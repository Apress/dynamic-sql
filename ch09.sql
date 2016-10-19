/*	Dynamic SQL: Applications, Performance, and Security
	Chapter 9: Dynamic PIVOT and UNPIVOT

	The SQL demos in this chapter serve to introduce the topic of dynamic SQL and provide
	the basis for all content discussed for the remainder of the book.	
*/

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Query that returns some product data from AdventureWorks.
SELECT
	PRODUCT.Name AS product_name,
	PRODUCT.Color AS product_color,
	PRODUCT_INVENTORY.LocationID,
	PRODUCT.ReorderPoint,
	PRODUCT_INVENTORY.Quantity AS product_quantity
FROM Production.Product PRODUCT
LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Common PIVOT usage that reports on products by color.
SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN ([Black], [Blue], [Grey], [Multi], [Red], [Silver], [Silver/Black], [White], [Yellow])
) PIVOT_DATA

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Things that don't work when trying to make the PIVOT list dynamic.  These queries generate a variety of errors.
SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (SELECT Color FROM Production.Product)
) PIVOT_DATA;

DECLARE @colors TABLE
	(color_name VARCHAR(25)	)

INSERT INTO @colors
	(color_name)
VALUES ('Black'), ('Blue'), ('Grey'), ('Multi'), ('Red'), ('Silver'), ('Silver/Black'), ('White'), ('Yellow')

SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (SELECT color_name FROM @colors)
) PIVOT_DATA
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- How to use dynamic SQL and a table variable to PIVOT on a list of colors declared at runtime.
DECLARE @colors TABLE
	(color_name VARCHAR(25)	);

INSERT INTO @colors
	(color_name)
VALUES ('Black'), ('Grey'), ('Silver/Black'), ('White');

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA
';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using a dynamic PIVOT to account for all product colors, even if they change over time.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT DISTINCT
	Product.Color
FROM Production.Product
WHERE Product.Color IS NOT NULL;

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA
';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Final test: Let's add a few new colors to the Production.Product table and re-run our query from above:
UPDATE Production.Product
SET Product.Color = 'Fuschia'
WHERE Product.ProductID = 325 -- Decal 1
UPDATE Production.Product
SET Product.Color = 'Aquamarine'
WHERE Product.ProductID = 326 -- Decal 2
-- Fuschia and Aquamarine will now be included in the results!

/* Cleanup:
UPDATE Production.Product
SET Product.Color = NULL
WHERE Product.ProductID = 325 -- Decal 1
UPDATE Production.Product
SET Product.Color = NULL
WHERE Product.ProductID = 326 -- Decal 2
*/
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- This query stores the product data returned above in a table for use in an UNPIVOT example below.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT DISTINCT
	Product.Color
FROM Production.Product
WHERE Product.Color IS NOT NULL;

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
INTO dbo.Products_By_Color
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA
';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Return the contents of the new table.
SELECT
	*
FROM dbo.Products_By_Color;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using UNPIVOT to revert column headers back into row data.
SELECT
	*
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color) AS PRODUCTS_BY_COLOR
UNPIVOT
   (product_quantity FOR Color IN 
      ([Black], [Blue], [Grey], [Multi], [Red], [Silver], [Silver/Black], [White], [Yellow])
) AS UNPIVOT_DATA;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- A dynamic UNPIVOT that uses the original data to supply color names at runtime.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT DISTINCT
	Product.Color
FROM Production.Product
WHERE Product.Color IS NOT NULL;

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color) AS PRODUCTS_BY_COLOR
UNPIVOT
   (product_quantity FOR Color IN 
      (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) AS UNPIVOT_DATA;
';

EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- A dynamic UNPIVOT that uses schema data from the PIVOT table to supply all color names.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT
	columns.name
FROM sys.tables
INNER JOIN sys.columns
ON columns.object_id = tables.object_id
WHERE tables.name = 'Products_By_Color'
AND columns.name NOT IN ('product_name', 'ReorderPoint');

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color) AS PRODUCTS_BY_COLOR
UNPIVOT
   (product_quantity FOR Color IN 
      (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) AS UNPIVOT_DATA;
';

EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- An example of using PIVOT to group sales data by quarter.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT
	columns.name
FROM sys.tables
INNER JOIN sys.columns
ON columns.object_id = tables.object_id
WHERE tables.name = 'Products_By_Color'
AND columns.name NOT IN ('product_name', 'ReorderPoint');

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color) AS PRODUCTS_BY_COLOR
UNPIVOT
   (product_quantity FOR Color IN 
      (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) AS UNPIVOT_DATA;
';

EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using PIVOT to group sales data by quarter and by year.
WITH CTE_SALES AS (
	SELECT
		DATEPART(QUARTER, OrderDate) AS order_quarter,
		DATEPART(YEAR, OrderDate) AS order_year,
		TotalDue
	FROM Sales.SalesOrderHeader)
SELECT
	*
FROM
(	SELECT
		*
	FROM CTE_SALES
) PRODUCT_DATA
PIVOT
(	SUM(TotalDue)
	FOR order_quarter IN ([1], [2], [3], [4])
) PIVOT_DATA
ORDER BY order_year ASC;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Getting sum totals for each quarter in one row of results.
WITH CTE_SALES AS (
	SELECT
		'Totals' AS Totals,
		'Q' + CAST(DATEPART(QUARTER, OrderDate) AS VARCHAR(1)) + '-' + 
			  CAST(DATEPART(YEAR, OrderDate) AS VARCHAR(4)) AS quarter_and_year,
		TotalDue
	FROM Sales.SalesOrderHeader)
SELECT
	*
FROM
(	SELECT
		*
	FROM CTE_SALES
) PRODUCT_DATA
PIVOT
(	SUM(TotalDue)
	FOR quarter_and_year IN ([Q2-2011], [Q3-2011], [Q4-2011], [Q1-2012],[Q2-2012], [Q3-2012], [Q4-2012],
							 [Q1-2013],[Q2-2013], [Q3-2013], [Q4-2013], [Q1-2014], [Q2-2014])
) PIVOT_DATA
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Dynamic PIVOT that returns any number of quarters of financial data, without the need to explicitly list them in the TSQL.
DECLARE @quarters TABLE
	(quarter_and_year NVARCHAR(7));

INSERT INTO @quarters
	(quarter_and_year)
SELECT DISTINCT
	'Q' + CAST(DATEPART(QUARTER, OrderDate) AS VARCHAR(1)) + '-' + 
		  CAST(DATEPART(YEAR, OrderDate) AS VARCHAR(4))
FROM Sales.SalesOrderHeader

DECLARE @sql_command NVARCHAR(MAX);

SELECT @sql_command = '
WITH CTE_SALES AS (
	SELECT
		''Totals'' AS Totals,
		''Q'' + CAST(DATEPART(QUARTER, OrderDate) AS VARCHAR(1)) + ''-'' + 
			  CAST(DATEPART(YEAR, OrderDate) AS VARCHAR(4)) AS quarter_and_year,
		TotalDue
	FROM Sales.SalesOrderHeader)
SELECT
	*
FROM
(	SELECT
		*
	FROM CTE_SALES
) PRODUCT_DATA
PIVOT
(	SUM(TotalDue)
	FOR quarter_and_year IN ('

SELECT @sql_command = @sql_command + '[' + quarter_and_year + '], '
FROM @quarters;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA
';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using multiple PIVOT operators in one TSQL statement.
SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity,
		PRODUCT.SafetyStockLevel
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN ([Black], [Blue], [Grey], [Multi], [Red], [Silver], [Silver/Black], [White], [Yellow])
) PIVOT_DATA_COLORS
PIVOT
(	COUNT(SafetyStockLevel)
	FOR SafetyStockLevel IN ([4], [60], [100], [500], [800], [1000])
) PIVOT_DATA_LEVELS
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Using multiple PIVOT operators while also using dynamic SQL to manage the lists.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT DISTINCT
	Product.Color
FROM Production.Product
WHERE Product.Color IS NOT NULL;

DECLARE @stock_levels TABLE
	(safety_stock_level SMALLINT);

INSERT INTO @stock_levels
SELECT DISTINCT
	Product.SafetyStockLevel
FROM Production.Product;

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity,
		PRODUCT.SafetyStockLevel
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA_COLOR
PIVOT
(	COUNT(SafetyStockLevel)
	FOR SafetyStockLevel IN (';

SELECT @sql_command = @sql_command + '[' + CAST(safety_stock_level AS NVARCHAR) + '], '
FROM @stock_levels;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA_LEVEL
';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Collecting PIVOT data for use in the next UNPIVOT demo.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT DISTINCT
	Product.Color
FROM Production.Product
WHERE Product.Color IS NOT NULL;

DECLARE @stock_levels TABLE
	(safety_stock_level SMALLINT);

INSERT INTO @stock_levels
SELECT DISTINCT
	Product.SafetyStockLevel
FROM Production.Product;

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	*
INTO dbo.Products_By_Color_and_Stock_Level
FROM
(	SELECT
		PRODUCT.Name AS product_name,
		PRODUCT.Color AS product_color,
		PRODUCT.ReorderPoint,
		PRODUCT_INVENTORY.Quantity AS product_quantity,
		PRODUCT.SafetyStockLevel
	FROM Production.Product PRODUCT
    LEFT JOIN Production.ProductInventory PRODUCT_INVENTORY
    ON PRODUCT.ProductID = PRODUCT_INVENTORY.ProductID
) PRODUCT_DATA
PIVOT
(	SUM(product_quantity)
	FOR product_color IN (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA_COLOR
PIVOT
(	COUNT(SafetyStockLevel)
	FOR SafetyStockLevel IN (';

SELECT @sql_command = @sql_command + '[' + CAST(safety_stock_level AS NVARCHAR) + '], '
FROM @stock_levels;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) PIVOT_DATA_LEVEL
';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- A flawed attempt at returning results using multiple UNPIVOT operators.  The data is duplicated with a variety
-- of extra mappings of safety stock levels.
SELECT
	*
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color_and_Stock_Level) AS PRODUCTS_BY_COLOR_AND_STOCK_LEVEL
UNPIVOT
   (product_quantity FOR Color IN 
      ([Black], [Blue], [Grey], [Multi], [Red], [Silver], [Silver/Black], [White], [Yellow])
) AS UNPIVOT_DATA_COLOR
UNPIVOT
   (safety_stock_level FOR SafetyStockLevel IN 
      ([4], [60], [100], [500], [800], [1000])
) AS UNPIVOT_DATA_STOCK_LEVEL;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- UNPIVOT example, with the zero values removed from the result set.
SELECT
	product_name,
	ReorderPoint,
	product_quantity,
	Color,
	SafetyStockLevel
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color_and_Stock_Level) AS PRODUCTS_BY_COLOR_AND_STOCK_LEVEL
UNPIVOT
   (product_quantity FOR Color IN 
      ([Black], [Blue], [Grey], [Multi], [Red], [Silver], [Silver/Black], [White], [Yellow])
) AS UNPIVOT_DATA_COLOR
UNPIVOT
   (safety_stock_level FOR SafetyStockLevel IN 
      ([4], [60], [100], [500], [800], [1000])
) AS UNPIVOT_DATA_STOCK_LEVEL
WHERE safety_stock_level <> 0;
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Dynamic SQL used in conjunction with multiple UNPIVOT operators.
DECLARE @colors TABLE
	(color_name VARCHAR(25));

INSERT INTO @colors
	(color_name)
SELECT
	columns.name
FROM sys.tables
INNER JOIN sys.columns
ON columns.object_id = tables.object_id
WHERE tables.name = 'Products_By_Color_and_Stock_Level'
AND columns.name NOT IN ('product_name', 'ReorderPoint')
AND ISNUMERIC(columns.name) = 0;

DECLARE @stock_levels TABLE
	(safety_stock_level SMALLINT);

INSERT INTO @stock_levels
SELECT
	columns.name
FROM sys.tables
INNER JOIN sys.columns
ON columns.object_id = tables.object_id
WHERE tables.name = 'Products_By_Color_and_Stock_Level'
AND columns.name NOT IN ('product_name', 'ReorderPoint')
AND ISNUMERIC(columns.name) = 1;

DECLARE @sql_command NVARCHAR(MAX);
SELECT  @sql_command = '
SELECT
	product_name,
	ReorderPoint,
	product_quantity,
	Color,
	SafetyStockLevel
FROM 
   (SELECT
		*
	FROM dbo.Products_By_Color_and_Stock_Level) AS PRODUCTS_BY_COLOR_AND_STOCK_LEVEL
UNPIVOT
   (product_quantity FOR Color IN 
      (';

SELECT @sql_command = @sql_command + '[' + color_name + '], '
FROM @colors;

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) AS UNPIVOT_DATA_COLOR
UNPIVOT
   (safety_stock_level FOR SafetyStockLevel IN 
      ('
	  
SELECT @sql_command = @sql_command + '[' + CAST(safety_stock_level  AS NVARCHAR) + '], '
FROM @stock_levels;	  

SELECT  @sql_command = SUBSTRING(@sql_command, 1, LEN(@sql_command) - 1);

SELECT  @sql_command = @sql_command + '	)) AS UNPIVOT_DATA_STOCK_LEVEL
WHERE safety_stock_level <> 0;';

PRINT @sql_command;
EXEC sp_executesql @sql_command;
GO
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------