/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 7: Scalable Dynamic Lists

	This SQL provides a variety of examples of how to efficiently generate lists
	without the need for loops or XML.
*/
USE AdventureWorks2014 -- Can use any AdventureWorks database for all demos in this book.
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
--------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- This is a common cursor-based iterative approach.  It's slow, inefficient, and not great for job security.
-- As always, most row-by-row solutions will be problematic and should be avoided unless abolutely necessary.
-- Total subtree cost: 2.006, 1021 logical reads!
DECLARE @nextid INT;
DECLARE @myIDs NVARCHAR(MAX) = '';

DECLARE idcursor CURSOR FOR
SELECT TOP 100
	BusinessEntityID
FROM Person.Person
ORDER BY LastName;
OPEN idcursor;
FETCH NEXT FROM idcursor INTO @nextid;

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @myIDs = @myIDs + CAST(@nextid AS NVARCHAR) + ',';
	FETCH NEXT FROM idcursor INTO @nextid;
END
SET @myIDs = LEFT(@myIDs, LEN(@myIDs) - 1);
CLOSE idcursor;
DEALLOCATE idcursor;

SELECT @myIDs AS comma_separated_output;
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- This is an old school approach from when XML first came to SQL Server.  The execution plan shows that while
-- this method reduces the number of operations & reads greatly, the XML usage itself is extremely inefficient.
-- Total subtree cost: 1.08051, 3 logical reads (far less reads, but still heavier on processing)
DECLARE @myIDs NVARCHAR(MAX) = '';

SET @myIDs = STUFF((SELECT TOP 100 ',' + CAST(BusinessEntityID AS NVARCHAR)
FROM Person.Person
ORDER BY LastName
FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)'), 1, 1, '');

SELECT @myIDs;
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Breakdown of the XML statement, starting with the basic SELECT.
SELECT TOP 100 ',' + CAST(BusinessEntityID AS NVARCHAR) AS ID_CSV
FROM Person.Person
ORDER BY LastName;
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Creating a list using the SELECT above with XML.
SELECT (SELECT TOP 100 ',' + CAST(BusinessEntityID AS NVARCHAR)
FROM Person.Person
ORDER BY LastName
FOR XML PATH(''));
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Add a data type to the output, ensuring we get back the type that we want, regardless of the contents of the SELECT.
SELECT (SELECT TOP 100 ',' + CAST(BusinessEntityID AS NVARCHAR)
FROM Person.Person
ORDER BY LastName
FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)');

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- The full XML list, with separate steps to show different ways to eliminate the extra comma.
DECLARE @myIDs NVARCHAR(MAX) = '';

SET @myIDs = (SELECT TOP 100 ',' + CAST(BusinessEntityID AS NVARCHAR)
FROM Person.Person
ORDER BY LastName
FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)');

SELECT RIGHT(@myIDs, LEN(@myIDs) - 1);
SELECT SUBSTRING(@myIDs, 2, LEN(@myIDs) - 1);
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- This method uses dynamic SQL to quickly generate a list in a single statement.  The only CPU/disk
-- consumption is that needed to retrieve the data from the base table.  The remainder of the operations
-- use negligible disk/CPU/memory and are VERY fast.
-- Total subtree cost: 0.0038369, 3 logical reads (far less reads AND far less processing!)
DECLARE @myIDs NVARCHAR(MAX) = '';

SELECT TOP 100 @myIDs = @myIDs + CAST(BusinessEntityID AS NVARCHAR) + ','
FROM Person.Person
ORDER BY LastName;
SET @myIDs = LEFT(@myIDs, LEN(@myIDs) - 1);

SELECT @myIDs;
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Lists can be created from multiple columns as well:
DECLARE @myData NVARCHAR(MAX) = '';
SELECT @myData = 
	@myData + 'ContactTypeID: ' + CAST(ContactTypeID AS NVARCHAR) + ',Name: ' + Name + ','
FROM person.ContactType
SET @myData = LEFT(@myData, LEN(@myData) - 1);

SELECT @myData;
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Lists can be created using COALESCE, which eliminates the need to remove the trailing comma.
DECLARE @myData NVARCHAR(MAX);

SELECT @myData = 
	COALESCE(@myData + ',','') + 'ContactTypeID: ' + CAST(ContactTypeID AS NVARCHAR) + ',Name: ' + Name
FROM person.ContactType;

SELECT @myData;
GO

DECLARE @myData NVARCHAR(MAX);

SELECT @myData = 
	ISNULL(@myData + ',','') + 'ContactTypeID: ' + CAST(ContactTypeID AS NVARCHAR) + ',Name: ' + Name
FROM person.ContactType;

SELECT @myData;
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- This stored procedure combines dynamic SQL and list builkding to return lists of names based on the input.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'return_person_data')
BEGIN
	DROP PROCEDURE dbo.return_person_data;
END
GO

CREATE PROCEDURE dbo.return_person_data
	@last_name NVARCHAR(MAX) = NULL, @first_name NVARCHAR(MAX) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @return_data NVARCHAR(MAX) = '';
	DECLARE @sql_command NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX);

	SELECT @parameter_list = '@output_data NVARCHAR(MAX) OUTPUT';

	SELECT @sql_command = '
	SELECT
		@output_data = @output_data + ''ID: '' + CAST(BusinessEntityID AS NVARCHAR) + '', Name: '' + FirstName + '' '' + LastName + '',''
	FROM Person.Person
	WHERE 1 = 1'
	IF @last_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND LastName LIKE ''%' + @last_name + '%''';
	IF @first_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND FirstName LIKE ''%' + @first_name + '%''';

	PRINT @sql_command;
	EXEC sp_executesql @sql_command, @parameter_list, @return_data OUTPUT;

	SELECT @return_data = LEFT(@return_data, LEN(@return_data) - 1);
	SELECT @return_data;
END
GO

EXEC dbo.return_person_data @first_name = 'Edward';
EXEC dbo.return_person_data @first_name = ''; -- This takes 2:58 to run!
EXEC dbo.return_person_data @first_name = 'whatever''; SELECT * FROM Person.Password; SELECT ''';
GO
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Dynamic SQL inputs are parameterized here, eliminating the obvious errors if names are passed in with apostrophes.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'return_person_data')
BEGIN
	DROP PROCEDURE dbo.return_person_data;
END
GO

CREATE PROCEDURE dbo.return_person_data
	@last_name NVARCHAR(MAX) = NULL, @first_name NVARCHAR(MAX) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT @last_name = '%' + @last_name + '%';
	SELECT @first_name = '%' + @first_name + '%';

	DECLARE @return_data NVARCHAR(MAX) = '';
	DECLARE @sql_command NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX);

	SELECT @parameter_list = '@output_data NVARCHAR(MAX) OUTPUT, @first_name NVARCHAR(MAX), @last_name NVARCHAR(MAX)';

	SELECT @sql_command = '
	SELECT
		@output_data = @output_data + ''ID: '' + CAST(BusinessEntityID AS NVARCHAR) + '', Name: '' + FirstName + '' '' + LastName + '',''
	FROM Person.Person
	WHERE 1 = 1'
	IF @last_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND LastName LIKE @last_name';
	IF @first_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND FirstName LIKE @first_name';

	PRINT @sql_command;
	EXEC sp_executesql @sql_command, @parameter_list, @return_data OUTPUT, @first_name, @last_name;

	SELECT @return_data = LEFT(@return_data, LEN(@return_data) - 1);

	SELECT @return_data;
END
GO

EXEC dbo.return_person_data @first_name = 'Edward';
EXEC dbo.return_person_data @first_name = ''; -- This takes 2:58 to run!
EXEC dbo.return_person_data @first_name = 'Edward''; SELECT * FROM Person.Password; SELECT ''';

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- A TOP 25 is added to the results so that we cannot be hammered with an immense search result set that could harm server performance.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'return_person_data')
BEGIN
	DROP PROCEDURE dbo.return_person_data;
END
GO

CREATE PROCEDURE dbo.return_person_data
	@last_name NVARCHAR(MAX) = NULL, @first_name NVARCHAR(MAX) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT @last_name = '%' + @last_name + '%';
	SELECT @first_name = '%' + @first_name + '%';

	DECLARE @return_data NVARCHAR(MAX) = '';
	DECLARE @sql_command NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX);

	SELECT @parameter_list = '@output_data NVARCHAR(MAX) OUTPUT, @first_name NVARCHAR(MAX), @last_name NVARCHAR(MAX)';

	SELECT @sql_command = '
	SELECT TOP 25
		@output_data = @output_data + ''ID: '' + CAST(BusinessEntityID AS NVARCHAR) + '', Name: '' + FirstName + '' '' + LastName + '',''
	FROM Person.Person
	WHERE 1 = 1'
	IF @last_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND LastName LIKE @last_name';
	IF @first_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND FirstName LIKE @first_name';

	PRINT @sql_command;
	EXEC sp_executesql @sql_command, @parameter_list, @return_data OUTPUT, @first_name, @last_name;

	IF LEN(@return_data) > 0 AND @return_data IS NOT NULL
		SELECT @return_data = LEFT(@return_data, LEN(@return_data) - 1);

	SELECT @return_data;
END
GO

EXEC dbo.return_person_data @first_name = 'Edward';
EXEC dbo.return_person_data @first_name = ''; -- This takes 2:58 to run!
EXEC dbo.return_person_data @first_name = 'Edward''; SELECT * FROM Person.Password; SELECT ''';
