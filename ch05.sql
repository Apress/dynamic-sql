/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 5: Managing Scope

	This TSQL all covers how to handle parameters, temp tables, table variables, and other objects relating to dynamic SQL scope.
*/
USE AdventureWorks2014 -- Can use any AdventureWorks database for all demos in this book.
GO
SET NOCOUNT ON;
GO
-- Simple SELECT statement
DECLARE @FirstName NVARCHAR(50) = 'Edward';

SELECT
	*
FROM Person.Person
WHERE FirstName = @FirstName;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- How using GO will end a batch and variables previously declared become out-of-scope and unavailable.
DECLARE @FirstName NVARCHAR(50) = 'Edward';
GO

SELECT
	*
FROM Person.Person
WHERE FirstName = @FirstName;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Illustration of how local variables used within a stored procedure are not available outside of the proc itself.
CREATE PROCEDURE dbo.get_people
AS
BEGIN
	DECLARE @FirstName NVARCHAR(50) = 'Edward';

	SELECT
		*
	FROM Person.Person
	WHERE FirstName = @FirstName;
END
GO
EXEC dbo.get_people;
SELECT @FirstName;
GO

DROP PROCEDURE dbo.get_people;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Use of input & output variables within a stored procedure.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_people')
BEGIN
	DROP PROCEDURE dbo.get_people;
END
GO
CREATE PROCEDURE dbo.get_people
	@first_name NVARCHAR(50), @person_with_most_entries NVARCHAR(50) OUTPUT
AS
BEGIN
	DECLARE @person_count INT;

	SELECT TOP 1
		@person_with_most_entries = Person.FirstName
	FROM Person.Person
	GROUP BY Person.FirstName
	ORDER BY COUNT(*) DESC;

	SELECT
		*
	FROM Person.Person
	WHERE FirstName = @first_name;

	RETURN @@ROWCOUNT;
END
GO

DECLARE @person_with_most_entries NVARCHAR(50);
DECLARE @person_count INT;

EXEC @person_count = dbo.get_people 'Edward', @person_with_most_entries OUTPUT;

SELECT @person_with_most_entries AS person_with_most_entries;
SELECT @person_count AS person_count
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Variables declared within dynamic SQL are not available outside of the scope of that dynamic SQL.
DECLARE @sql_command NVARCHAR(MAX);

SELECT @sql_command = '
DECLARE @FirstName NVARCHAR(50) = ''Edward'';
SELECT
	*
FROM Person.Person
WHERE FirstName = @FirstName;'
EXEC (@sql_command);
SELECT @FirstName
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Illustration of how variables passed into dynamic SQL can be modified, but without the OUTPUT operator,
-- those changes will not persist outside of the dynamic SQL.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name NVARCHAR(50) = 'Edward';

SELECT @sql_command = '
SELECT
	*
FROM Person.Person
WHERE FirstName = @first_name;
SELECT @first_name = ''Xavier'';
SELECT @first_name;
'

SELECT @parameter_list = '@first_name NVARCHAR(50)'
EXEC sp_executesql @sql_command, @parameter_list, @first_name;

SELECT @first_name;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Changing of variable names helps emphasize the differences between variables within dynamic SQL and those passed in from outside.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name_calling_sql NVARCHAR(50) = 'Edward';

SELECT @sql_command = '
SELECT
	*
FROM Person.Person
WHERE FirstName = @first_name_within_dynamic_sql;
SELECT @first_name_within_dynamic_sql = ''Xavier'';
SELECT @first_name_within_dynamic_sql;
'

SELECT @parameter_list = '@first_name_within_dynamic_sql NVARCHAR(50)'
EXEC sp_executesql @sql_command, @parameter_list, @first_name_calling_sql;

SELECT @first_name_calling_sql;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Using OUTPUT to allow a parameter to be written and for those changes to persist after dynamic SQL execution is complete.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name_calling_sql NVARCHAR(50) = 'Edward';

SELECT @sql_command = '
SELECT
	*
FROM Person.Person
WHERE FirstName = @first_name_within_dynamic_sql;
SELECT @first_name_within_dynamic_sql = ''Xavier'';
SELECT @first_name_within_dynamic_sql;
'

SELECT @parameter_list = '@first_name_within_dynamic_sql NVARCHAR(50) OUTPUT'
EXEC sp_executesql @sql_command, @parameter_list, @first_name_calling_sql OUTPUT;

SELECT @first_name_calling_sql;
GO

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Not declaring the parameter as an output parameter correctly can result in error messages, such as like this:
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name_calling_sql NVARCHAR(50) = 'Edward';

SELECT @sql_command = '
SELECT
	*
FROM Person.Person
WHERE FirstName = @first_name_within_dynamic_sql;
SELECT @first_name_within_dynamic_sql = ''Xavier'';
SELECT @first_name_within_dynamic_sql;
'

SELECT @parameter_list = '@first_name_within_dynamic_sql NVARCHAR(50)'
EXEC sp_executesql @sql_command, @parameter_list, @first_name_calling_sql OUTPUT;

SELECT @first_name_calling_sql;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Use of OUTPUT to change a parameter within dynamic SQL.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name_calling_sql NVARCHAR(50) = 'Edward';

SELECT @sql_command = '
SELECT
	*
FROM Person.Person
WHERE FirstName = @first_name_within_dynamic_sql;
SELECT @first_name_within_dynamic_sql = ''Xavier'';
SELECT @first_name_within_dynamic_sql;
'

SELECT @parameter_list = '@first_name_within_dynamic_sql NVARCHAR(50) OUTPUT'
EXEC sp_executesql @sql_command, @parameter_list, @first_name_calling_sql ;

SELECT @first_name_calling_sql;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Table variables declared outside of dynamic SQL are not available for use within (just like scalar variables)
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);

DECLARE @last_names TABLE (
	last_name NVARCHAR(50));

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM @last_names)
'

EXEC sp_executesql @sql_command;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Using a custom table type to pass a table variable into dynamic SQL.
CREATE TYPE last_name_table AS TABLE 
	(last_name NVARCHAR(50));
GO

DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name_calling_sql NVARCHAR(50) = 'Edward';

DECLARE @last_names AS last_name_table;

INSERT INTO @last_names
	(last_name)
SELECT
	LastName
FROM Person.Person WHERE FirstName = @first_name_calling_sql;

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM @last_name_table)
'

SELECT @parameter_list = '@first_name_within_dynamic_sql NVARCHAR(50), @last_name_table last_name_table READONLY'
EXEC sp_executesql @sql_command, @parameter_list, @first_name_calling_sql, @last_names;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Use of READONLY to ensure that the contents of a table variable cannot be modified within dynamic SQL.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);
DECLARE @first_name_calling_sql NVARCHAR(50) = 'Edward';

DECLARE @last_names AS last_name_table;

INSERT INTO @last_names
	(last_name)
SELECT
	LastName
FROM Person.Person WHERE FirstName = @first_name_calling_sql;

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM @last_name_table);

DELETE FROM @last_name_table;
'

SELECT @parameter_list = '@first_name_within_dynamic_sql NVARCHAR(50), @last_name_table last_name_table READONLY'
EXEC sp_executesql @sql_command, @parameter_list, @first_name_calling_sql, @last_names;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Use of tamp tables in dynamic SQL, which remain in scope throughout their use.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);

CREATE TABLE #last_names (
	last_name NVARCHAR(50));

INSERT INTO #last_names
	(last_name)
SELECT 'Thomas'

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM #last_names);

INSERT INTO #last_names
	(last_name)
SELECT ''Smith'';
'

EXEC sp_executesql @sql_command;

SELECT * FROM #last_names;

DROP TABLE #last_names;
GO

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Note that a temp table created in one dynamic SQL statement will not be available in another, separate dynamic SQL statement.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);

SELECT @sql_command = '
CREATE TABLE #last_names (
	last_name NVARCHAR(50));

INSERT INTO #last_names
	(last_name)
SELECT ''Thomas'';'

EXEC sp_executesql @sql_command;

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM #last_names);'

EXEC sp_executesql @sql_command;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Use of a global temp table to maintain data throughout any scope.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);

SELECT @sql_command = '
CREATE TABLE ##last_names (
	last_name NVARCHAR(50));

INSERT INTO ##last_names
	(last_name)
SELECT ''Thomas'';'

EXEC sp_executesql @sql_command;

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM ##last_names);'

EXEC sp_executesql @sql_command;

SELECT * FROM ##last_names;

DROP TABLE ##last_names;
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Global temp tables are accessible from any database, anywhere on the server.
CREATE TABLE ##last_names (
	last_name NVARCHAR(50));
CREATE DATABASE temp_table_test;
GO
USE temp_table_test;
GO
SELECT
	*
FROM ##last_names;

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Any user can access a global temp table, regardless of their security roles or permissions.
EXECUTE AS USER = 'VeryLimitedUser'; 
GO
SELECT
	*
FROM ##last_names;
REVERT; 
GO
DROP TABLE ##last_names;
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Using permanent staging tables to manage data in different scopes.
CREATE TABLE last_names_staging (
	last_name NVARCHAR(50) NOT NULL CONSTRAINT PK_last_names_staging PRIMARY KEY CLUSTERED);
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);

SELECT @sql_command = '

INSERT INTO last_names_staging
	(last_name)
SELECT ''Thomas'';'

EXEC sp_executesql @sql_command;

SELECT @sql_command = '
SELECT DISTINCT
	FirstName
FROM Person.Person
WHERE LastName IN (SELECT last_name FROM last_names_staging);'

EXEC sp_executesql @sql_command;

SELECT * FROM last_names_staging;

DROP TABLE last_names_staging;
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- How to output results from dynamic SQL directly into a table.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX);

CREATE TABLE #last_names (
	last_name NVARCHAR(50));

SELECT @sql_command = '
SELECT
	LastName
FROM Person.Person
WHERE FirstName = ''Edward'';
'

INSERT INTO #last_names
	(last_name)
EXEC sp_executesql @sql_command;

SELECT
	*
FROM #last_names

DROP TABLE #last_names;
GO

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Using INSERT...EXEC to retrieve and store the results from sp_who.
CREATE TABLE #sp_who_data
(	
	spid SMALLINT,
	ecid SMALLINT,
	status NCHAR(30),
	loginame NCHAR(128),
	hostname NCHAR(128),
	blk CHAR(5),
	dbname NCHAR(128),
	cmd NCHAR(16),
	request_id INT
)

INSERT INTO #sp_who_data
(spid, ecid, status, loginame, hostname, blk, dbname, cmd, request_id)
EXEC sp_who;

SELECT * FROM #sp_who_data
WHERE dbname = 'AdventureWorks2012'

DROP TABLE #sp_who_data;
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Things that SQL Server doesn't allow you to do.
SELECT
	EXEC sp_who
INTO #sp_who_data;

SELECT INTO #sp_who_data
EXEC sp_who;

SELECT INTO #sp_who_data
(EXEC sp_who);
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Cleanup:
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_people')
BEGIN
	DROP PROCEDURE dbo.get_people;
END
GO
IF EXISTS (SELECT * FROM sys.databases WHERE databases.name = 'temp_table_test')
BEGIN
	DROP DATABASE temp_table_test;
END
GO
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------