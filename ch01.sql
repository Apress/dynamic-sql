/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 1: What is Dynamic SQL.

	The SQL demos in this chapter serve to introduce the topic of dynamic SQL and provide
	the basis for all content discussed for the remainder of the book.	
*/
USE AdventureWorks2014 -- Can use any AdventureWorks database for all demos in this book.
GO

SELECT TOP 10 * FROM Person.Person; -- Simple SELECT to return ten rows from Person.Person
-- Dynamic SQL to call the same statement
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = 'SELECT TOP 10 * FROM Person.Person';
EXEC (@sql_command);
GO

DECLARE @sql_command VARCHAR(MAX)
SET @sql_command = 'SELECT TOP 10 * FROM Person.Person'
PRINT @sql_command
EXEC @sql_command -- Must use parenthesis around all EXEC statements when calling dynamic SQL.
GO
-- Add in a table name variable into the dynamic SQL as part of the FROM.
DECLARE @sql_command VARCHAR(MAX);
DECLARE @table_name VARCHAR(100);
SELECT @table_name = 'Person.Person';
SELECT @sql_command = 'SELECT TOP 10 * FROM ' + @table_name;
EXEC (@sql_command);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Simple backup statement
BACKUP DATABASE AdventureWorks2012
TO DISK='C:\SQLBackups\AdventureWorks2012.bak'
WITH COMPRESSION;
GO
-- Dynamic SQL to back up all databases on the server with a name like AdventureWorks.
DECLARE @database_list TABLE
	(database_name SYSNAME);

INSERT INTO @database_list
	(database_name)
SELECT
	name
FROM sys.databases
WHERE name LIKE 'AdventureWorks%';

DECLARE @sql_command NVARCHAR(MAX);
DECLARE @database_name SYSNAME;

DECLARE database_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT database_name FROM @database_list
OPEN database_cursor
FETCH NEXT FROM database_cursor INTO @database_name;

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @sql_command = '
	BACKUP DATABASE ' + @database_name + '
	TO DISK=''C:\SQLBackups\' + @database_name + '.bak''
	WITH COMPRESSION;'
	
	EXEC (@sql_command);

	FETCH NEXT FROM database_cursor INTO @database_name;
END

CLOSE database_cursor;
DEALLOCATE database_cursor;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example showing that dynamic SQL is not allowed within functions as they must be deterministic when created.
CREATE FUNCTION dbo.fn_test ()
RETURNS INT
AS BEGIN
	DECLARE @sql_command NVARCHAR(MAX);

	SET @sql_command = 'SELECT 1';
	EXEC (@sql_command);
	RETURN 1;
END
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of how a mispelling or syntax mistake within the dynamic SQL string will go unnoticed by SQL Server until runtime.
-- This will throw a syntax error.
DECLARE @CMD NVARCHAR(MAX);
SET @CMD = 'SELLECT TOP 17 * FROM Person.Person';
EXEC (@CMD);
GO
-- Printing dynamic SQL while initially writing & debugging will greatly help in avoiding errors...
DECLARE @CMD NVARCHAR (MAX);
SELECT @CMD = 'SELLECT TOP 17 * FROM Person.Person';
PRINT (@CMD);
-- ...otherwise this can happen : )
SELLECT TOP 17 * FROM Person.Person
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Examples of good TSQL documentation, which is useful both with dynamic SQL and otherwise.

/*	9/8/2015 Edward Pollack
	Backup routing for AdventureWorks databases

	As a result of ticket T1234, logged on 8/20/2015, it became necessary to selectively
	back up a limited set of AdventureWorks databases via a SQL Server Agent job.  The
	job can have its schedule adjusted as needed to fit the current needs of the business.

	Dynamic SQL is used to iterate through each database, performing the backup and naming the
	resulting file using the database name, date, time, and source server.	*/

-- This will temporarily store the list of databases that we will back up below.
DECLARE @database_list TABLE
	(database_name SYSNAME);

INSERT INTO @database_list
	(database_name)
SELECT
	name
FROM sys.databases
WHERE name LIKE 'AdventureWorks%';
-- This WHERE clause may be adjusted to backup other databases besides those starting with "AdventureWorks"

DECLARE @sql_command NVARCHAR(MAX);
DECLARE @database_name SYSNAME;
DECLARE @date_string VARCHAR(17) = CONVERT(VARCHAR, CURRENT_TIMESTAMP, 112) + '_' + REPLACE(RIGHT(CONVERT(NVARCHAR, CURRENT_TIMESTAMP, 120), 8), ':', '');

-- Use a cursor to iterate through databases, one by one.
DECLARE database_cursor CURSOR FOR
SELECT database_name FROM @database_list
OPEN database_cursor
FETCH NEXT FROM database_cursor INTO @database_name;

WHILE @@FETCH_STATUS = 0 -- Continue looping until the cursor has reached the end of the database list.
BEGIN
	-- Customize the backup file name to use the database name, as well as the date and time
	SELECT @sql_command = '
	BACKUP DATABASE ' + @database_name + '
	TO DISK=''E:\SQLBackups\' + @database_name + '_' + @date_string + '.bak''
	WITH COMPRESSION;'
	
	EXEC (@sql_command);

	FETCH NEXT FROM database_cursor INTO @database_name;
END

-- Clean up our cursor object.
CLOSE database_cursor;
DEALLOCATE database_cursor;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of superfluous/unnecessary documentation.  Good for laughs, but not very useful.
-- This variable holds the database name.
DECLARE @database_name SYSNAME;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of using a debug bit to switch between printing the command string and executing it:
DECLARE @debug BIT = 1;

DECLARE @database_list TABLE
	(database_name SYSNAME);

INSERT INTO @database_list
	(database_name)
SELECT
	name
FROM sys.databases
WHERE name LIKE 'AdventureWorks%';
-- This WHERE clause may be adjusted to backup other databases besides those starting with "AdventureWorks"

DECLARE @sql_command NVARCHAR(MAX);
DECLARE @database_name SYSNAME;
DECLARE @date_string VARCHAR(17) = CONVERT(VARCHAR, CURRENT_TIMESTAMP, 112) + '_' + REPLACE(RIGHT(CONVERT(NVARCHAR, CURRENT_TIMESTAMP, 120), 8), ':', '');

-- Use a cursor to iterate through databases, one by one.
DECLARE database_cursor CURSOR FOR
SELECT database_name FROM @database_list
OPEN database_cursor
FETCH NEXT FROM database_cursor INTO @database_name;

WHILE @@FETCH_STATUS = 0 -- Continue looping until the cursor has reacdhed the end of the database list.
BEGIN
	-- Customize the backup file name to use the database name, as well as the date and time
	SELECT @sql_command = '
	BACKUP DATABASE ' + @database_name + '
	TO DISK=''E:\SQLBackups\' + @database_name + '_' + @date_string + '.bak''
	WITH COMPRESSION;'
	
	IF @debug = 1
		PRINT @sql_command
	ELSE
		EXEC (@sql_command);

	FETCH NEXT FROM database_cursor INTO @database_name;
END
-- Clean up our cursor object.
CLOSE database_cursor;
DEALLOCATE database_cursor;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using PRINT to return variables throughout code, not just for the command string:
DECLARE @date_string VARCHAR(17) = CONVERT(VARCHAR, CURRENT_TIMESTAMP, 112) + '_' + REPLACE(RIGHT(CONVERT(NVARCHAR, CURRENT_TIMESTAMP, 120), 8), ':', '');

PRINT '@date_string (line 20): ' + @date_string
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of poorly written dynamic SQL.  Putting everything on one line is sure to irrirate future developers without fail.
DECLARE @CMD VARCHAR(MAX) = ''; -- This will hold the final SQL to execute
DECLARE @first_name VARCHAR(50) = 'Edward'; -- First name as entered in search box
SET @CMD = 'SELECT PERSON.FirstName,PERSON.LastName,PHONE.PhoneNumber,PTYPE.Name FROM Person.Person PERSON INNER JOIN Person.PersonPhone PHONE ON PERSON.BusinessEntityID = PHONE.BusinessEntityID INNER JOIN Person.PhoneNumberType PTYPE ON PHONE.PhoneNumberTypeID = PTYPE.PhoneNumberTypeID WHERE PERSON.FirstName = ''' + @first_name + '''';
PRINT @CMD;
EXEC (@CMD);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Examples of string truncation due to the string being longer than the variable it is being assigned to.
DECLARE @date_string VARCHAR(10) = CONVERT(VARCHAR, CURRENT_TIMESTAMP, 112) + '_' + REPLACE(RIGHT(CONVERT(NVARCHAR, CURRENT_TIMESTAMP, 120), 8), ':', '');
PRINT @date_string;
GO
DECLARE @date_string VARCHAR(17) = CONVERT(VARCHAR, CURRENT_TIMESTAMP, 112) + '_' + REPLACE(RIGHT(CONVERT(NVARCHAR, CURRENT_TIMESTAMP, 120), 8), ':', '');
PRINT @date_string;
GO
DECLARE @date_string VARCHAR(30) = CONVERT(VARCHAR, CURRENT_TIMESTAMP, 112) + '_' + REPLACE(RIGHT(CONVERT(NVARCHAR, CURRENT_TIMESTAMP, 120), 8), ':', '');
PRINT @date_string;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Syntax for sp_executesql
sp_executesql N'SELECT COUNT(*) FROM Person.Person'

DECLARE @sql_command NVARCHAR(MAX) = 'SELECT COUNT(*) FROM Person.Person';
EXEC sp_executesql @sql_command;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Building strings via concatenation.
DECLARE @schema VARCHAR(25) = NULL;
DECLARE @table VARCHAR(25) = 'Person';
DECLARE @sql_command VARCHAR(MAX);
SET @sql_command = 'SELECT COUNT(*) ' + 'FROM ' +  @schema + '.' + @table;
PRINT @sql_command;
SET @sql_command = 'SELECT COUNT(*) ' + 'FROM ' +  ISNULL(@schema, 'Person') + '.' + @table;
PRINT @sql_command;
SET @sql_command = 'SELECT COUNT(*) ' + 'FROM ' +  CASE WHEN @schema IS NULL THEN 'Person' ELSE @schema END + '.' + @table;
PRINT @sql_command;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of how to use CONCAT to combine strings.
SELECT CONCAT ('SELECT COUNT(*) ', 'FROM ', 'Person.', 'Person')

DECLARE @schema VARCHAR(25) = 'Person';
DECLARE @table VARCHAR(25) = 'Person';
DECLARE @sql_command VARCHAR(MAX);
SET @sql_command = CONCAT ('SELECT COUNT(*) ', 'FROM ', @schema, '.', @table);
PRINT @sql_command;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of using LTRIM and RTRIM to remove whitespaces from a string.
DECLARE @string NVARCHAR(MAX) = '   This is a string with extra whitespaces     ';
SELECT @string;
SELECT LTRIM(@string);
SELECT RTRIM(@string);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of using CHARINDEX to locate the position of a string within a string
DECLARE @string NVARCHAR(MAX) = 'The stegosaurus is my favorite dinosaur';
SELECT CHARINDEX('dinosaur', @string);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of using STUFF to insert text within another string.
DECLARE @string NVARCHAR(MAX) = 'The stegosaurus is my favorite dinosaur';
SELECT STUFF(@string, 5, 0, 'purple ');
SELECT STUFF(@string, 5, 11, 't-rex');
SELECT STUFF(@string, 32, 8, 'animal!')
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of using REPLACE to remove specific characters from a string.
DECLARE @string NVARCHAR(MAX) = CAST(CURRENT_TIMESTAMP AS NVARCHAR);
SELECT REPLACE(@string, ' ', '');
SELECT REPLACE(REPLACE(@string, ' ', ''), ':', '');
SELECT REPLACE(REPLACE(REPLACE(REPLACE(@string, ' ', ''), ':', ''), 'AM', ''), 'PM', '');
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using SUBSTRING to return part of a larger string
DECLARE @string NVARCHAR(MAX) = CAST(CURRENT_TIMESTAMP AS NVARCHAR);
SELECT SUBSTRING(@string, 1, 3);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using REPLICATE to create a repeating sequence of characters
DECLARE @serial_number NVARCHAR(MAX) = '91542278';
SELECT REPLICATE(0, 20 - LEN(@serial_number)) + @serial_number;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using REVERSE to invert the order of a string.
DECLARE @string NVARCHAR(MAX) = '123456789';
SELECT REVERSE(@string);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of using two apostrophes in order to escape an apostrophe within a string.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @first_name NVARCHAR(20) = 'Ed';
SELECT @sql_command = '
SELECT
	*
FROM Person.Person
WHERE FirstName LIKE ''' + @first_name + '%''';
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
