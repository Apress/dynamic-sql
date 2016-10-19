/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 4: Permissions and Security.

	These demos illustrate how to control security within SQL Server and best practices for security when working with dynamic SQL.
*/
-- Simple stored proc that demonstrates ownership chaining.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'ownership_chaining_example')
BEGIN
	DROP PROCEDURE dbo.ownership_chaining_example;
END
GO

CREATE PROCEDURE dbo.ownership_chaining_example
AS
BEGIN
	SET NOCOUNT ON;
	-- Select the current security context, for reference
	SELECT SUSER_SNAME() AS security_context_no_dynamic_sql;
	SELECT COUNT(*) AS table_count_no_dynamic_sql FROM Person.Person;

	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = 'SELECT SUSER_SNAME() AS security_context_in_dynamic_sql;
	
	SELECT COUNT(*) AS table_count_in_dynamic_sql FROM Person.Person';

	EXEC sp_executesql @sql_command;
END
GO

EXEC dbo.ownership_chaining_example;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of how ownership chaining is not used when executing dynamic SQL, and can create unexpected results.
CREATE USER VeryLimitedUser WITHOUT LOGIN; 
GO
CREATE ROLE VeryLimitedRole; 
GO
EXEC sys.sp_addrolemember 'VeryLimitedRole', 'VeryLimitedUser'; 
GO
GRANT EXECUTE ON dbo.ownership_chaining_example TO VeryLimitedRole; 
GO 
EXECUTE AS USER = 'VeryLimitedUser'; 
GO

EXEC dbo.ownership_chaining_example; 
GO 
REVERT; 
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- How to collect user information to verify security context
SELECT SUSER_SNAME() AS SUSER_SNAME, USER_NAME() AS USER_NAME, ORIGINAL_LOGIN() AS ORIGINAL_LOGIN;
GO
EXECUTE AS USER = 'VeryLimitedUser'; 
SELECT SUSER_SNAME() AS SUSER_SNAME, USER_NAME() AS USER_NAME, ORIGINAL_LOGIN() AS ORIGINAL_LOGIN;
GO
EXECUTE AS USER = 'Edward';
GO
REVERT; 
GO
SELECT SUSER_SNAME() AS SUSER_SNAME, USER_NAME() AS USER_NAME, ORIGINAL_LOGIN() AS ORIGINAL_LOGIN;
GO
EXECUTE AS USER = 'VeryLimitedUser' WITH NO REVERT;
REVERT;
EXECUTE AS USER = 'Edward';
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Using EXECUTE AS OWNER when managing security within a stored procedure.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'ownership_chaining_example')
BEGIN
	DROP PROCEDURE dbo.ownership_chaining_example;
END
GO

CREATE PROCEDURE dbo.ownership_chaining_example
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;
	-- Select the current security context, for reference
	SELECT SUSER_SNAME() AS security_context_no_dynamic_sql;
	SELECT COUNT(*) AS table_count_no_dynamic_sql FROM Person.Person;

	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = 'SELECT SUSER_SNAME() AS security_context_in_dynamic_sql;
	
	SELECT COUNT(*) AS table_count_in_dynamic_sql FROM Person.Person';

	EXEC sp_executesql @sql_command;
END
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Results of using EXECUTE AS CALLER in a stored procedure definition.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'ownership_chaining_example')
BEGIN
	DROP PROCEDURE dbo.ownership_chaining_example;
END
GO

CREATE PROCEDURE dbo.ownership_chaining_example
WITH EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	-- Select the current security context, for reference
	SELECT SUSER_SNAME() AS security_context_no_dynamic_sql;
	SELECT COUNT(*) AS table_count_no_dynamic_sql FROM Person.Person;

	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = 'SELECT SUSER_SNAME() AS security_context_in_dynamic_sql;
	
	SELECT COUNT(*) AS table_count_in_dynamic_sql FROM Person.Person';

	EXEC sp_executesql @sql_command;
END
GO

EXEC dbo.ownership_chaining_example;
GO
GRANT EXECUTE ON dbo.ownership_chaining_example TO VeryLimitedRole; 
GO
EXECUTE AS USER = 'VeryLimitedUser';
EXEC dbo.ownership_chaining_example;
REVERT;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Embedding a security context change within dyanmic SQL.
CREATE LOGIN EdwardJr WITH PASSWORD = 'AntiSemiJoin17', DEFAULT_DATABASE = AdventureWorks2014;
GO
USE AdventureWorks2014
GO
CREATE USER EdwardJr FROM LOGIN EdwardJr;
EXEC sp_addrolemember 'db_owner', 'EdwardJr';
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'ownership_chaining_example')
BEGIN
	DROP PROCEDURE dbo.ownership_chaining_example;
END
GO

CREATE PROCEDURE dbo.ownership_chaining_example
AS
BEGIN
	SET NOCOUNT ON;
	-- Select the current security context, for reference
	SELECT SUSER_SNAME() AS security_context_no_dynamic_sql;
	SELECT COUNT(*) AS table_count_no_dynamic_sql FROM Person.Person;

	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = 'EXECUTE AS LOGIN = ''EdwardJr'';
	SELECT SUSER_SNAME() AS security_context_in_dynamic_sql;
	
	SELECT COUNT(*) AS table_count_in_dynamic_sql FROM Person.Person';

	EXEC sp_executesql @sql_command;
END
GO

EXEC dbo.ownership_chaining_example;

GRANT EXECUTE ON dbo.ownership_chaining_example TO VeryLimitedRole; 
EXECUTE AS USER = 'VeryLimitedUser';
EXEC dbo.ownership_chaining_example;
REVERT;
GO
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-- TSQL that will find instances of text in a variety of SQL Server objects.  Will search:
-- Stored procedures, views, functions, triggers, constraints, tables, columns, indexes, index columns, and jobs.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'search_all_schema')
BEGIN
	DROP PROCEDURE dbo.search_all_schema
END
GO

CREATE PROCEDURE dbo.search_all_schema
	@searchString NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	-- This is the string you want to search databases and jobs for.  MSDB, model and any databases named like tempDB will be ignored
	SET @searchString = '%' + @searchString + '%';
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @database_name NVARCHAR(MAX);
	DECLARE @databases TABLE (database_name NVARCHAR(MAX));

	IF EXISTS (SELECT * FROM tempdb.sys.tables WHERE name = '##object_data')
	BEGIN
		DROP TABLE ##object_data;
	END

	CREATE TABLE ##object_data
	(
		database_name NVARCHAR(MAX),
		table_name SYSNAME,
		objectname SYSNAME,
		object_type NVARCHAR(MAX)
	);

	IF EXISTS (SELECT * FROM tempdb.sys.tables WHERE name = '##index_data')
	BEGIN
		DROP TABLE ##index_data;
	END

	CREATE TABLE ##index_data
	(
		database_name NVARCHAR(MAX),
		table_name SYSNAME,
		index_name SYSNAME,
		key_column_list NVARCHAR(MAX),
		include_column_list NVARCHAR(MAX)
	);

	INSERT INTO @databases
		(database_name)
	SELECT
		name
	FROM sys.databases
	WHERE name NOT IN ('msdb', 'model', 'tempdb')
	AND state_desc <> 'OFFLINE';

	DECLARE DBCURSOR CURSOR FOR SELECT database_name FROM @databases;
	OPEN DBCURSOR;
	FETCH NEXT FROM DBCURSOR INTO @database_name;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @sql = '
		USE ' + @database_name + ';

		WITH CTE_SCHEMA_METADATA AS (
			SELECT db_name() AS database_name, '''' AS table_name, o.Name AS objectname, CASE o.Type
				WHEN ''P'' THEN ''Stored Procedure'' WHEN ''TR'' THEN ''Trigger'' WHEN ''V'' THEN ''View'' WHEN ''C'' THEN ''Check Constraint'' WHEN ''D'' THEN ''Default'' WHEN ''FN'' THEN ''Scalar Function'' WHEN ''IF'' THEN ''Inline Function''
				WHEN ''F'' THEN ''Foreign Key'' WHEN ''PK'' THEN ''Primary Key'' WHEN ''R'' THEN ''Rule'' WHEN ''TA'' THEN ''Assembly Trigger'' WHEN ''UQ'' THEN ''Unique Constraint'' WHEN ''TF'' THEN ''Table-Valued Function'' ELSE o.Type END AS object_type
			-- Views, stored procedures, triggers, check constraints, default constraints, and rules.
			FROM
			(
			SELECT id,
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 1 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 2 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 3 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 4 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 5 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 6 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 7 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 8 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 9 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 10 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 11 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 12 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 13 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 14 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 15 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 16 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 17 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 18 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 19 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 20 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 21 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 22 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 23 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 24 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 25 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 26 THEN sc.text END), '''') AS NVARCHAR(max)) +
			CAST(COALESCE(MIN(CASE WHEN sc.colId = 27 THEN sc.text END), '''') AS NVARCHAR(max)) [text]
			FROM syscomments SC
			WHERE SC.colId IS NOT NULL
			GROUP BY id
			) C
			INNER JOIN sysobjects O
			ON C.id = O.id
			WHERE C.text LIKE ''' + @searchString + '''
			  AND NAME NOT LIKE ''%syncobj%''
			UNION ALL
			SELECT db_name() AS database_name, ST.name AS table_name, '''' AS objectname, ''Table'' AS object_type -- Tables (name only)
			FROM sys.tables ST
			WHERE ST.name LIKE ''' + @searchString + '''
			UNION ALL
			SELECT db_name() AS database_name, ST.name AS table_name, SC.name AS column_name, ''Column'' AS object_type -- Columns
			FROM sys.tables ST
			INNER JOIN sys.columns SC
			ON ST.object_id = SC.object_id
			WHERE SC.name LIKE ''' + @searchString + '''
			UNION ALL
			SELECT
				db_name() AS database_name, ST.name AS table_name, SI.name AS column_name, ''Index'' AS object_type -- Indexes (name only)
			FROM sys.indexes SI
			INNER JOIN sys.tables ST
			ON ST.object_id = SI.object_id
			WHERE SI.name LIKE ''' + @searchString + ''')
		INSERT INTO ##object_data
			(database_name, table_name, objectname, object_type)
		SELECT
			*
		FROM CTE_SCHEMA_METADATA
		ORDER BY object_type ASC, objectname ASC;

		WITH CTE_INDEX_COLUMNS AS (
			SELECT -- User indexes (with column name matching search string)
				db_name() AS database_name,
				TABLE_DATA.name AS table_name,
				INDEX_DATA.name AS index_name,
				STUFF(( SELECT  '', '' + SC.name
						FROM sys.tables AS ST
						INNER JOIN sys.indexes SI
						ON ST.object_id = SI.object_id
						INNER JOIN sys.index_columns IC
						ON SI.object_id = IC.object_id
						AND SI.index_id = IC.index_id
						INNER JOIN sys.all_columns SC
						ON ST.object_id = SC.object_id
						AND IC.column_id = SC.column_id
						WHERE INDEX_DATA.object_id = SI.object_id
						AND INDEX_DATA.index_id = SI.index_id
						AND IC.is_included_column = 0
						ORDER BY IC.key_ordinal
					FOR XML PATH('''')), 1, 2, '''') AS key_column_list,
					STUFF(( SELECT  '', '' + SC.name
						FROM sys.tables AS ST
						INNER JOIN sys.indexes SI
						ON ST.object_id = SI.object_id
						INNER JOIN sys.index_columns IC
						ON SI.object_id = IC.object_id
						AND SI.index_id = IC.index_id
						INNER JOIN sys.all_columns SC
						ON ST.object_id = SC.object_id
						AND IC.column_id = SC.column_id
						WHERE INDEX_DATA.object_id = SI.object_id
						AND INDEX_DATA.index_id = SI.index_id
						AND IC.is_included_column = 1
						ORDER BY IC.key_ordinal
					FOR XML PATH('''')), 1, 2, '''') AS include_column_list,
					''Index Column'' AS object_type
			FROM sys.indexes INDEX_DATA
			INNER JOIN sys.tables TABLE_DATA
			ON TABLE_DATA.object_id = INDEX_DATA.object_id
			WHERE TABLE_DATA.is_ms_shipped = 0	)
		INSERT INTO ##index_data
			(database_name, table_name, index_name, key_column_list, include_column_list)
		SELECT
			database_name, table_name, index_name, key_column_list, ISNULL(include_column_list, '''') AS include_column_list
		FROM CTE_INDEX_COLUMNS
		WHERE CTE_INDEX_COLUMNS.key_column_list LIKE ''' + @searchString + '''
		OR CTE_INDEX_COLUMNS.include_column_list LIKE ''' + @searchString + ''';'
		EXEC sp_executesql @sql;

		FETCH NEXT FROM DBCURSOR INTO @database_name;
	END

	SELECT
		*
	FROM ##object_data;

	SELECT
		*
	FROM ##index_data

	-- Search to see if text exists in any job steps
	SELECT
		j.job_id,
		s.srvname,
		j.name,
		js.step_id,
		js.command,
		j.enabled
	FROM msdb.dbo.sysjobs j
	INNER JOIN msdb.dbo.sysjobsteps js
	ON js.job_id = j.job_id
	INNER JOIN master.dbo.sysservers s
	ON s.srvid = j.originating_server_id
	WHERE js.command LIKE @searchString;

	DROP TABLE ##object_data;
	DROP TABLE ##index_data;
END
GO

EXEC dbo.search_all_schema N'BusinessEntityContact';
EXEC dbo.search_all_schema N'PK_Sales';
EXEC dbo.search_all_schema N'Production.Product';
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-- Scripts to aid in auditing security and clean up as needed.
-- List all logins and roles on the server
SELECT
	server_principals.name AS Login_Name,
	server_principals.type_desc AS Account_Type
FROM sys.server_principals 
WHERE server_principals.name NOT LIKE '%##%'
ORDER BY server_principals.name, server_principals.type_desc

-- Restrict list to logins only, omitting server roles.
SELECT
	server_principals.name AS Login_Name,
	server_principals.type_desc AS Account_Type
FROM sys.server_principals 
WHERE server_principals.type IN ('U', 'S', 'G')
and server_principals.name not like '%##%'
ORDER BY server_principals.name, server_principals.type_desc
GO

-- Add some permissions, to make this a bit more interesting:
GRANT EXECUTE ON dbo.ownership_chaining_example TO EdwardJr;
GRANT EXECUTE ON dbo.search_products TO EdwardJr;
GRANT EXECUTE ON dbo.search_all_schema TO Edward;
GO 

-- Identify customized user securables
SELECT
    OBJECT_NAME(database_permissions.major_id) AS object_name,
	USER_NAME(database_permissions.grantee_principal_id) AS role_name,
	database_permissions.permission_name
FROM sys.database_permissions
WHERE database_permissions.class = 1
AND OBJECTPROPERTY(database_permissions.major_id, 'IsMSSHipped') = 0
ORDER BY OBJECT_NAME(database_permissions.major_id)
GO

CREATE TABLE #login_user_mapping (
    login_name NVARCHAR(MAX),
    database_name NVARCHAR(MAX),
    user_name NVARCHAR(MAX), 
    alias_name NVARCHAR(MAX))

INSERT INTO #login_user_mapping 
EXEC master.dbo.sp_msloginmappings 

SELECT
	* 
FROM #login_user_mapping 
ORDER BY database_name,
		 user_name

DROP TABLE #login_user_mapping
GO
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-- Dynamic SQL to check DB integrity of all databases using DBCC CHECKDB.
DECLARE @databases TABLE
	(database_name NVARCHAR(MAX));

INSERT INTO @databases
	(database_name)
SELECT
	databases.name
FROM sys.databases;

DECLARE @sql_command NVARCHAR(MAX) = '';

SELECT @sql_command = @sql_command + '
DBCC CHECKDB (' + database_name + ');'
FROM @databases;

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-- Dynamic SQL that gathers row counts of all tables on this SQL Server instance.
SET NOCOUNT ON;

DECLARE @databases TABLE
	(database_name NVARCHAR(MAX));

CREATE TABLE ##tables
	(database_name NVARCHAR(MAX),
	 schema_name NVARCHAR(MAX),
	 table_name NVARCHAR(MAX),
	 row_count BIGINT);

DECLARE @sql_command NVARCHAR(MAX) = '';

INSERT INTO @databases
	(database_name)
SELECT
	databases.name
FROM sys.databases
WHERE databases.name <> 'tempdb';

DECLARE @current_database NVARCHAR(MAX);
WHILE EXISTS (SELECT * FROM @databases)
BEGIN
	SELECT TOP 1 @current_database = database_name FROM @databases;
	
	SELECT @sql_command = @sql_command + '
		USE [' + @current_database + ']
		INSERT INTO ##tables
			(database_name, schema_name, table_name, row_count)
		SELECT
			''' + @current_database + ''',
			schemas.name,
			tables.name,
			0
		FROM sys.tables
		INNER JOIN sys.schemas
		ON tables.schema_id = schemas.schema_id';
	EXEC sp_executesql @sql_command;
	DELETE FROM @databases WHERE database_name = @current_database;
END

SELECT @sql_command = '';
SELECT @sql_command = @sql_command + '
	UPDATE ##tables
		SET row_count = (SELECT COUNT(*)
	FROM [' + database_name + '].[' + schema_name + '].[' + table_name + '])
	WHERE database_name = ''' + database_name + '''
	AND schema_name = ''' + schema_name + '''
	AND table_name = ''' + table_name + ''';'
FROM ##tables;

SELECT (LEN(@sql_command) * 16) + 2 AS length_of_large_sql_command
EXEC sp_executesql @sql_command;

SELECT
	*
FROM ##tables;

DROP TABLE ##tables;
GO
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-- Dynamic SQL to gather row counts using batched command script creation.
SET NOCOUNT ON;

DECLARE @databases TABLE
	(database_name NVARCHAR(MAX));

CREATE TABLE ##tables
	(database_name NVARCHAR(MAX),
	 schema_name NVARCHAR(MAX),
	 table_name NVARCHAR(MAX),
	 row_count BIGINT);

DECLARE @sql_command NVARCHAR(MAX) = '';

INSERT INTO @databases
	(database_name)
SELECT
	databases.name
FROM sys.databases
WHERE databases.name <> 'tempdb';

DECLARE @current_database NVARCHAR(MAX);
WHILE EXISTS (SELECT * FROM @databases)
BEGIN
	SELECT TOP 1 @current_database = database_name FROM @databases;

	SELECT @sql_command = '';

	SELECT @sql_command = @sql_command + '
		USE [' + @current_database + ']
		INSERT INTO ##tables
			(database_name, schema_name, table_name, row_count)
		SELECT
			''' + @current_database + ''',
			schemas.name,
			tables.name,
			0
		FROM sys.tables
		INNER JOIN sys.schemas
		ON tables.schema_id = schemas.schema_id';
	EXEC sp_executesql @sql_command;

	SELECT @sql_command = '';
	SELECT @sql_command = @sql_command + '
		UPDATE ##tables
			SET row_count = (SELECT COUNT(*)
		FROM [' + database_name + '].[' + schema_name + '].[' + table_name + '])
		WHERE database_name = ''' + database_name + '''
		AND schema_name = ''' + schema_name + '''
		AND table_name = ''' + table_name + ''';'
	FROM ##tables
	WHERE database_name = @current_database;

	SELECT (LEN(@sql_command) * 16) + 2 AS length_of_large_sql_command
	EXEC sp_executesql @sql_command;

	DELETE FROM @databases WHERE database_name = @current_database;
END

SELECT
	*
FROM ##tables;

DROP TABLE ##tables;