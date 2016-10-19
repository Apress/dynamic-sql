/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 10: Solving Common Problems.

	This TSQL walks through a variety of common database issues and how to solve them using dynamic SQL.
*/

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Here we build a test database that will be used for collation testing.
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'Collation_Test')
BEGIN
	DROP DATABASE Collation_Test;
END
GO

CREATE DATABASE Collation_Test COLLATE Traditional_Spanish_CI_AS;
GO
USE Collation_Test;
GO

CREATE TABLE dbo.Spanish_Employees
(	BusinessEntityID INT NOT NULL,
	NationalIDNumber NVARCHAR(15) NOT NULL,
	LoginID NVARCHAR(256) NOT NULL,
	OrganizationNode HIERARCHYID NULL,
	OrganizationLevel SMALLINT NULL,
	JobTitle NVARCHAR(50) NOT NULL,
	BirthDate DATE NOT NULL,
	MaritalStatus NCHAR(1) NOT NULL,
	Gender NCHAR(1) NOT NULL,
	HireDate DATE NOT NULL,
	SalariedFlag BIT NOT NULL,
	VacationHours SMALLINT NOT NULL,
	SickLeaveHours SMALLINT NOT NULL,
	CurrentFlag BIT NOT NULL,
	rowguid UNIQUEIDENTIFIER ROWGUIDCOL  NOT NULL,
	ModifiedDate DATETIME NOT NULL,);
GO

INSERT INTO Collation_Test.dbo.Spanish_Employees
SELECT
	*
FROM AdventureWorks2014.HumanResources.Employee;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Verify the collation of the new database.
USE Collation_Test;
SELECT SERVERPROPERTY('Collation') AS ServerDefaultCollation;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Some test queries that illustrate the differences between the Latin and Traditional Spanish collations.
SELECT
	*
FROM AdventureWorks2014.HumanResources.Employee
WHERE JobTitle LIKE 'C%'
ORDER BY JobTitle;

SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
WHERE JobTitle LIKE 'C%'
ORDER BY JobTitle;

SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
WHERE JobTitle LIKE 'CH%'
ORDER BY JobTitle;

SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
WHERE JobTitle BETWEEN 'C' AND 'D'
ORDER BY JobTitle;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Forcing a specific collation in order to ensure that the results sort and filter correctly.
SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
WHERE JobTitle COLLATE SQL_Latin1_General_CP1_CI_AS LIKE 'C%'
ORDER BY JobTitle COLLATE SQL_Latin1_General_CP1_CI_AS;

SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
WHERE JobTitle COLLATE SQL_Latin1_General_CP1_CI_AS BETWEEN 'C' AND 'D'
ORDER BY JobTitle COLLATE SQL_Latin1_General_CP1_CI_AS;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Data from different collations cannot be directly compared.  The first SELECT below will throw an error.
SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
INNER JOIN AdventureWorks2014.HumanResources.Employee
ON Spanish_Employees.LoginID = Employee.LoginID;
-- This fixes the error by resolving the collation conflict in the join.
SELECT
	*
FROM Collation_Test.dbo.Spanish_Employees
INNER JOIN AdventureWorks2014.HumanResources.Employee
ON Spanish_Employees.LoginID = Employee.LoginID COLLATE Traditional_Spanish_CI_AS
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Example of a collation conflict when using a table variable.
USE AdventureWorks2014
GO

DECLARE @temp_employees TABLE
(	id INT NOT NULL IDENTITY(1,1),
	LoginID NVARCHAR(256) NOT NULL	);

INSERT INTO @temp_employees
	(LoginID)
SELECT TOP 50
	LoginID
FROM AdventureWorks2014.HumanResources.Employee
ORDER BY Employee.JobTitle;

SELECT
	Spanish_Employees.NationalIDNumber,
	Spanish_Employees.LoginID,
	Spanish_Employees.JobTitle,
	Spanish_Employees.BirthDate,
	Spanish_Employees.HireDate
FROM Collation_Test.dbo.Spanish_Employees
WHERE Spanish_Employees.LoginID IN
	(SELECT LoginID FROM @temp_employees);
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Resolving the collation conflict by defaulting to the server's default collation in a search.
USE AdventureWorks2014
GO

DECLARE @sql_command NVARCHAR(MAX);
DECLARE @server_collation NVARCHAR(50);
SELECT @server_collation = CAST(SERVERPROPERTY('Collation') AS NVARCHAR(50));

SELECT @sql_command = '

DECLARE @temp_employees TABLE
(	id INT NOT NULL IDENTITY(1,1),
	LoginID NVARCHAR(256) NOT NULL	);

INSERT INTO @temp_employees
	(LoginID)
SELECT TOP 50
	LoginID
FROM AdventureWorks2014.HumanResources.Employee
ORDER BY Employee.JobTitle;

SELECT
	Spanish_Employees.NationalIDNumber,
	Spanish_Employees.LoginID,
	Spanish_Employees.JobTitle,
	Spanish_Employees.BirthDate,
	Spanish_Employees.HireDate
FROM Collation_Test.dbo.Spanish_Employees
WHERE Spanish_Employees.LoginID IN
	(SELECT LoginID COLLATE ' + @server_collation + ' FROM @temp_employees);'

EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Resolving the collation conflict by defaulting to a database's default collation in a search.
USE master
GO
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @database_name NVARCHAR(128) = 'Collation_Test';

DECLARE @collation_name NVARCHAR(50);
SELECT @collation_name = collation_name
FROM sys.databases WHERE databases.name = @database_name;

SELECT @sql_command = '
SELECT
	Spanish_Employees.NationalIDNumber,
	Spanish_Employees.LoginID,
	Spanish_Employees.JobTitle,
	Spanish_Employees.BirthDate,
	Spanish_Employees.HireDate
FROM Collation_Test.dbo.Spanish_Employees
WHERE Spanish_Employees.LoginID IN
	(SELECT TOP 50 LoginID COLLATE ' + @collation_name + '
	 FROM AdventureWorks2014.HumanResources.Employee ORDER BY LoginID COLLATE ' + @collation_name + ')';

EXEC sp_executesql @sql_command;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Create the Database_Log table, which will be used for an archiving demonstration.
SET NOCOUNT ON;
IF EXISTS (SELECT * FROM sys.tables WHERE tables.name = 'Database_Log')
BEGIN
	DROP TABLE dbo.Database_Log;
END

-- Create and populate a test table for an archiving demo
CREATE TABLE dbo.Database_Log
	(log_id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_Database_Log PRIMARY KEY CLUSTERED,
	 Log_Time DATETIME,
	 Log_Data NVARCHAR(1000));

DECLARE @datetime DATETIME = CURRENT_TIMESTAMP;
DECLARE @datediff TABLE
	(previous_hour SMALLINT);
DECLARE @count SMALLINT = 0;
WHILE @count <= 360
BEGIN
	INSERT INTO @datediff
		(previous_hour)
	SELECT @count;

	SELECT @count = @count + 1
END

SELECT @count = 0;
WHILE @count <= 1000
BEGIN
	INSERT INTO Database_Log
		(Log_Time, Log_Data)
	SELECT
		DATEADD(HOUR, -1 * previous_hour, CURRENT_TIMESTAMP),
		CAST(DATEADD(HOUR, -1 * previous_hour, CURRENT_TIMESTAMP) AS NVARCHAR)
	FROM @datediff;

	SELECT @count = @count + 1;
END
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Script that will increase the size of our data in order to improve this demo.
DECLARE @year_offset TINYINT = 5;

WHILE @year_offset > 0
BEGIN
	INSERT INTO dbo.Database_Log
		(Log_Time, Log_Data)
	SELECT TOP 10000
		DATEADD(YEAR, -1 * @year_offset, Log_Time),
		CAST(DATEADD(YEAR, -1 * @year_offset, Log_Time) AS NVARCHAR)
	FROM Database_Log

	SELECT @year_offset = @year_offset - 1;
END
GO

SELECT COUNT(*) FROM Database_Log;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using dynamic SQL to archive data into dynamically named tables.
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX) = '@start_of_week DATETIME, @end_of_week DATETIME';
DECLARE @min_datetime DATETIME;
SELECT @min_datetime = MIN(Log_Time) FROM Database_Log;
DECLARE @previous_min_time DATETIME = '1/1/1900';
DECLARE @start_of_week DATETIME = CAST(DATEADD(dd, -1 * (DATEPART(dw, @min_datetime) - 1), @min_datetime) AS DATE);
DECLARE @end_of_week DATETIME = DATEADD(WEEK, 1, @start_of_week);
DECLARE @current_year SMALLINT;
DECLARE @current_week TINYINT;
DECLARE @database_name NVARCHAR(128);
DECLARE @table_name NVARCHAR(128);

WHILE (@previous_min_time <> @min_datetime)
BEGIN
	SELECT @current_year = DATEPART(YEAR, @start_of_week);
	SELECT @current_week = DATEPART(WEEK, @start_of_week);
	SELECT @database_name = 'Database_Log_' + CAST(@current_year AS NVARCHAR);
	SELECT @table_name = 'Database_Log_' + CAST(@current_year AS NVARCHAR) + '_' + CAST(@current_week AS NVARCHAR)

	-- Create the yearly database if it does not already exist
	IF NOT EXISTS (SELECT * FROM sys.databases WHERE databases.name = @database_name)
	BEGIN
		SELECT @sql_command = 'CREATE DATABASE [' + @database_name + ']';
		EXEC sp_executesql @sql_command;
	END
	-- Create the weekly table if it does not already exist
	SELECT @sql_command = '
	USE [' + @database_name + '];
	IF NOT EXISTS (SELECT * FROM sys.tables WHERE tables.name = ''' + @table_name + ''')
	BEGIN
		CREATE TABLE [dbo].[' + @table_name + ']
		(Log_Id INT NOT NULL CONSTRAINT PK_Database_Log_' + CAST(@current_year AS NVARCHAR) + '_' + CAST(@current_week AS NVARCHAR) + ' PRIMARY KEY CLUSTERED,
		 Log_Time DATETIME,
		 Log_Data NVARCHAR(1000));
	END'
	EXEC sp_executesql @sql_command;

	SELECT @sql_command = '
	INSERT INTO [' + @database_name + '].[dbo].[' + @table_name + ']
		(Log_Id, Log_Time, Log_Data)
	SELECT
		Log_Id,
		Log_Time,
		Log_Data
	FROM AdventureWorks2014.dbo.Database_Log
	WHERE Log_Time >= @start_of_week
	AND Log_Time <= @end_of_week
	AND Log_Time < DATEADD(WEEK, -1, CURRENT_TIMESTAMP);

	DELETE
	FROM AdventureWorks2014.dbo.Database_Log
	WHERE Log_Time >= @start_of_week
	AND Log_Time <= @end_of_week
	AND Log_Time < DATEADD(WEEK, -1, CURRENT_TIMESTAMP);'

	EXEC sp_executesql @sql_command, @parameter_list, @start_of_week, @end_of_week

	SELECT @previous_min_time = @min_datetime;
	SELECT @min_datetime = MIN(Log_Time) FROM Database_Log;
	SELECT @start_of_week = CAST(DATEADD(dd, -1 * (DATEPART(dw, @min_datetime) - 1), @min_datetime) AS DATE);
	SELECT @end_of_week = DATEADD(WEEK, 1, @start_of_week);
END
GO

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Review one of the archive tables created in the previous example.
SELECT
	*
FROM Database_Log_2011.dbo.Database_Log_2011_48
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using a dynamic pivot that returns a count of employees' hire year by job title.
DECLARE @hire_date_years TABLE
	(hire_date_year NVARCHAR(50));

INSERT INTO @hire_date_years
	(hire_date_year)
SELECT DISTINCT
	DATEPART(YEAR, Employee.HireDate)
FROM HumanResources.Employee;

DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
SELECT
	*
FROM
(	SELECT
		Employee.BusinessEntityID,
		Employee.JobTitle,
		DATEPART(YEAR, Employee.HireDate) AS HireDate_Year
	FROM HumanResources.Employee
) EMPLOYEE_DATA
PIVOT
(	COUNT(BusinessEntityID)
	FOR HireDate_Year IN (';

SELECT @sql_command = @sql_command + '[' + hire_date_year + '], '
FROM @hire_date_years;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Dynamic SQL that creates a customized view with a variable column list.
IF EXISTS (SELECT * FROM sys.views WHERE views.name = 'v_job_title_year_summary')
BEGIN
	DROP VIEW v_job_title_year_summary
END
GO

DECLARE @hire_date_years TABLE
	(hire_date_year NVARCHAR(50));

INSERT INTO @hire_date_years
	(hire_date_year)
SELECT DISTINCT
	DATEPART(YEAR, Employee.HireDate)
FROM HumanResources.Employee;

DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
CREATE VIEW dbo.v_job_title_year_summary
WITH SCHEMABINDING
AS
SELECT
	JobTitle,'

SELECT @sql_command = @sql_command + '
[' + hire_date_year + '], '
FROM @hire_date_years;

SELECT @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT @sql_command = @sql_command + '
FROM
(	SELECT
		Employee.BusinessEntityID,
		Employee.JobTitle,
		DATEPART(YEAR, Employee.HireDate) AS HireDate_Year
	FROM HumanResources.Employee
) EMPLOYEE_DATA
PIVOT
(	COUNT(BusinessEntityID)
	FOR HireDate_Year IN (';

SELECT @sql_command = @sql_command + '[' + hire_date_year + '], '
FROM @hire_date_years;

SELECT @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT @sql_command = @sql_command + '	)) PIVOT_DATA';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Update some data that is used in the dynamic view above.
UPDATE HumanResources.Employee
SET HireDate = '1/1/2015'
WHERE BusinessEntityID = 282

UPDATE HumanResources.Employee
SET HireDate = '1/1/2014'
WHERE BusinessEntityID IN (260, 285)
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Note that the newly updated data is NOT yet reflected in the schema of the dynamic view.
-- The view must be refreshed or recreated in order for the new data to appear.
SELECT
	*
FROM dbo.v_job_title_year_summary
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Stred procedure that will drop and create a dynamically generated view.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'create_v_job_title_year_summary')
BEGIN
	DROP PROCEDURE dbo.create_v_job_title_year_summary;
END
GO
CREATE PROCEDURE dbo.create_v_job_title_year_summary
AS
BEGIN
	IF EXISTS (SELECT * FROM sys.views WHERE views.name = 'v_job_title_year_summary')
	BEGIN
		DROP VIEW v_job_title_year_summary;
	END

	DECLARE @hire_date_years TABLE
		(hire_date_year NVARCHAR(50));

	INSERT INTO @hire_date_years
		(hire_date_year)
	SELECT DISTINCT
		DATEPART(YEAR, Employee.HireDate)
	FROM HumanResources.Employee;

	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = '
	CREATE VIEW dbo.v_job_title_year_summary
	WITH SCHEMABINDING
	AS
	SELECT
		JobTitle,'

	SELECT @sql_command = @sql_command + '
	[' + hire_date_year + '], '
	FROM @hire_date_years;

	SELECT @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

	SELECT @sql_command = @sql_command + '
	FROM
	(	SELECT
			Employee.BusinessEntityID,
			Employee.JobTitle,
			DATEPART(YEAR, Employee.HireDate) AS HireDate_Year
		FROM HumanResources.Employee
	) EMPLOYEE_DATA
	PIVOT
	(	COUNT(BusinessEntityID)
		FOR HireDate_Year IN (';

	SELECT @sql_command = @sql_command + '[' + hire_date_year + '], '
	FROM @hire_date_years;

	SELECT @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

	SELECT @sql_command = @sql_command + '	)) PIVOT_DATA';

	PRINT @sql_command;
	EXEC sp_executesql @sql_command;
END
GO
-- Run the proc to generate the new view.
EXEC dbo.create_v_job_title_year_summary;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Verify the contents of the new view.
SELECT
	*
FROM dbo.v_job_title_year_summary
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
