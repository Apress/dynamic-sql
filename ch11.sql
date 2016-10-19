/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 11: Additional Applications

	Below are a variety of larger, more involved examples of using dynamic SQL.
*/
SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Query that determines index fragmentation for all indexes in a given database.
USE AdventureWorks2014
DECLARE @database_name VARCHAR(100) = 'AdventureWorks2014';

SELECT
	SD.name AS database_name,
	SO.name AS object_name,
	SI.name AS index_name,
	IPS.index_type_desc,
	IPS.page_count,
	IPS.avg_fragmentation_in_percent -- Be sure to filter as much as possible...this can return a lot of data if you don't filter by database and table.
FROM sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL , NULL) IPS
INNER JOIN sys.databases SD
ON SD.database_id = IPS.database_id
INNER JOIN sys.indexes SI
ON SI.index_id = IPS.index_id
INNER JOIN sys.objects SO
ON SO.object_id = SI.object_id
AND IPS.object_id = SO.object_id
WHERE alloc_unit_type_desc = 'IN_ROW_DATA'
AND index_level = 0
AND SD.name = @database_name
ORDER BY IPS.avg_fragmentation_in_percent DESC;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Simple index maintenance solution using dynamic SQL.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'index_maintenance_demo')
BEGIN
	DROP PROCEDURE dbo.index_maintenance_demo;
END
GO

CREATE PROCEDURE dbo.index_maintenance_demo
	@reorganization_percentage TINYINT = 10,
	@rebuild_percentage TINYINT = 35,
	@print_results_only BIT = 1
AS
BEGIN
	DECLARE @sql_command NVARCHAR(MAX) = '';
	DECLARE @parameter_list NVARCHAR(MAX) = '@reorganization_percentage TINYINT, @rebuild_percentage TINYINT'
	DECLARE @database_name NVARCHAR(MAX);
	DECLARE @database_list TABLE
		(database_name NVARCHAR(MAX) NOT NULL);
	
	INSERT INTO @database_list
		(database_name)
	SELECT
		name
	FROM sys.databases
	WHERE databases.name NOT IN ('msdb', 'master', 'TempDB', 'model');

	CREATE TABLE #index_maintenance
	(	database_name NVARCHAR(MAX),
		schema_name NVARCHAR(MAX),
		object_name NVARCHAR(MAX),
		index_name NVARCHAR(MAX),
		index_type_desc NVARCHAR(MAX),
		page_count BIGINT,
		avg_fragmentation_in_percent FLOAT,
		index_operation NVARCHAR(MAX));

	SELECT @sql_command = @sql_command + '
	USE [' + database_name + ']

	INSERT INTO #index_maintenance
		(database_name, schema_name, object_name, index_name, index_type_desc, page_count, avg_fragmentation_in_percent, index_operation)
	SELECT
		CAST(SD.name AS NVARCHAR(MAX)) AS database_name,
		CAST(SS.name AS NVARCHAR(MAX)) AS schema_name,
		CAST(SO.name AS NVARCHAR(MAX)) AS object_name,
		CAST(SI.name AS NVARCHAR(MAX)) AS index_name,
		IPS.index_type_desc,
		IPS.page_count,
		IPS.avg_fragmentation_in_percent, -- Be sure to filter as much as possible...this can return a lot of data if you dont filter by database and table.
		CAST(CASE
			WHEN IPS.avg_fragmentation_in_percent >= @rebuild_percentage THEN ''REBUILD''
			WHEN IPS.avg_fragmentation_in_percent >= @reorganization_percentage THEN ''REORGANIZE''
		END AS NVARCHAR(MAX)) AS index_operation
	FROM sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL , NULL) IPS
	INNER JOIN sys.databases SD
	ON SD.database_id = IPS.database_id
	INNER JOIN sys.indexes SI
	ON SI.index_id = IPS.index_id
	INNER JOIN sys.objects SO
	ON SO.object_id = SI.object_id
	AND IPS.object_id = SO.object_id
	INNER JOIN sys.schemas SS
	ON SS.schema_id = SO.schema_id
	WHERE alloc_unit_type_desc = ''IN_ROW_DATA''
	AND index_level = 0
	AND SD.name = ''' + database_name + '''
	AND IPS.avg_fragmentation_in_percent >= @reorganization_percentage
	AND SI.name IS NOT NULL -- Only review index, not heap data.
	AND SO.is_ms_shipped = 0 -- Do not perform maintenance on system objects
	ORDER BY SD.name ASC;'
	FROM @database_list
	WHERE database_name IN (SELECT name FROM sys.databases);

	EXEC sp_executesql @sql_command, @parameter_list, @reorganization_percentage, @rebuild_percentage;

	SELECT @sql_command = '';
	SELECT @sql_command = @sql_command +
	'	USE [' + database_name + ']
		ALTER INDEX [' + index_name + '] ON [' + schema_name + '].[' + object_name + ']
		' + index_operation + ';
'
	FROM #index_maintenance;

	SELECT * FROM #index_maintenance
	ORDER BY avg_fragmentation_in_percent DESC;

	IF @print_results_only = 1
		PRINT @sql_command;
	ELSE
		EXEC sp_executesql @sql_command;

	DROP TABLE #index_maintenance;
END
GO

EXEC dbo.index_maintenance_demo @reorganization_percentage = 10, @rebuild_percentage = 35, @print_results_only = 1;

EXEC dbo.index_maintenance_demo @reorganization_percentage = 10, @rebuild_percentage = 35, @print_results_only = 0;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- A database backup solution that uses dynamic SQL to manage all databases on a SQL Server.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'backup_plan')
BEGIN
	DROP PROCEDURE dbo.backup_plan;
END
GO

CREATE PROCEDURE dbo.backup_plan
	@differential_and_full_backup_time TIME = '00:00:00', -- Default to midnight
	@full_backup_day TINYINT = 1, -- Default to Sunday
	@backup_location NVARCHAR(MAX) = 'E:\SQLBackups\', -- Default to my backup folder
	@print_output_only BIT = 1
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @current_time TIME = CAST(CURRENT_TIMESTAMP AS TIME);
	DECLARE @current_day TINYINT = DATEPART(DW, CURRENT_TIMESTAMP);
	DECLARE @datetime_string NVARCHAR(MAX) = FORMAT(CURRENT_TIMESTAMP , 'MMddyyyyHHmmss');
	DECLARE @sql_command NVARCHAR(MAX) = '';

	DECLARE @database_list TABLE
		(database_name NVARCHAR(MAX) NOT NULL, recovery_model_desc NVARCHAR(MAX));
	
	INSERT INTO @database_list
		(database_name, recovery_model_desc)
	SELECT
		name,
		recovery_model_desc
	FROM sys.databases
	WHERE databases.name NOT IN ('msdb', 'master', 'TempDB', 'model');

	-- Check if a full backup is to be taken now.
	IF (@current_day = @full_backup_day) AND (@current_time BETWEEN @differential_and_full_backup_time AND DATEADD(MINUTE, 10, @differential_and_full_backup_time))
	BEGIN
		SELECT @sql_command = @sql_command +
		'
		BACKUP DATABASE [' + database_name + ']
		TO DISK = ''' + @backup_location + database_name + '_' + @datetime_string + '.bak'';
		'
		FROM @database_list;

		IF @print_output_only = 1
			PRINT @sql_command;
		ELSE
			EXEC sp_executesql @sql_command;
	END
	ELSE -- Check if a differential backup is to be taken now.
	IF (@current_day <> @full_backup_day) AND (@current_time BETWEEN @differential_and_full_backup_time AND DATEADD(MINUTE, 10, @differential_and_full_backup_time))
	BEGIN
		SELECT @sql_command = @sql_command +
		'
		BACKUP DATABASE [' + database_name + ']
		TO DISK = ''' + @backup_location + database_name + '_' + @datetime_string + '.dif''
		WITH DIFFERENTIAL;
		'
		FROM @database_list;

		IF @print_output_only = 1
			PRINT @sql_command;
		ELSE
			EXEC sp_executesql @sql_command;
	END
	ELSE -- If neither full or differential, then take a transaction log backup
	BEGIN
		SELECT @sql_command = @sql_command +
		'
		BACKUP LOG [' + database_name + ']
		TO DISK = ''' + @backup_location + database_name + '_' + @datetime_string + '.trn''
		'
		FROM @database_list
		WHERE recovery_model_desc = 'FULL';

		IF @print_output_only = 1
			PRINT @sql_command;
		ELSE
			EXEC sp_executesql @sql_command;
	END
END
GO
-- This stored procedure will intelligently determine what sort of backup to run.  This can be worked into a separate parameter as well.
EXEC dbo.backup_plan @differential_and_full_backup_time = '20:00:00', @full_backup_day = 3, @backup_location = 'c:\SQLBackups\', @print_output_only = 0;

EXEC dbo.backup_plan @differential_and_full_backup_time = '20:00:00', @full_backup_day = 1, @backup_location = 'c:\SQLBackups\', @print_output_only = 0;

EXEC dbo.backup_plan @differential_and_full_backup_time = '00:00:00', @full_backup_day = 1, @backup_location = 'c:\SQLBackups\', @print_output_only = 0;
GO
-- Verify the recovery model for all non-system databases on a server.
	SELECT
		name,
		recovery_model_desc
	FROM sys.databases
	WHERE databases.name NOT IN ('msdb', 'master', 'TempDB', 'model');
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Create a table that will be used to save dynamic SQL script output.
CREATE TABLE dbo.sql_command
(	command_id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_sql_commands PRIMARY KEY CLUSTERED,
	sql_command NVARCHAR(MAX) NOT NULL,
	time_stamp DATETIME NOT NULL CONSTRAINT DF_sql_commands_time_stamp DEFAULT (CURRENT_TIMESTAMP)	);
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--  Index maintenance solution with an option that outputs the commands to a file instead of executing them.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'index_maintenance_demo_output')
BEGIN
	DROP PROCEDURE dbo.index_maintenance_demo_output;
END
GO

CREATE PROCEDURE dbo.index_maintenance_demo_output
	@reorganization_percentage TINYINT = 10,
	@rebuild_percentage TINYINT = 35,
	@print_results_to_file_only BIT = 1
AS
BEGIN
	DECLARE @sql_command NVARCHAR(MAX) = '';
	DECLARE @parameter_list NVARCHAR(MAX) = '@reorganization_percentage TINYINT, @rebuild_percentage TINYINT'
	DECLARE @database_name NVARCHAR(MAX);
	DECLARE @database_list TABLE
		(database_name NVARCHAR(MAX) NOT NULL);
	
	INSERT INTO @database_list
		(database_name)
	SELECT
		name
	FROM sys.databases
	WHERE databases.name NOT IN ('msdb', 'master', 'TempDB', 'model');

	CREATE TABLE #index_maintenance
	(	database_name NVARCHAR(MAX),
		schema_name NVARCHAR(MAX),
		object_name NVARCHAR(MAX),
		index_name NVARCHAR(MAX),
		index_type_desc NVARCHAR(MAX),
		page_count BIGINT,
		avg_fragmentation_in_percent FLOAT,
		index_operation NVARCHAR(MAX));

	SELECT @sql_command = @sql_command + '
	USE [' + database_name + ']

	INSERT INTO #index_maintenance
		(database_name, schema_name, object_name, index_name, index_type_desc, page_count, avg_fragmentation_in_percent, index_operation)
	SELECT
		CAST(SD.name AS NVARCHAR(MAX)) AS database_name,
		CAST(SS.name AS NVARCHAR(MAX)) AS schema_name,
		CAST(SO.name AS NVARCHAR(MAX)) AS object_name,
		CAST(SI.name AS NVARCHAR(MAX)) AS index_name,
		IPS.index_type_desc,
		IPS.page_count,
		IPS.avg_fragmentation_in_percent, -- Be sure to filter as much as possible...this can return a lot of data if you dont filter by database and table.
		CAST(CASE
			WHEN IPS.avg_fragmentation_in_percent >= @rebuild_percentage THEN ''REBUILD''
			WHEN IPS.avg_fragmentation_in_percent >= @reorganization_percentage THEN ''REORGANIZE''
		END AS NVARCHAR(MAX)) AS index_operation
	FROM sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL , NULL) IPS
	INNER JOIN sys.databases SD
	ON SD.database_id = IPS.database_id
	INNER JOIN sys.indexes SI
	ON SI.index_id = IPS.index_id
	INNER JOIN sys.objects SO
	ON SO.object_id = SI.object_id
	AND IPS.object_id = SO.object_id
	INNER JOIN sys.schemas SS
	ON SS.schema_id = SO.schema_id
	WHERE alloc_unit_type_desc = ''IN_ROW_DATA''
	AND index_level = 0
	AND SD.name = ''' + database_name + '''
	AND IPS.avg_fragmentation_in_percent >= @reorganization_percentage
	AND SI.name IS NOT NULL -- Only review index, not heap data.
	AND SO.is_ms_shipped = 0 -- Do not perform maintenance on system objects
	ORDER BY SD.name ASC;'
	FROM @database_list
	WHERE database_name IN (SELECT name FROM sys.databases WHERE databases.name NOT IN ('msdb', 'master', 'TempDB', 'model'));

	EXEC sp_executesql @sql_command, @parameter_list, @reorganization_percentage, @rebuild_percentage;

	SELECT @sql_command = '';
	SELECT @sql_command = @sql_command +
	'	USE [' + database_name + ']
		ALTER INDEX [' + index_name + '] ON [' + schema_name + '].[' + object_name + ']
		' + index_operation + ';
'
	FROM #index_maintenance;

	IF @print_results_to_file_only = 1
		INSERT INTO dbo.sql_command
			(sql_command)
		SELECT
			@sql_command
	ELSE
		EXEC sp_executesql @sql_command;

	DROP TABLE #index_maintenance;
END
GO

EXEC dbo.index_maintenance_demo_output @reorganization_percentage = 10, @rebuild_percentage = 35, @print_results_to_file_only = 1;
EXEC dbo.index_maintenance_demo_output @reorganization_percentage = 20, @rebuild_percentage = 50, @print_results_to_file_only = 1;
EXEC dbo.index_maintenance_demo_output @reorganization_percentage = 30, @rebuild_percentage = 75, @print_results_to_file_only = 1;
EXEC dbo.index_maintenance_demo_output @reorganization_percentage = 5, @rebuild_percentage = 10, @print_results_to_file_only = 1;
SELECT * FROM dbo.sql_command;
GO
-------------------------------------------------------------------------------------
-- These are the directories that I used for data, backups, and my server name.  You may use
-- any directories on your computer in order to get similar results.
-- E:\SQLData\
-- E:\SQLBackups\
-- SSANDILE\EDSQLSERVER14
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Backup maintenance script, with the ability to output the command strings to a file, rather than immediately execute.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'backup_plan_output')
BEGIN
	DROP PROCEDURE dbo.backup_plan_output;
END
GO

CREATE PROCEDURE dbo.backup_plan_output
	@differential_and_full_backup_time TIME = '00:00:00', -- Default to midnight
	@full_backup_day TINYINT = 1, -- Default to Sunday
	@backup_location NVARCHAR(MAX) = 'E:\SQLBackups\', -- Default to my backup folder
	@sql_data_location NVARCHAR(MAX) = 'E:\SQLData\', -- Default to my SQL data file folder
	@sql_server_name NVARCHAR(MAX) = 'SSANDILE\EDSQLSERVER14', -- Server name to operate on
	@print_output_to_file_only BIT = 1
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @current_time TIME = CAST(CURRENT_TIMESTAMP AS TIME);
	DECLARE @current_day TINYINT = DATEPART(DW, CURRENT_TIMESTAMP);
	DECLARE @datetime_string NVARCHAR(MAX) = FORMAT(CURRENT_TIMESTAMP , 'MMddyyyyHHmmss');
	DECLARE @sql_command NVARCHAR(MAX) = '';
	DECLARE @bcp_command VARCHAR(4000);

	DECLARE @database_list TABLE
		(database_name NVARCHAR(MAX) NOT NULL, recovery_model_desc NVARCHAR(MAX));
	
	INSERT INTO @database_list
		(database_name, recovery_model_desc)
	SELECT
		name,
		recovery_model_desc
	FROM sys.databases
	WHERE databases.name NOT IN ('msdb', 'master', 'TempDB', 'model');

	-- Check if a full backup is to be taken now.
	IF (@current_day = @full_backup_day) AND (@current_time BETWEEN @differential_and_full_backup_time AND DATEADD(MINUTE, 10, @differential_and_full_backup_time))
	BEGIN
		SELECT @sql_command = @sql_command +
		'BACKUP DATABASE [' + database_name + '] TO DISK = ''''' + @backup_location + database_name + '_' + @datetime_string + '.bak'''';'
		FROM @database_list;

		IF @print_output_to_file_only = 1
			BEGIN
				SELECT @bcp_command =
				'bcp "SELECT ''' + @sql_command + '''" queryout ' + @sql_data_location + 'TempOutput.sql -c -T -S' + @sql_server_name + ' -dAdventureWorks2014';
				EXEC xp_cmdshell @bcp_command;
				SELECT @bcp_command = 'type "' + @sql_data_location + 'TempOutput.sql" >> "' + @sql_data_location + 'QueryOutput.sql"';
				EXEC xp_cmdshell @bcp_command;
			END
		ELSE
			EXEC sp_executesql @sql_command;
	END
	ELSE -- Check if a differential backup is to be taken now.
	IF (@current_day <> @full_backup_day) AND (@current_time BETWEEN @differential_and_full_backup_time AND DATEADD(MINUTE, 10, @differential_and_full_backup_time))
	BEGIN
		SELECT @sql_command = '';
		SELECT @sql_command = @sql_command +
		'BACKUP DATABASE [' + database_name + '] TO DISK = ''''' + @backup_location + database_name + '_' + @datetime_string + '.dif'''' WITH DIFFERENTIAL;'
		FROM @database_list;

		IF @print_output_to_file_only = 1
			BEGIN
				SELECT @bcp_command =
				'bcp "SELECT ''' + @sql_command + '''" queryout ' + @sql_data_location + 'TempOutput.sql -c -T -S' + @sql_server_name + ' -dAdventureWorks2014';
				EXEC xp_cmdshell @bcp_command;
				SELECT @bcp_command = 'type "' + @sql_data_location + 'TempOutput.sql" >> "' + @sql_data_location + 'QueryOutput.sql"';
				EXEC xp_cmdshell @bcp_command;
			END
		ELSE
			EXEC sp_executesql @sql_command;
	END
	ELSE -- If neither full or differential, then take a transaction log backup
	BEGIN
		SELECT @sql_command = '';
		SELECT @sql_command = @sql_command +
		'BACKUP LOG [' + database_name + '] TO DISK = ''''' + @backup_location + database_name + '_' + @datetime_string + '.trn'''''
		FROM @database_list
		WHERE recovery_model_desc = 'FULL';

		IF @print_output_to_file_only = 1
			BEGIN
				SELECT @bcp_command =
				'bcp "SELECT ''' + @sql_command + '''" queryout ' + @sql_data_location + 'TempOutput.sql -c -T -S' + @sql_server_name + ' -dAdventureWorks2014';
				EXEC xp_cmdshell @bcp_command;
				SELECT @bcp_command = 'type "' + @sql_data_location + 'TempOutput.sql" >> "' + @sql_data_location + '\QueryOutput.sql"';
				EXEC xp_cmdshell @bcp_command;
			END
		ELSE
			EXEC sp_executesql @sql_command;
	END
END
GO

EXEC dbo.backup_plan_output @differential_and_full_backup_time = '13:55:00', @full_backup_day = 3, @backup_location = 'E:\SQLBackups\',
	 @sql_data_location = 'E:\SQLData\', @sql_server_name = 'SSANDILE\EDSQLSERVER14', @print_output_to_file_only = 1;
EXEC dbo.backup_plan_output @differential_and_full_backup_time = '13:55:00', @full_backup_day = 1, @backup_location = 'E:\SQLBackups\',
	 @sql_data_location = 'E:\SQLData\', @sql_server_name = 'SSANDILE\EDSQLSERVER14', @print_output_to_file_only = 1;
EXEC dbo.backup_plan_output @differential_and_full_backup_time = '10:00:00', @full_backup_day = 1, @backup_location = 'E:\SQLBackups\',
	 @sql_data_location = 'E:\SQLData\', @sql_server_name = 'SSANDILE\EDSQLSERVER14', @print_output_to_file_only = 1;

-- If xp_cmdshell is needed, this is how to enable it.
EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
EXEC sp_configure 'xp_cmdshell', 1
GO
RECONFIGURE
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Create a log table for the next example.
USE AdventureWorks2014
GO

CREATE TABLE dbo.recent_product_counts
	(	count_id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_recent_product_counts PRIMARY KEY CLUSTERED,
		product_count INT NOT NULL,
		server_name NVARCHAR(128),
		sample_time DATETIME NOT NULL CONSTRAINT DF_recent_product_counts DEFAULT (CURRENT_TIMESTAMP));
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using dynamic SQL and OPENQUERY in order to retrieve data from remote servers.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_product_count_all_servers')
BEGIN
	DROP PROCEDURE dbo.get_product_count_all_servers;
END
GO

CREATE PROCEDURE dbo.get_product_count_all_servers
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sql_command NVARCHAR(MAX) = '';

	SELECT
		name AS server_name
	INTO #servers
	FROM sys.servers;

	SELECT @sql_command = @sql_command + '
	INSERT INTO AdventureWorks2014.dbo.recent_product_counts
		(product_count, server_name)
	SELECT
		product_count,
		''' + server_name + '''
	FROM OPENQUERY([' + server_name + '], ''SELECT COUNT(*) AS product_count FROM AdventureWorks2014.Production.Product WHERE ModifiedDate >= ''''2/8/2014'''''');'
	FROM #servers
	WHERE server_name <> @@SERVERNAME;
	
	SELECT @sql_command = @sql_command + '
	INSERT INTO AdventureWorks2014.dbo.recent_product_counts
		(product_count, server_name)
	SELECT
		COUNT(*),
		@@SERVERNAME
	FROM AdventureWorks2014.Production.Product WHERE ModifiedDate >= ''2/8/2014''';

	EXEC sp_executesql @sql_command;

	DROP TABLE #servers;
END
GO

EXEC dbo.get_product_count_all_servers;

SELECT * FROM dbo.recent_product_counts;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-