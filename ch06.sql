/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 6: Performance Optimization

	This chapter contains a wide variety of examples that illustrate how to gauge performance and mitigate
	queries that are performing poorly.
*/
USE AdventureWorks2014 -- Can use any AdventureWorks database for all demos in this book.
GO

SET NOCOUNT ON; -- Exclude row counts from SQL Server output.
SET STATISTICS IO ON; -- Turn on IO reporting for all queries executed in this session.
SET STATISTICS TIME ON; -- Turn on time tracking for this session.
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Run this after turning on the actual execution plan, STATISTICS IO, and STATISTICS TIME to see the new info that is provided when the query is executed.
SELECT
	FirstName,
	MiddleName,
	LastName,
	ModifiedDate
FROM Person.Person
WHERE FirstName = 'Xavier'
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Example of a syntax error, which is thrown as the query is parsed (prior to binding, optimization, & execution).
SELECT & FROM Person.Person;
-- Example of the same query, which will throw an error when executed, but not when parsed, as the command string is valid to the parser.
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = 'SELECT & FROM Person.Person;';
EXEC (@sql_command);
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- This TSQL will generate a new query execution plan for any new value of @FirstName that is provided.
-- Each name below will be given a new execution plan.
DECLARE @FirstName NVARCHAR(MAX) = 'Edward';
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = ''' + @FirstName + ''';
'
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO

DECLARE @FirstName NVARCHAR(MAX) = 'Xavier';
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = ''' + @FirstName + ''';
'
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO

DECLARE @FirstName NVARCHAR(MAX) = 'Thomas';
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = ''' + @FirstName + ''';
'
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO

DECLARE @FirstName NVARCHAR(MAX) = 'James';
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = ''' + @FirstName + ''';
'
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO

DECLARE @FirstName NVARCHAR(MAX) = 'Jesse';
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = ''' + @FirstName + ''';
'
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO

DECLARE @FirstName NVARCHAR(MAX) = 'T-Rex!!!';
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = ''' + @FirstName + ''';
'
PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Parameterizing @FirstName allows the execution plan to be reused for any value, rather than a new plan provided every time.
DECLARE @FirstName NVARCHAR(MAX) = 'Edward';
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @parameter_list NVARCHAR(MAX) = '@first_name NVARCHAR(MAX)';
SELECT @sql_command = '
	SELECT
		*
	FROM Person.Person
	WHERE FirstName = @first_name;'
PRINT @sql_command;
EXEC sp_executesql @sql_command, @parameter_list, @FIrstName;
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- This clears out the plan cache---do not use this in production---it is a dev tool for allowing queries to be tested on an empty cache.
DBCC FREEPROCCACHE;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- This query can be used to retrieve TSQL data from the query plan cache.
SELECT
	cached_plans.objtype AS ObjectType,
	OBJECT_NAME(sql_text.objectid, sql_text.dbid) AS ObjectName,
	cached_plans.usecounts AS ExecutionCount,
	sql_text.TEXT AS QueryText
FROM sys.dm_exec_cached_plans AS cached_plans
CROSS APPLY sys.dm_exec_sql_text(cached_plans.plan_handle) AS sql_text
WHERE sql_text.TEXT LIKE '%Person.Person%';
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Dynamic search proc that selectively queries objects as needed in order to reduce reads on unneeded tables.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'search_products')
BEGIN
	DROP PROCEDURE dbo.search_products;
END
GO
-- Search with a check to avoid empty searches
CREATE PROCEDURE dbo.search_products
	@product_name NVARCHAR(50) = NULL, @product_number NVARCHAR(25) = NULL, @product_model NVARCHAR(50) = NULL,
	@product_subcategory NVARCHAR(50) = NULL, @product_sizemeasurecode NVARCHAR(50) = NULL,
	@product_weightunitmeasurecode NVARCHAR(50) = NULL,
	@show_color BIT = 0, @show_safetystocklevel BIT = 0, @show_reorderpoint BIT = 0, @show_standard_cost BIT = 0,
	@show_catalog_description BIT = 0, @show_subcategory_modified_date BIT = 0, @show_product_model BIT = 0,
	@show_product_subcategory BIT = 0, @show_product_sizemeasurecode BIT = 0, @show_product_weightunitmeasurecode BIT = 0
AS
BEGIN
	SET NOCOUNT ON;

	IF COALESCE(@product_name, @product_number, @product_model, @product_subcategory,
				@product_sizemeasurecode, @product_weightunitmeasurecode) IS NULL
		RETURN;

	-- Add "%" delimiters to parameters that will be searched as wildcards.
	SET @product_name = '%' + @product_name + '%';
	SET @product_number = '%' + @product_number + '%';
	SET @product_model = '%' + @product_model + '%';

	DECLARE @sql_command NVARCHAR(MAX);
	-- Define the parameter list for filter criteria
	DECLARE @parameter_list NVARCHAR(MAX) = '@product_name NVARCHAR(50), @product_number NVARCHAR(25),
	@product_model NVARCHAR(50), @product_subcategory NVARCHAR(50), @product_sizemeasurecode NVARCHAR(50),
	@product_weightunitmeasurecode NVARCHAR(50)';

-- Generate the simplified command string section for the SELECT columns
SELECT @sql_command = '
	SELECT
		Product.Name AS product_name,
		Product.ProductNumber AS product_number,';
		IF @show_product_model = 1 OR @show_catalog_description = 1 SELECT @sql_command = @sql_command + '
			ProductModel.Name AS product_model_name,
			ProductModel.CatalogDescription AS productmodel_catalog_description,';
		IF @show_product_subcategory = 1 OR @show_subcategory_modified_date = 1 SELECT @sql_command = @sql_command + '
			ProductSubcategory.Name AS product_subcategory_name,
			ProductSubcategory.ModifiedDate AS product_subcategory_modified_date,';
		IF @show_product_sizemeasurecode = 1 SELECT @sql_command = @sql_command + '
			SizeUnitMeasureCode.Name AS size_unit_measure_code,';
		IF @show_product_weightunitmeasurecode = 1 SELECT @sql_command = @sql_command + '
			WeightUnitMeasureCode.Name AS weight_unit_measure_code,';
		IF @show_color = 1 OR @show_safetystocklevel = 1 OR @show_reorderpoint = 1 OR @show_standard_cost = 1
		SELECT @sql_command = @sql_command + '
			Product.Color AS product_color,
			Product.SafetyStockLevel AS product_safety_stock_level,
			Product.ReorderPoint AS product_reorderpoint,
			Product.StandardCost AS product_standard_cost';
	-- In the event that there is a comma at the end of our command string, remove it before continuing:
	IF (SELECT SUBSTRING(@sql_command, LEN(@sql_command), 1)) = ','
		SELECT @sql_command = LEFT(@sql_command, LEN(@sql_command) - 1);
	SELECT @sql_command = @sql_command + '
	FROM Production.Product'
	-- Put together the JOINs based on what tables are required by the search.
	IF (@product_model IS NOT NULL OR @show_product_model = 1 OR @show_catalog_description = 1)
		SELECT @sql_command = @sql_command + '
	LEFT JOIN Production.ProductModel
	ON Product.ProductModelID = ProductModel.ProductModelID';
	IF (@product_subcategory IS NOT NULL OR @show_subcategory_modified_date = 1 OR @show_product_subcategory = 1)
		SELECT @sql_command = @sql_command + '
	LEFT JOIN Production.ProductSubcategory
	ON Product.ProductSubcategoryID = ProductSubcategory.ProductSubcategoryID';
	IF (@product_sizemeasurecode IS NOT NULL OR @show_product_sizemeasurecode = 1)
		SELECT @sql_command = @sql_command + '
	LEFT JOIN Production.UnitMeasure SizeUnitMeasureCode
	ON Product.SizeUnitMeasureCode = SizeUnitMeasureCode.UnitMeasureCode';
	IF (@product_weightunitmeasurecode IS NOT NULL OR @show_product_weightunitmeasurecode = 1)
		SELECT @sql_command = @sql_command + '
	LEFT JOIN Production.UnitMeasure WeightUnitMeasureCode
	ON Product.WeightUnitMeasureCode = SizeUnitMeasureCode.UnitMeasureCode';

	SELECT @sql_command = @sql_command + '
	WHERE 1 = 1';
	-- Build the WHERE clause based on which tables are referenced and required by the search.
	IF @product_name IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND Product.Name LIKE @product_name';
	IF @product_number IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND Product.ProductNumber LIKE @product_number';
	IF @product_model IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND ProductModel.Name LIKE @product_model';
	IF @product_subcategory IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND ProductSubcategory.Name = @product_subcategory';
	IF @product_sizemeasurecode IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND SizeUnitMeasureCode.Name = @product_sizemeasurecode';
	IF @product_weightunitmeasurecode IS NOT NULL
		SELECT @sql_command = @sql_command + '
		AND WeightUnitMeasureCode.Name = @product_weightunitmeasurecode';

	PRINT @sql_command;
	EXEC sp_executesql @sql_command, @parameter_list, @product_name, @product_number,
	@product_model, @product_subcategory, @product_sizemeasurecode,	@product_weightunitmeasurecode;
END
GO

EXEC dbo.search_products @product_name = 'Mountain Frame', @product_number  = 'FR-M21B', @product_model = 'LL Mountain Frame',
@product_subcategory = 'Mountain Frames', @show_color = 0, @show_safetystocklevel = 0,
@show_reorderpoint = 0, @show_standard_cost = 1, @show_catalog_description = 1, @show_subcategory_modified_date = 0,
@show_product_model = 1, @show_product_subcategory = 1
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Similar search proc that checks all objects, regardless of what is needed.  This will generally use more resources --- but will allow for plan reuse.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'search_products')
BEGIN
	DROP PROCEDURE dbo.search_products;
END
GO

CREATE PROCEDURE dbo.search_products
	@product_name NVARCHAR(50) = NULL, @product_number NVARCHAR(25) = NULL, @product_model NVARCHAR(50) = NULL,
	@product_subcategory NVARCHAR(50) = NULL, @product_sizemeasurecode NVARCHAR(50) = NULL,
	@product_weightunitmeasurecode NVARCHAR(50) = NULL
AS
BEGIN
	SELECT @product_name = '%' + @product_name + '%';
	SELECT @product_number = '%' + @product_number + '%';
	SELECT @product_model = '%' + @product_model + '%';

	SELECT
		Product.Name AS product_name,
		Product.ProductNumber AS product_number,
		ProductModel.Name AS product_model_name,
		ProductModel.CatalogDescription AS productmodel_catalog_description,
		ProductSubcategory.Name AS product_subcategory_name,
		ProductSubcategory.ModifiedDate AS product_subcategory_modified_date,
		SizeUnitMeasureCode.Name AS size_unit_measure_code,
		WeightUnitMeasureCode.Name AS weight_unit_measure_code,
		Product.Color AS product_color,
		Product.SafetyStockLevel AS product_safety_stock_level,
		Product.ReorderPoint AS product_reorderpoint,
		Product.StandardCost AS product_standard_cost
	FROM Production.Product
	LEFT JOIN Production.ProductModel
	ON Product.ProductModelID = ProductModel.ProductModelID
	LEFT JOIN Production.ProductSubcategory
	ON Product.ProductSubcategoryID = ProductSubcategory.ProductSubcategoryID
	LEFT JOIN Production.UnitMeasure SizeUnitMeasureCode
	ON Product.SizeUnitMeasureCode = SizeUnitMeasureCode.UnitMeasureCode
	LEFT JOIN Production.UnitMeasure WeightUnitMeasureCode
	ON Product.WeightUnitMeasureCode = SizeUnitMeasureCode.UnitMeasureCode
	WHERE (Product.Name LIKE @product_name OR @product_name IS NULL)
	AND (Product.ProductNumber LIKE @product_number OR @product_number IS NULL)
	AND (ProductModel.Name LIKE @product_model OR @product_model IS NULL)
	AND (ProductSubcategory.Name = @product_subcategory OR @product_subcategory IS NULL)
	AND (SizeUnitMeasureCode.Name = @product_sizemeasurecode OR @product_sizemeasurecode IS NULL)
	AND (WeightUnitMeasureCode.Name = @product_weightunitmeasurecode OR @product_weightunitmeasurecode IS NULL);
END
GO

EXEC dbo.search_products @product_name = 'Mountain Frame', @product_number  = 'FR-M21B', @product_model = 'LL Mountain Frame',
@product_subcategory = 'Mountain Frames';
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Basic data paging, using row numbers based on the order date.
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
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 75;

-- Same query, but returning a greater number of rows.
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
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 200;
-- Same query, returning even more data than previously.
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
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 500;
-- One final iteration, returning even more data than the previous three examples.  Note how resource consumption changes with each version.
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
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 1000;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Similar query, but with the row count returned as part of the final SELECT statement.
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
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*,
	(SELECT COUNT(*) FROM CTE_PRODUCTS) AS total_result_count
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 75;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Collecting the row count for the data set first, prior to retrieving the actual data.
SELECT COUNT(*) AS total_result_count
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
WHERE SalesOrderHeader.SalesPersonID = 277;

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
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 75;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Data paging, using the COUNT window function to retrieve the row count as part of the CTE.
WITH CTE_PRODUCTS AS (
	SELECT
		ROW_NUMBER() OVER (ORDER BY OrderDate ASC) AS rownum,
		COUNT(SalesOrderDetail.SalesOrderDetailID) OVER (ORDER BY SalesOrderDetail.SalesOrderDetailID ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS total_result_count,
		SalesOrderHeader.SalesOrderID,
		SalesOrderHeader.Status,
		SalesOrderHeader.OrderDate,
		SalesOrderHeader.ShipDate,
		SalesOrderDetail.UnitPrice,
		SalesOrderDetail.LineTotal
	FROM Sales.SalesOrderHeader
	INNER JOIN Sales.SalesOrderDetail
	ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 75;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Data paging using a simplified version of the COUNT window function.
WITH CTE_PRODUCTS AS (
	SELECT
		ROW_NUMBER() OVER (ORDER BY OrderDate ASC) AS rownum,
		COUNT(*) OVER () AS total_result_count,
		SalesOrderHeader.SalesOrderID,
		SalesOrderHeader.Status,
		SalesOrderHeader.OrderDate,
		SalesOrderHeader.ShipDate,
		SalesOrderDetail.UnitPrice,
		SalesOrderDetail.LineTotal
	FROM Sales.SalesOrderHeader
	INNER JOIN Sales.SalesOrderDetail
	ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
	WHERE SalesOrderHeader.SalesPersonID = 277
	)
SELECT
	*
FROM CTE_PRODUCTS
WHERE rownum BETWEEN 51 AND 75;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Collecting the row count after the SELECT using @@ROWCOUNT
SELECT
	ROW_NUMBER() OVER (ORDER BY OrderDate ASC) AS rownum,
	SalesOrderHeader.SalesOrderID,
	SalesOrderHeader.Status,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.ShipDate,
	SalesOrderDetail.UnitPrice,
	SalesOrderDetail.LineTotal
INTO #orders
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
WHERE SalesOrderHeader.SalesPersonID = 277;

SELECT @@ROWCOUNT AS total_result_count;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- The effects of indexing the temp table w/ respect to performance.
CREATE CLUSTERED INDEX IX_temp_orders_rownum ON #orders (rownum);

SELECT * FROM #orders WHERE rownum BETWEEN 1 AND 25;
SELECT * FROM #orders WHERE rownum BETWEEN 26 AND 50;
SELECT * FROM #orders WHERE rownum BETWEEN 51 AND 75;
SELECT * FROM #orders WHERE rownum BETWEEN 76 AND 100;

DROP TABLE #orders;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Data paging, using OFFSET
SELECT
	SalesOrderHeader.SalesOrderID,
	SalesOrderHeader.Status,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.ShipDate,
	SalesOrderDetail.UnitPrice,
	SalesOrderDetail.LineTotal
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
WHERE SalesOrderHeader.SalesPersonID = 277
ORDER BY OrderDate ASC
OFFSET 50 ROWS
FETCH NEXT 25 ROWS ONLY
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- An introduction to filtered indexes.
IF EXISTS (SELECT * FROM sys.indexes WHERE indexes.name = 'IX_PurchaseOrderHeader_status_INC')
BEGIN
	DROP INDEX IX_PurchaseOrderHeader_status_INC ON Purchasing.PurchaseOrderHeader
END
GO

CREATE NONCLUSTERED INDEX IX_PurchaseOrderHeader_status_INC
ON Purchasing.PurchaseOrderHeader (OrderDate, status)
INCLUDE (PurchaseOrderID, ShipDate, SubTotal, Freight);
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_in_process_purchasing_data')
BEGIN
	DROP PROCEDURE dbo.get_in_process_purchasing_data;
END
GO
-- Simple dynamic search, and its use of filtered indexes.
CREATE PROCEDURE dbo.get_in_process_purchasing_data
	@return_detail_data BIT
AS
BEGIN 
	SET NOCOUNT ON;
	DECLARE @sql_command NVARCHAR(MAX);

	SELECT @sql_command = '
	SELECT
		PurchaseOrderHeader.PurchaseOrderID,
		PurchaseOrderHeader.OrderDate,
		PurchaseOrderHeader.ShipDate,
		PurchaseOrderHeader.SubTotal,
		PurchaseOrderHeader.Freight';
	IF @return_detail_data = 1
		SELECT @sql_command = @sql_command + ',
		PurchaseOrderDetail.PurchaseOrderDetailID,
		PurchaseOrderDetail.OrderQTY,
		PurchaseOrderDetail.UnitPrice,
		Product.Name,
		Product.ProductNumber';
	SELECT @sql_command = @sql_command + '
	FROM purchasing.PurchaseOrderHeader
	INNER JOIN purchasing.PurchaseOrderDetail
	ON PurchaseOrderHeader.PurchaseOrderID = PurchaseOrderDetail.PurchaseOrderID';
	IF @return_detail_data = 1
		SELECT @sql_command = @sql_command + '
		INNER JOIN Production.Product
		ON Product.ProductID = PurchaseOrderDetail.ProductID';
	SELECT @sql_command = @sql_command + '
	WHERE PurchaseOrderHeader.Status = 2';

	EXEC sp_executesql @sql_command;
END
GO

-- 0.095894 subtree
-- 114/24/24 reads / 0/12/1 scans
EXEC dbo.get_in_process_purchasing_data @return_detail_data = 1;

IF EXISTS (SELECT * FROM sys.indexes WHERE indexes.name = 'IX_PurchaseOrderHeader_status_INC')
BEGIN
	DROP INDEX IX_PurchaseOrderHeader_status_INC ON Purchasing.PurchaseOrderHeader
END
GO

CREATE NONCLUSTERED INDEX IX_PurchaseOrderHeader_status_INC
ON Purchasing.PurchaseOrderHeader (OrderDate, status)
INCLUDE (PurchaseOrderID, ShipDate, SubTotal, Freight)
WHERE status = 2;
GO

EXEC dbo.get_in_process_purchasing_data @return_detail_data = 1;

BEGIN TRANSACTION
UPDATE Purchasing.PurchaseOrderHeader
	SET status = 2
WHERE PurchaseOrderID = 2758;
ROLLBACK

DROP INDEX IX_PurchaseOrderHeader_status_INC ON Purchasing.PurchaseOrderHeader;
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Examples of how to view, update, and use statistics data.
DBCC SHOW_STATISTICS ("Sales.SalesOrderheader", IX_SalesOrderHeader_CustomerID);

SELECT DISTINCT CustomerID FROM Sales.SalesOrderheader;
SELECT DISTINCT CustomerID, SalesOrderID FROM Sales.SalesOrderheader;

SELECT
	is_auto_update_stats_on,
	is_auto_create_stats_on,
	is_auto_update_stats_async_on
FROM sys.databases WHERE name = 'AdventureWorks2014'

EXEC sys.sp_updatestats;

UPDATE STATISTICS Production.Product; -- Updates all statistics on Production.Product

UPDATE STATISTICS Production.Product PK_Product_ProductID; -- Updates the statistics on NCI_Product_Weight
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- The results of disabling the automatic updating of statistics.
ALTER DATABASE AdventureWorks2014
SET AUTO_UPDATE_STATISTICS OFF; -- default ON
-- creates single column indexes on tables...not views

SELECT
	is_auto_update_stats_on,
	is_auto_create_stats_on,
	is_auto_update_stats_async_on
FROM sys.databases WHERE name = 'AdventureWorks2014'

DROP INDEX IX_Product_Weight ON Production.Product;

CREATE NONCLUSTERED INDEX IX_Product_Weight ON Production.Product (Weight);

UPDATE STATISTICS Production.Product IX_Product_Weight; -- Updates the statistics on NCI_Product_Weight

SELECT COUNT(*) FROM Production.Product;

SELECT
	ProductID,
	Weight,
	Name
FROM Production.Product
WHERE Weight = 170

-- Turn off execution plan here
SET STATISTICS IO OFF
SET STATISTICS TIME OFF
-- Populate additional test data into Production.Product
DECLARE @count INT = 1
WHILE @count < 2000
BEGIN
	INSERT INTO Production.Product
			( Name ,
			  ProductNumber ,
			  MakeFlag ,
			  FinishedGoodsFlag ,
			  Color ,
			  SafetyStockLevel ,
			  ReorderPoint ,
			  StandardCost ,
			  ListPrice ,
			  Size ,
			  SizeUnitMeasureCode ,
			  WeightUnitMeasureCode ,
			  Weight ,
			  DaysToManufacture ,
			  ProductLine ,
			  Class ,
			  Style ,
			  ProductSubcategoryID ,
			  ProductModelID ,
			  SellStartDate ,
			  SellEndDate ,
			  DiscontinuedDate ,
			  rowguid ,
			  ModifiedDate
			)
	SELECT
		'Hoverboard' + CAST(@count AS VARCHAR(25)),
		'HOV-' + CAST(@count AS VARCHAR(25)),
		1 AS MakeFlag ,
		1 AS FinishedGoodsFlag ,
		NULL AS Color ,
		500 AS SafetyStockLevel ,
		375 AS ReorderPoint ,
		55 AS StandardCost ,
		100 AS ListPrice ,
		NULL AS Size ,
		NULL AS SizeUnitMeasureCode ,
		'G' AS WeightUnitMeasureCode ,
		170 AS Weight ,
		5 AS DaysToManufacture ,
		NULL AS ProductLine ,
		'H' AS Class ,
		NULL AS Style ,
		5 AS ProductSubcategoryID ,
		97 AS ProductModelID ,
		'1/1/2015' AS SellStartDate ,
		NULL AS SellEndDate ,
		NULL AS DiscontinuedDate ,
		NEWID() AS rowguid,
		CURRENT_TIMESTAMP AS ModifiedDate

	SET @count = @count + 1
END

--default
-- 0.006574: seek + key lookup--> nested loops-->select, 1 scan, 6 reads
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET NOCOUNT ON;
-- Adding a ton of data without statistics being updated results in poor execution plan choices:
SELECT
	ProductID,
	Weight,
	Name
FROM Production.Product
WHERE Weight = 170
-- Verify statistics
DBCC SHOW_STATISTICS ("Production.Product", IX_Product_Weight);
-- Update statistics
UPDATE STATISTICS Production.Product IX_Product_Weight;
-- Verify the changes
DBCC SHOW_STATISTICS ("Production.Product", IX_Product_Weight);
-- Run the query again and now get an optimal execution plan.
SELECT
	ProductID,
	Weight,
	Name
FROM Production.Product
WHERE Weight = 170

ALTER DATABASE AdventureWorks2014
SET AUTO_UPDATE_STATISTICS ON; -- default ON

DELETE FROM Production.Product WHERE ProductID > 999
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- This trace flag can be useful on databases with large tables that may see frequent incremental change that
-- may not be enough to trigger the auto-updating of statistics as often as needed.
DBCC TRACEON (2371);
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Example query to be used below
SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID,
	SalesOrderHeader.OrderDate
FROM Sales.SalesOrderDetail
INNER JOIN Sales.SalesOrderHeader
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WHERE ProductID = 713;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Example use of the NOLOCK hint.
SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID
FROM Sales.SalesOrderDetail WITH (NOLOCK)
WHERE ProductID = 713;
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Using join hints to force specific join types.
DECLARE @ProductID INT = 713;
SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID,
	SalesOrderHeader.OrderDate
FROM Sales.SalesOrderDetail
INNER LOOP JOIN Sales.SalesOrderHeader
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WHERE ProductID = @ProductID;

SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID,
	SalesOrderHeader.OrderDate
FROM Sales.SalesOrderDetail
INNER MERGE JOIN Sales.SalesOrderHeader
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WHERE ProductID = @ProductID;

SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID,
	SalesOrderHeader.OrderDate
FROM Sales.SalesOrderDetail
INNER HASH JOIN Sales.SalesOrderHeader
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WHERE ProductID = @ProductID;
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Using the RECOMPILE hint to force a query to execute with a new execution plan, even if one already exists in the plan cache.
DECLARE @ProductID INT = 713;
SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID,
	SalesOrderHeader.OrderDate
FROM Sales.SalesOrderDetail
INNER LOOP JOIN Sales.SalesOrderHeader
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WHERE ProductID = @ProductID
OPTION (RECOMPILE);
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Same query, without the RECOMPILE hint.
DECLARE @ProductID INT = 713;
SELECT
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.ProductID,
	SalesOrderHeader.OrderDate
FROM Sales.SalesOrderDetail
INNER JOIN Sales.SalesOrderHeader
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WHERE ProductID = @ProductID
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
-- Cleanup
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'search_products')
BEGIN
	DROP PROCEDURE dbo.search_products;
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE indexes.name = 'IX_PurchaseOrderHeader_status_INC')
BEGIN
	DROP INDEX IX_PurchaseOrderHeader_status_INC ON Purchasing.PurchaseOrderHeader
END
GO
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'get_in_process_purchasing_data')
BEGIN
	DROP PROCEDURE dbo.get_in_process_purchasing_data;
END
GO
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------