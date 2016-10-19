/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 8: Parameter Sniffing

	This SQL provides examples of parameter sniffing, and a variety of ways in which to work with it
	(or against it).
*/
USE AdventureWorks2014 -- Can use any AdventureWorks database for all demos in this book.
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Stored procedure that we will use to read optimization and execution data from the query plan cache.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'read_query_plan_cache')
BEGIN
	DROP PROCEDURE dbo.read_query_plan_cache;
END
GO

CREATE PROCEDURE dbo.read_query_plan_cache
	@text_string NVARCHAR(MAX) = NULL
AS
BEGIN
	SELECT @text_string = '%' + @text_string + '%';
	DECLARE @sql_command NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX) = '@text_string NVARCHAR(MAX)';

	IF @text_string IS NULL
		SELECT @sql_command = '
			SELECT TOP 25
				DB_NAME(execution_plan.dbid) AS database_name,
				cached_plans.objtype AS ObjectType,
				OBJECT_NAME(sql_text.objectid, sql_text.dbid) AS ObjectName,
				query_stats.creation_time,
				query_stats.last_execution_time,
				query_stats.last_worker_time AS cpu_last_execution,
				query_stats.last_logical_reads AS reads_last_execution,
				query_stats.last_elapsed_time AS duration_last_execution,
				query_stats.last_rows AS rows_last_execution,
				cached_plans.size_in_bytes,
				cached_plans.usecounts AS ExecutionCount,
				sql_text.TEXT AS QueryText,
				execution_plan.query_plan,
				cached_plans.plan_handle
			FROM sys.dm_exec_cached_plans cached_plans
			INNER JOIN sys.dm_exec_query_stats query_stats
			ON cached_plans.plan_handle = query_stats.plan_handle
			CROSS APPLY sys.dm_exec_sql_text(cached_plans.plan_handle) AS sql_text
			CROSS APPLY sys.dm_exec_query_plan(cached_plans.plan_handle) AS execution_plan';
	ELSE
		SELECT @sql_command = '
			SELECT TOP 25
				DB_NAME(execution_plan.dbid) AS database_name,
				cached_plans.objtype AS ObjectType,
				OBJECT_NAME(sql_text.objectid, sql_text.dbid) AS ObjectName,
				query_stats.creation_time,
				query_stats.last_execution_time,
				query_stats.last_worker_time AS cpu_last_execution,
				query_stats.last_logical_reads AS reads_last_execution,
				query_stats.last_elapsed_time AS duration_last_execution,
				query_stats.last_rows AS rows_last_execution,
				cached_plans.size_in_bytes,
				cached_plans.usecounts AS ExecutionCount,
				sql_text.TEXT AS QueryText,
				execution_plan.query_plan,
				cached_plans.plan_handle
			FROM sys.dm_exec_cached_plans cached_plans
			INNER JOIN sys.dm_exec_query_stats query_stats
			ON cached_plans.plan_handle = query_stats.plan_handle
			CROSS APPLY sys.dm_exec_sql_text(cached_plans.plan_handle) AS sql_text
			CROSS APPLY sys.dm_exec_query_plan(cached_plans.plan_handle) AS execution_plan
		WHERE sql_text.TEXT LIKE @text_string';

		EXEC sp_executesql @sql_command, @parameter_list, @text_string
END
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- This index will be used in examples below.
CREATE NONCLUSTERED INDEX NCI_production_product_ProductModelID ON Production.Product (ProductModelID) INCLUDE (Name);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Clear the plan cache.  *** ONLY USE THIS DBCC COMMAND IN DEV ENVIRONMENTS WHERE PERFORMANCE IS NOT IMPORTANT! ***
DBCC FREEPROCCACHE;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Demo usage of the read_query_plan_cache stored procedure.
EXEC dbo.read_query_plan_cache 'person';
-- How to remove a specific plan from cache.  The plan handle will vary each time, so the hex value below will need to be replaced with the new value.
DBCC FREEPROCCACHE (0x06000700E8C6530730F36E6B0300000001000000000000000000000000000000000000000000000000000000);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Create a simple stored procedure that will get all products from production.product with a specific range of model IDs
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_products_by_model')
BEGIN
	DROP PROCEDURE dbo.get_products_by_model;
END
GO
CREATE PROCEDURE dbo.get_products_by_model (@firstProductModelID INT, @lastProductModelID INT) 
AS
BEGIN
	SELECT
		PRODUCT.Name,
		PRODUCT.ProductID,
		PRODUCT.ProductModelID,
		PRODUCT.ProductNumber,
		MODEL.Name
	FROM Production.Product PRODUCT
	INNER JOIN Production.ProductModel MODEL
	ON MODEL.ProductModelID = PRODUCT.ProductModelID
	WHERE PRODUCT.ProductModelID BETWEEN @firstProductModelID AND @lastProductModelID;
END

-- Execute the stored proc with a narrow range of model numbers
EXEC get_products_by_model 120, 125;

EXEC dbo.read_query_plan_cache 'get_products_by_model';
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Clear the plan cache
DBCC FREEPROCCACHE;

-- Execute the stored procedure with a wide range of model numbers.  Note the difference in execution plan and subtree cost.
-- Also note that each execution adds to the count in the plan cache.
EXEC get_products_by_model 0, 10000;

EXEC get_products_by_model 0, 10000;
EXEC get_products_by_model 0, 10000;
EXEC get_products_by_model 0, 10000;
EXEC get_products_by_model 0, 10000;
EXEC get_products_by_model 0, 10000;

EXEC dbo.read_query_plan_cache 'get_products_by_model';
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
DBCC FREEPROCCACHE;
EXEC get_products_by_model 120, 125;
-- Without clearing the cache, run the same proc with the wide range of product model IDs.  Note the reuse of the last execution plan, despite not being the optimal plan.
EXEC get_products_by_model 0, 10000;

EXEC dbo.read_query_plan_cache 'get_products_by_model';

DROP PROCEDURE get_products_by_model;
DROP INDEX NCI_production_product_ProductModelID ON Production.Product;
GO

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Add a new sales person, as well as existing orders to reference them.
INSERT INTO Sales.SalesPerson
	(BusinessEntityID, TerritoryID, SalesQuota, Bonus, CommissionPct, SalesYTD, SalesLastYear, rowguid, ModifiedDate)
VALUES
	(1, 1, 1000000, 289, 0.17, 0, 0, NEWID(), CURRENT_TIMESTAMP);

UPDATE Sales.SalesOrderHeader
	SET SalesPersonID = 1
WHERE SalesPersonID IS NULL;
GO

UPDATE STATISTICS Sales.SalesOrderHeader;
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Search proc that will be used to further demonstrate parameter sniffing.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_sales_orders_by_sales_person')
BEGIN
	DROP PROCEDURE dbo.get_sales_orders_by_sales_person;
END
GO

CREATE PROCEDURE dbo.get_sales_orders_by_sales_person
	@SalesPersonID INT, @RowCount INT, @Offset INT
AS
BEGIN
	DECLARE @sql_command NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX) = '@SalesPersonID INT, @RowCount INT, @Offset INT';

	SELECT @sql_command = '
	WITH CTE_PRODUCTS AS (
		SELECT
			ROW_NUMBER() OVER (ORDER BY OrderDate ASC) AS rownum,
			SalesOrderHeader.SalesOrderID,
			SalesOrderHeader.Status,
			SalesOrderHeader.OrderDate,
			SalesOrderHeader.ShipDate,
			SalesOrderDetail.UnitPrice,
			SalesOrderDetail.LineTotal
		FROM Sales.SalesOrderHeader
		INNER JOIN Sales.SalesOrderDetail
		ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
		WHERE SalesOrderHeader.SalesPersonID = @SalesPersonID
		)
	SELECT
		*
	FROM CTE_PRODUCTS
	WHERE rownum BETWEEN @Offset AND @Offset + @RowCount;';

	EXEC sp_executesql @sql_command, @parameter_list, @SalesPersonID, @RowCount, @Offset;
END
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Clear the cache and view the performance for a search on the new sales person above.
DBCC FREEPROCCACHE;
EXEC dbo.get_sales_orders_by_sales_person 1, 1000, 0;

EXEC dbo.read_query_plan_cache 'CTE_PRODUCTS';
/*
(@SalesPersonID INT, @RowCount INT, @Offset INT)
	WITH CTE_PRODUCTS AS (
		SELECT
			ROW_NUMBER() OVER (ORDER BY OrderDate ASC) AS rownum,
			SalesOrderHeader.SalesOrderID,
			SalesOrderHeader.Status,
			SalesOrderHeader.OrderDate,
			SalesOrderHeader.ShipDate,
			SalesOrderDetail.UnitPrice,
			SalesOrderDetail.LineTotal
		FROM Sales.SalesOrderHeader
		INNER JOIN Sales.SalesOrderDetail
		ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
		WHERE SalesOrderHeader.SalesPersonID = @SalesPersonID
		)
	SELECT
		*
	FROM CTE_PRODUCTS
	WHERE rownum BETWEEN @Offset AND @Offset + @RowCount;
*/
-- View the execution plan for a sales person with far fewer sales.
DBCC FREEPROCCACHE;
EXEC dbo.get_sales_orders_by_sales_person 285, 1000, 0;

EXEC dbo.read_query_plan_cache 'CTE_PRODUCTS';
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Run each sales person search in succession to further illustrate parameter sniffing.
DBCC FREEPROCCACHE;
EXEC dbo.get_sales_orders_by_sales_person 1, 1000, 0;

EXEC dbo.get_sales_orders_by_sales_person 285, 1000, 0;

EXEC dbo.read_query_plan_cache 'CTE_PRODUCTS';
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Example of the use of the RECOMPILE hint to force a plan to be created from scrach each time this proc is run.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_sales_orders_by_sales_person')
BEGIN
	DROP PROCEDURE dbo.get_sales_orders_by_sales_person;
END
GO

CREATE PROCEDURE dbo.get_sales_orders_by_sales_person
	@SalesPersonID INT, @RowCount INT, @Offset INT
AS
BEGIN
	DECLARE @sql_command NVARCHAR(MAX);
	DECLARE @parameter_list NVARCHAR(MAX) = '@SalesPersonID INT, @RowCount INT, @Offset INT';

	SELECT @sql_command = '
	WITH CTE_PRODUCTS AS (
		SELECT
			ROW_NUMBER() OVER (ORDER BY OrderDate ASC) AS rownum,
			SalesOrderHeader.SalesOrderID,
			SalesOrderHeader.Status,
			SalesOrderHeader.OrderDate,
			SalesOrderHeader.ShipDate,
			SalesOrderDetail.UnitPrice,
			SalesOrderDetail.LineTotal
		FROM Sales.SalesOrderHeader
		INNER JOIN Sales.SalesOrderDetail
		ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
		WHERE SalesOrderHeader.SalesPersonID = @SalesPersonID
		)
	SELECT
		*
	FROM CTE_PRODUCTS
	WHERE rownum BETWEEN @Offset AND @Offset + @RowCount
	OPTION (RECOMPILE);';

	EXEC sp_executesql @sql_command, @parameter_list, @SalesPersonID, @RowCount, @Offset;
END
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Each time the stored proc is called, a new execution plan is generated, as a result of the use of the RECOMPILE hint.
DBCC FREEPROCCACHE;
EXEC dbo.get_sales_orders_by_sales_person 1, 1000, 0;

EXEC dbo.get_sales_orders_by_sales_person 285, 1000, 0;

EXEC dbo.read_query_plan_cache 'CTE_PRODUCTS';
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Example of a query that is guaranteed to perform poorly.
SELECT DISTINCT
	PRODUCT.ProductID,
	PRODUCT.Name
FROM Production.Product PRODUCT
INNER JOIN Sales.SalesOrderDetail DETAIL
ON PRODUCT.ProductID = DETAIL.ProductID
OR PRODUCT.rowguid = DETAIL.rowguid;

-- Example of how to rewrite it to perform significantly better.
SELECT
	PRODUCT.ProductID,
	PRODUCT.Name
FROM Production.Product PRODUCT
INNER JOIN Sales.SalesOrderDetail DETAIL
ON PRODUCT.ProductID = DETAIL.ProductID
UNION
SELECT
	PRODUCT.ProductID,
	PRODUCT.Name
FROM Production.Product PRODUCT
INNER JOIN Sales.SalesOrderDetail DETAIL
ON PRODUCT.rowguid = DETAIL.rowguid;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Add an index for the next demo.
CREATE NONCLUSTERED INDEX NCI_production_product_ProductModelID ON Production.Product (ProductModelID) INCLUDE (Name);
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- Example of a stored procedure that re-declares a parameter locally and uses it in a search.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_products_by_model_local')
BEGIN
	DROP PROCEDURE dbo.get_products_by_model_local;
END
GO
CREATE PROCEDURE dbo.get_products_by_model_local (@firstProductModelID INT, @lastProductModelID INT) 
AS
BEGIN
	DECLARE @ProductModelID1 INT = @firstProductModelID;
	DECLARE @ProductModelID2 INT = @lastProductModelID;

	SELECT
		PRODUCT.Name,
		PRODUCT.ProductID,
		PRODUCT.ProductModelID,
		PRODUCT.ProductNumber,
		MODEL.Name
	FROM Production.Product PRODUCT
	INNER JOIN Production.ProductModel MODEL
	ON MODEL.ProductModelID = PRODUCT.ProductModelID
	WHERE PRODUCT.ProductModelID BETWEEN @ProductModelID1 AND @ProductModelID2;
END
GO
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- This proc results in frequent plan reuse, but that reuse is based on poor statistics.  Some runs will be efficient
-- while others will be awful due to the lack of histogram data in the optimizer's work.
DBCC FREEPROCCACHE;
-- Execute the stored proc with a narrow range of model numbers
EXEC dbo.get_products_by_model 120, 125;
EXEC dbo.get_products_by_model_local 120, 125;

EXEC dbo.read_query_plan_cache 'get_products_by_model';

DBCC FREEPROCCACHE;
-- Execute the stored proc with a narrow range of model numbers
EXEC dbo.get_products_by_model_local 120, 125;
EXEC dbo.get_products_by_model_local 0, 10000;

-- Clear the plan cache
DBCC FREEPROCCACHE;
-- Execute the stored procedure with a wide range of model numbers.  Note the difference in execution plan and subtree cost.
EXEC dbo.get_products_by_model 0, 10000;
EXEC dbo.get_products_by_model_local 0, 10000;

EXEC dbo.read_query_plan_cache 'get_products_by_model';

DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model 120, 125;
EXEC dbo.get_products_by_model 0, 10000;

EXEC dbo.read_query_plan_cache 'get_products_by_model';

DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model_local 120, 125;
DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model_local 120, 125;
EXEC dbo.get_products_by_model_local 0, 10000;
EXEC dbo.get_products_by_model_local 120, 125;
EXEC dbo.get_products_by_model_local 0, 10000;
-- Without clearing the cache, run the same proc with the wide range of product model IDs.  Note the reuse of the last execution plan, despite not being the optimal plan.
EXEC dbo.get_products_by_model_local 0, 10000;

EXEC dbo.read_query_plan_cache 'get_products_by_model_local';

DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model 0, 10000;

DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model_local 0, 10000;

-- Further illustration of the effect of local variables on optimization.
	DECLARE @ProductModelID1 INT = 0;
	DECLARE @ProductModelID2 INT = 10000;
	SELECT
		PRODUCT.Name,
		PRODUCT.ProductID,
		PRODUCT.ProductModelID,
		PRODUCT.ProductNumber,
		MODEL.Name
	FROM Production.Product PRODUCT
	INNER JOIN Production.ProductModel MODEL
	ON MODEL.ProductModelID = PRODUCT.ProductModelID
	WHERE PRODUCT.ProductModelID BETWEEN @ProductModelID1 AND @ProductModelID2;


DBCC SHOW_STATISTICS ("Production.Product", NCI_production_product_ProductModelID);

-- Cleanup
DROP PROCEDURE dbo.get_products_by_model_local;
DROP INDEX NCI_production_product_ProductModelID ON Production.Product;
GO

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Example of using the OPTIMIZE FOR hint in a search.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_products_by_model_local')
BEGIN
	DROP PROCEDURE dbo.get_products_by_model;
END
GO
CREATE PROCEDURE dbo.get_products_by_model (@firstProductModelID INT, @lastProductModelID INT) 
AS
BEGIN
	SELECT
		PRODUCT.Name,
		PRODUCT.ProductID,
		PRODUCT.ProductModelID,
		PRODUCT.ProductNumber,
		MODEL.Name
	FROM Production.Product PRODUCT
	INNER JOIN Production.ProductModel MODEL
	ON MODEL.ProductModelID = PRODUCT.ProductModelID
	WHERE PRODUCT.ProductModelID BETWEEN @firstProductModelID AND @lastProductModelID
	OPTION (OPTIMIZE FOR (@firstProductModelID = 0, @lastProductModelID = 10000));
END
GO

DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model 0, 10000;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Using OPTIMIZE FOR UNKNOWN in a search.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_products_by_model_local')
BEGIN
	DROP PROCEDURE dbo.get_products_by_model;
END
GO
CREATE PROCEDURE dbo.get_products_by_model (@firstProductModelID INT, @lastProductModelID INT) 
AS
BEGIN
	SELECT
		PRODUCT.Name,
		PRODUCT.ProductID,
		PRODUCT.ProductModelID,
		PRODUCT.ProductNumber,
		MODEL.Name
	FROM Production.Product PRODUCT
	INNER JOIN Production.ProductModel MODEL
	ON MODEL.ProductModelID = PRODUCT.ProductModelID
	WHERE PRODUCT.ProductModelID BETWEEN @firstProductModelID AND @lastProductModelID
	OPTION (OPTIMIZE FOR (@firstProductModelID UNKNOWN, @lastProductModelID UNKNOWN));
END
GO

DBCC FREEPROCCACHE;
EXEC dbo.get_products_by_model 0, 10000;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-- Cleanup
IF EXISTS (SELECT * FROM sys.indexes WHERE indexes.name = 'NCI_production_product_ProductModelID')
BEGIN
	DROP INDEX NCI_production_product_ProductModelID ON Production.Product;
END
GO
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_products_by_model_local')
BEGIN
	DROP PROCEDURE dbo.get_products_by_model;
END
GO
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_sales_orders_by_sales_person')
BEGIN
	DROP PROCEDURE dbo.get_sales_orders_by_sales_person;
END
GO
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------