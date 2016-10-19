/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 2: Protecting Against SQL Injection.

	The SQL in this chapter provides a guideline for detecting, avoiding, and fixing SQL injection threats.
*/
USE AdventureWorks2014 -- Can use any AdventureWorks database for all demos in this book.
GO
-- Simple search using dynamic SQL.
DECLARE @CMD NVARCHAR(MAX);
DECLARE @search_criteria NVARCHAR(1000);

SELECT @CMD = 'SELECT * FROM Person.Person
WHERE FirstName = ''';
SELECT @search_criteria = 'Edward';
SELECT @CMD = @CMD + @search_criteria;
SELECT @CMD = @CMD + '''';
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- What happens when input is entered that includes an apostrope.
DECLARE @CMD NVARCHAR(MAX);
DECLARE @search_criteria NVARCHAR(1000);

SELECT @CMD = 'SELECT * FROM Person.Person
WHERE LastName = ''';
SELECT @search_criteria = 'O''Brien';
SELECT @CMD = @CMD + @search_criteria;
SELECT @CMD = @CMD + '''';
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- If the user entering text realizes they can enter anything and it will be handled directly by SQL Server
-- with no input sanitization, they could close the string and write their own TSQL against your database.
DECLARE @CMD NVARCHAR(MAX);
DECLARE @search_criteria NVARCHAR(1000);

SELECT @CMD = 'SELECT * FROM Person.Person
WHERE LastName = ''';
SELECT @search_criteria = 'Smith'' OR 1 = 1 AND '''' = ''';
SELECT @CMD = @CMD + @search_criteria;
SELECT @CMD = @CMD + '''';
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using SQL injection in order to return information about schema, such as table names and related info.
DECLARE @CMD NVARCHAR(MAX);
DECLARE @search_criteria NVARCHAR(1000);

SELECT @CMD = 'SELECT * FROM Person.Person
WHERE LastName = ''';
SELECT @search_criteria = 'Smith''; SELECT * FROM sys.tables WHERE '''' = '''
SELECT @CMD = @CMD + @search_criteria;
SELECT @CMD = @CMD + '''';
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using SQL injection to retrieve password data.
DECLARE @CMD NVARCHAR(MAX);
DECLARE @search_criteria NVARCHAR(1000);

SELECT @CMD = 'SELECT * FROM Person.Person
WHERE LastName = ''';
SELECT @search_criteria = 'Smith''; SELECT * FROM Person.Password WHERE '''' = '''
SELECT @CMD = @CMD + @search_criteria;
SELECT @CMD = @CMD + '''';
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using REPLACE to clean up inputs of any apostrophes.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'search_people')
	DROP PROCEDURE search_people;
GO

CREATE PROCEDURE dbo.search_people
	 (@search_criteria NVARCHAR(1000) = NULL) -- This comes from user input
AS
BEGIN
	SELECT @search_criteria = REPLACE(@search_criteria, '''', '''''');

	DECLARE @CMD NVARCHAR(MAX);

	SELECT @CMD = 'SELECT * FROM Person.Person
	WHERE LastName = ''';
	SELECT @CMD = @CMD + @search_criteria;
	SELECT @CMD = @CMD + '''';
	PRINT @CMD;
	EXEC sp_executesql @CMD;
END
GO

EXEC dbo.search_people 'Smith';
EXEC dbo.search_people 'O''Brien';
EXEC dbo.search_people ''' SELECT * FROM Person.Password; SELECT ''';

IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'search_people')
	DROP PROCEDURE search_people;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using QUOTENAME to sanitize inputs for the apostrophe escape character.
CREATE PROCEDURE dbo.search_people
	 (@search_criteria NVARCHAR(1000) = NULL) -- This comes from user input
AS
BEGIN
	DECLARE @CMD NVARCHAR(MAX);

	SELECT @CMD = 'SELECT * FROM Person.Person
	WHERE LastName = ';
	SELECT @CMD = @CMD + QUOTENAME(@search_criteria, '''');
	PRINT @CMD;
	EXEC sp_executesql @CMD;
END
GO

EXEC dbo.search_people 'Smith';
EXEC dbo.search_people 'O''Brien';
EXEC dbo.search_people ''' SELECT * FROM Person.Password; SELECT ''';

DROP PROCEDURE dbo.search_people;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Parameterizing sp_executesql in order to prevent SQL injection.
CREATE PROCEDURE dbo.search_people
	 (@search_criteria NVARCHAR(1000) = NULL) -- This comes from user input
AS
BEGIN
	DECLARE @CMD NVARCHAR(MAX);

	SELECT @CMD = 'SELECT * FROM Person.Person
	WHERE LastName = @search_criteria';
	PRINT @CMD;
	EXEC sp_executesql @CMD, N'@search_criteria NVARCHAR(1000)', @search_criteria;
END
GO

EXEC dbo.search_people 'Smith';
EXEC dbo.search_people 'O''Brien';
EXEC dbo.search_people ''' SELECT * FROM Person.Password; SELECT ''';

DROP PROCEDURE dbo.search_people;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Simple password verification query
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @id INT = 3;
DECLARE @password NVARCHAR(128) = '';

SELECT @sql_command = 'SELECT
	*
FROM Person.Password
WHERE BusinessEntityID = ' + CAST(@id AS VARCHAR(25)) + '
AND PasswordHash = ''' + @password + ''''

PRINT @sql_command
EXEC (@sql_command)
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using SQL injection to alter the WHERE clause and return all password data, thereby potentially bypassing the security check.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @id INT = 3;
DECLARE @password NVARCHAR(128) = ''' OR 1 = 1 AND '''' = ''';

SELECT @sql_command = 'SELECT
	*
FROM Person.Password
WHERE BusinessEntityID = ' + CAST(@id AS VARCHAR(25)) + '
AND PasswordHash = ''' + @password + ''''

PRINT @sql_command
EXEC (@sql_command)
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using comments in SQL injection to introduce rogue TSQL or remove parts of the statement.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @username NVARCHAR(128) = 'administrator'' --';
DECLARE @password NVARCHAR(128) = 'my_password';

SELECT @sql_command = 'SELECT
	*
FROM dbo.password
WHERE username = ''' + @username + ''' AND Password = ''' + @password + '''';

PRINT @sql_command;
EXEC (@sql_command);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- using UNION to add additional rows to a result set using SQL injection.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @id INT = 3;
DECLARE @password NVARCHAR(128) = ''' UNION ALL SELECT * FROM Person.Password WHERE '''' = ''';

SELECT @sql_command = 'SELECT
	*
FROM Person.Password
WHERE BusinessEntityID = ' + CAST(@id AS VARCHAR(25)) + '
AND PasswordHash = ''' + @password + ''''

PRINT @sql_command
EXEC (@sql_command)
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using a separate parameter list variable in order to manage sp_executesql parameters.
CREATE PROCEDURE dbo.search_people
	 (@search_criteria NVARCHAR(1000) = NULL) -- This comes from user input
AS
BEGIN
	DECLARE @CMD NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX) = N'@search_criteria NVARCHAR(1000)'

	SELECT @CMD = 'SELECT * FROM Person.Person
	WHERE LastName = @search_criteria';
	PRINT @CMD;
	EXEC sp_executesql @CMD, @parameter_list, @search_criteria;
END
GO

EXEC dbo.search_people 'Smith';
EXEC dbo.search_people 'O''Brien';
EXEC dbo.search_people ''' SELECT * FROM Person.Password; SELECT ''';

DROP PROCEDURE dbo.search_people;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using sp_executesql with multiple parameters.
CREATE PROCEDURE dbo.search_people
	 (@FirstName NVARCHAR(50) = NULL,
	  @MiddleName NVARCHAR(50) = NULL,
	  @LastName NVARCHAR(50) = NULL,
	  @EmailPromotion INT = NULL)
AS
BEGIN
	DECLARE @CMD NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX) = N'@FirstName NVARCHAR(50), @MiddleName NVARCHAR(50), @LastName NVARCHAR(50), @EmailPromotion INT';

	SELECT @CMD = 'SELECT * FROM Person.Person
	WHERE 1 = 1';
	IF @FirstName IS NOT NULL
		SELECT @CMD = @CMD + '
		AND FirstName = @FirstName'
	IF @MiddleName IS NOT NULL
		SELECT @CMD = @CMD + '
		AND MiddleName = @MiddleName'
	IF @LastName IS NOT NULL
		SELECT @CMD = @CMD + '
		AND LastName = @LastName'
	IF @EmailPromotion IS NOT NULL
		SELECT @CMD = @CMD + '
		AND EmailPromotion = @EmailPromotion';
	PRINT @CMD;
	EXEC sp_executesql @CMD, @parameter_list, @FirstName, @MiddleName, @LastName, @EmailPromotion;
END
GO

EXEC dbo.search_people 'Edward', 'H', 'Johnson', 1
EXEC dbo.search_people 'Edward', NULL, NULL, 1
EXEC dbo.search_people

DROP PROCEDURE dbo.search_people;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Dynamic SQL to return rows from a dynamically provided table.
DECLARE @table_name SYSNAME = 'ErrorLog';
DECLARE @CMD NVARCHAR(MAX);

SELECT @CMD = 'SELECT * FROM ' + @table_name;
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Adding additional TSQL to the table name in order to return data that wasn't intended to be accessed as part of this query.
DECLARE @table_name SYSNAME = 'ErrorLog; SELECT * FROM Person.Password WHERE '''' = ''''';
DECLARE @CMD NVARCHAR(MAX);

SELECT @CMD = 'SELECT * FROM ' + @table_name;
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using square brackets in order to quash attempts to circumvent object names.
DECLARE @table_name SYSNAME = 'ErrorLog; SELECT * FROM Person.Password WHERE '''' = ''''';
DECLARE @CMD NVARCHAR(MAX);

SELECT @CMD = 'SELECT * FROM [dbo].[' + @table_name + ']';
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using dynamic SQL to circumvent that security attempt by closing the square brackets and then carefully adding more TSQL.
DECLARE @table_name SYSNAME = 'ErrorLog]; SELECT * FROM [Person].[Password';
DECLARE @CMD NVARCHAR(MAX);

SELECT @CMD = 'SELECT * FROM [dbo].[' + @table_name + ']';
PRINT @CMD;
EXEC sp_executesql @CMD;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Blind SQL injection examples:
IF CURRENT_USER = 'dbo' SELECT 1 ELSE SELECT 0;
IF @@VERSION LIKE '%12.0%' SELECT 1 ELSE SELECT 0;

IF (SELECT COUNT(*) FROM Person.Person WHERE FirstName = 'Edward' and LastName = 'Pollack') > 0
WAITFOR DELAY '00:00:05'
ELSE
WAITFOR DELAY '00:00:00';

BEGIN TRY
	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = 'SELECT * FROM dbo.password;'
	EXEC (@sql_command)
END TRY
BEGIN CATCH
	SELECT 0
END CATCH;
