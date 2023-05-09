USE WideWorldImportersDW;
SET STATISTICS IO ON;
SET NOCOUNT ON;
GO
/************************************************************************************************
DEMO: Enabling/Disabling IQP Features and Viewing Usage
************************************************************************************************/
-- Altering compatibility level will disable any IQP features tied to a newer version of SQL Server.
-- This is a sledgehammer that will impact other features and is not the ideal solution to solve a specific IQP problem.
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
-- Sets compatibility level to SQL Server 2017.  IQP features from 2019+ are not enabled
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
-- Sets compatibility level to SQL Server 2019.  IQP features from 2022+ are not enabled
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 160;
-- Sets compatibility level to SQL Server 2022.  All current IQP features are enabled.

-- IQP features can be enabled or disabled as database-scoped configurations:
-- Disable cardinality estimation feedback on the current database.
ALTER DATABASE SCOPED CONFIGURATION SET CE_FEEDBACK = OFF;
-- Enable cardinality estimation feedback on the current database.
ALTER DATABASE SCOPED CONFIGURATION SET CE_FEEDBACK = ON;

-- sys.database_scoped_configurations can be used to validate current database scoped configurations on the current database.
SELECT
	*
FROM sys.database_scoped_configurations;

-- You can take a look at all database-scoped configurations for IQP:
SELECT
	*
FROM sys.database_scoped_configurations
WHERE name IN ('INTERLEAVED_EXECUTION_TVF', 'BATCH_MODE_MEMORY_GRANT_FEEDBACK', 'BATCH_MODE_ADAPTIVE_JOINS',
'TSQL_SCALAR_UDF_INLINING', 'ROW_MODE_MEMORY_GRANT_FEEDBACK', 'BATCH_MODE_ON_ROWSTORE', 'DEFERRED_COMPILATION_TV',
'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION', 'CE_FEEDBACK', 'MEMORY_GRANT_FEEDBACK_PERSISTENCE',
'MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT', 'OPTIMIZED_PLAN_FORCING', 'DOP_FEEDBACK')

-- Want to see only the non-default database-scoped configurations?
SELECT
	*
FROM sys.database_scoped_configurations
WHERE database_scoped_configurations.is_value_default = 0;

ALTER DATABASE SCOPED CONFIGURATION SET DOP_FEEDBACK = ON;

SELECT
	*
FROM sys.database_scoped_configurations
WHERE database_scoped_configurations.is_value_default = 0;

ALTER DATABASE SCOPED CONFIGURATION SET DOP_FEEDBACK = OFF;

-- IQP features can be disabled at the query level.  This example disables cardinality estimation for this particular query execution.
SELECT
	[order].[Order Key],
	[Stock Item].[Lead Time Days],
	[order].[Quantity]
FROM Fact.[order]
INNER JOIN Dimension.[Stock Item]
ON [order].[Stock Item Key] = [Stock Item].[Stock Item Key]
WHERE [order].[Quantity] = 360
OPTION (USE HINT('DISABLE_CE_FEEDBACK'));
/************************************************************************************************
DEMO: Adaptive Joins
************************************************************************************************/
-- Check compatibility level
SELECT
	databases.name,
	compatibility_level
FROM sys.databases
WHERE databases.name = DB_NAME();
GO
-- SQL Server 2014 (Compatibility level = 120)
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = 'ALTER DATABASE [' + DB_NAME() + '] SET COMPATIBILITY_LEVEL = 120'; -- SQL Server 2014
EXEC sp_executesql @sql_command;

-- Note: Merge Join!  Query cost ~ 0.499
SELECT
	[order].[Order Key],
	[Stock Item].[Lead Time Days],
	[order].[Quantity]
FROM Fact.[order]
INNER JOIN Dimension.[Stock Item]
ON [order].[Stock Item Key] = [Stock Item].[Stock Item Key]
WHERE [order].[Quantity] = 360;
GO

-- SQL Server 2016 (Compatibility level = 130)
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = 'ALTER DATABASE [' + DB_NAME() + '] SET COMPATIBILITY_LEVEL = 130'; -- SQL Server 2016
EXEC sp_executesql @sql_command;

-- Note: Hash Match!  Query cost ~ 0.1
SELECT
	[order].[Order Key],
	[Stock Item].[Lead Time Days],
	[order].[Quantity]
FROM Fact.[order]
INNER JOIN Dimension.[Stock Item]
ON [order].[Stock Item Key] = [Stock Item].[Stock Item Key]
WHERE [order].[Quantity] = 360;
GO
-- SQL Server 2017 (Compatibility level = 140)
DECLARE @sql_command NVARCHAR(MAX);
SELECT @sql_command = 'ALTER DATABASE [' + DB_NAME() + '] SET COMPATIBILITY_LEVEL = 140'; -- SQL Server 2017
EXEC sp_executesql @sql_command;

-- Note: Adaptive Join!  Query cost ~ 0.1
SELECT
	[order].[Order Key],
	[Stock Item].[Lead Time Days],
	[order].[Quantity]
FROM Fact.[order]
INNER JOIN Dimension.[Stock Item]
ON [order].[Stock Item Key] = [Stock Item].[Stock Item Key]
WHERE [order].[Quantity] = 360;
GO
/************************************************************************************************
DEMO: Table Variable Deferred Compilation
************************************************************************************************/

ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140; -- SQL Server 2017 (140)

DECLARE @tvdc_demc TABLE
(	Id INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	order_number BIGINT NOT NULL);

INSERT INTO @tvdc_demc
	(order_number)
SELECT
	[Order].[Order Key]
FROM Fact.[Order];

-- Note estimated rows are set to 1 in the execution plan operator for the table variable.
SELECT COUNT(*) FROM @tvdc_demc WHERE order_number <= 5000;
GO

ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 160; -- SQL Server 2022 (160)
GO

DECLARE @tvdc_demc TABLE
(	Id INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	order_number BIGINT NOT NULL);

INSERT INTO @tvdc_demc
	(order_number)
SELECT
	[Order].[Order Key]
FROM Fact.[Order];

-- Note estimated rows are set to 231412 in the execution plan operator for the table variable.
SELECT COUNT(*) FROM @tvdc_demc WHERE order_number <= 5000;

/************************************************************************************************
DEMO: Batch Mode on Rowstore
************************************************************************************************/
USE WideWorldImportersDW;
GO
-- Can enable or disable with a database-scoped configuration change:
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = OFF;

ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = ON;

-- Example columnstore query that uses batch mode
SELECT [Tax Rate], [Lineage Key], [Salesperson Key], SUM(Quantity) AS SUM_QTY, SUM([Unit Price]) AS SUM_BASE_PRICE, COUNT(*) AS COUNT_ORDER
FROM Fact.[Order]
WHERE [Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY [Tax Rate], [Lineage Key], [Salesperson Key]
ORDER BY [Tax Rate], [Lineage Key], [Salesperson Key];

-- Can disable batch mode if needed, including on columnstore.  Not advised to disable unless exceptional reasons exist.
SELECT [Tax Rate], [Lineage Key], [Salesperson Key], SUM(Quantity) AS SUM_QTY, SUM([Unit Price]) AS SUM_BASE_PRICE, COUNT(*) AS COUNT_ORDER
FROM Fact.[Order]
WHERE [Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY [Tax Rate], [Lineage Key], [Salesperson Key]
ORDER BY [Tax Rate], [Lineage Key], [Salesperson Key]
OPTION(RECOMPILE, USE HINT('DISALLOW_BATCH_MODE'));

-- Uses row mode as row counts are not large enough to justify batch mode
SELECT
	COUNT(*) AS row_count,
	SUM([Latest Recorded Population]) AS [Latest Recorded Population]
FROM Dimension.City;

-- The option to use batch mode does not force it!  This allows it to be used, but the optimizer must choose it.
SELECT
	COUNT(*) AS row_count,
	SUM([Latest Recorded Population]) AS [Latest Recorded Population]
FROM Dimension.City
OPTION(RECOMPILE, USE HINT('ALLOW_BATCH_MODE')); -- This allows batch mode, it doesn't force it :-)

USE AdventureWorks2017;
GO
/*
-- Create larger table to demo batch mode on rowstore
CREATE TABLE [dbo].[SalesOrderDetail_BIG](
	[SalesOrderID] [INT] NOT NULL,
	[SalesOrderDetailID] [INT] NOT NULL,
	[CarrierTrackingNumber] [NVARCHAR](25) NULL,
	[OrderQty] [SMALLINT] NOT NULL,
	[ProductID] [INT] NOT NULL,
	[SpecialOfferID] [INT] NOT NULL,
	[UnitPrice] [MONEY] NOT NULL,
	[UnitPriceDiscount] [MONEY] NOT NULL,
	[LineTotal] [NUMERIC](38, 6) NOT NULL,
	[rowguid] [UNIQUEIDENTIFIER] NOT NULL,
	[ModifiedDate] [DATETIME] NOT NULL);
GO
-- Pile in some data
INSERT INTO SalesOrderDetail_BIG
SELECT * FROM sales.SalesOrderDetail
GO 25
*/

ALTER DATABASE AdventureWorks2017 SET COMPATIBILITY_LEVEL = 140;

-- SQL Server 2017: Batch mode on rowstore did not exist yet.
SELECT
	ProductID,
	SUM(OrderQty) AS TotalQTY
FROM dbo.SalesOrderDetail_BIG
GROUP BY ProductID
ORDER BY SUM(OrderQty) DESC;

ALTER DATABASE AdventureWorks2017 SET COMPATIBILITY_LEVEL = 150;

-- Uses batch mode on rowstore.  Yay!
-- Note the simpler execution plan!!
SELECT
	ProductID,
	SUM(OrderQty) AS TotalQTY
FROM dbo.SalesOrderDetail_BIG
GROUP BY ProductID
ORDER BY SUM(OrderQty) DESC;

/************************************************************************************************
DEMO: Approximate Query Processing
************************************************************************************************/

USE WideWorldImportersDW;
GO

-- Classic COUNT DISTINCT
SELECT
	COUNT(DISTINCT [Customer Key])
FROM Fact.[Order];
-- Approx_Count_Distinct returns a different, but close value
SELECT
	APPROX_COUNT_DISTINCT([Customer Key])
FROM Fact.[Order];
-- No difference in resource usage (this time).

-- Classic COUNT DISTINCT
SELECT
	COUNT(DISTINCT [State Province])
FROM Dimension.City; -- Query cost ~3.48
-- This returns the same value in this case, but uses less compute to do so
SELECT
	APPROX_COUNT_DISTINCT([State Province])
FROM Dimension.City; -- Query cost ~2.77
GO

