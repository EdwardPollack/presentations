USE WideWorldImporters;
SET NOCOUNT ON;
GO
-----------------------------------------------------------------------------------------------------------------------------
-----------------------------------------Basic Optimization Tools------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------
/*	For any query executed, SQL Server collects an immense amount of information that can be used to learn about how it executed
	and why.  Shown here are: Execution plans, STATISTICS IO, STATISTICS TIME, and data gathered from a variety of dynamic
	management views.	*/

/*	EXECUTION PLANS.  Ctrl-l, ctrl-m or click on the icons in SSMS to view the estimated exceution plan, actual execution plan,
					  or live query statistics. This tells us how the optimizer decided to process our query:
					  How was each table accessed, how was data joined, filtered, and processed in order to result
					  in some output at the end.  This is read right-to-left.	*/

SELECT
	StockItems.StockItemID,
	StockItems.StockItemName,
	StockItems.Size,
	StockItems.UnitPrice,
	Suppliers.SupplierName
FROM Warehouse.StockItems
LEFT JOIN [Application].People -- Note this table is not in the execution plan as it is not used in the query
ON StockItems.LastEditedBy = People.PersonID
INNER JOIN Purchasing.Suppliers
ON StockItems.SupplierID = Suppliers.SupplierID
WHERE StockItems.StockItemName LIKE 'Shipping Carton%';

/*	STATISTICS IO.	Provides basic information about reads, writes, and details on how much data was read from disk vs. memory.
					A read represents a single 8kb page, and therefore the kilobytes read can be derived by multiplying the reads by 8.
					This tells us which tables were responsible for the most IO, which we can compare to the amount of data that exists
					in the table, as well as the amount of data returned in order to judge if it seems too high.
*/
SET STATISTICS IO ON;
GO

SELECT
	StockItems.StockItemID,
	StockItems.StockItemName,
	StockItems.Size,
	StockItems.UnitPrice,
	Suppliers.SupplierName
FROM Warehouse.StockItems
LEFT JOIN [Application].People
ON StockItems.LastEditedBy = People.PersonID
INNER JOIN Purchasing.Suppliers
ON StockItems.SupplierID = Suppliers.SupplierID
WHERE StockItems.StockItemName LIKE 'Shipping Carton%';

/*	STATISTICS TIME.	No metric of performance is as valuable as duration.  Whether a query is slow or a report takes too long is
						determined primarily by how long someone had to wait for their data.  The runtime can be captured by timing
						a query manually, by inserting CURRENT_TIMESTAMP entries in TSQL, or by using STATISTICS TIME:
*/
SET STATISTICS TIME ON; -- Note that server/resource variability will affect this!
GO

SELECT
	StockItems.StockItemID,
	StockItems.StockItemName,
	StockItems.Size,
	StockItems.UnitPrice,
	Suppliers.SupplierName
FROM Warehouse.StockItems
LEFT JOIN [Application].People
ON StockItems.LastEditedBy = People.PersonID
INNER JOIN Purchasing.Suppliers
ON StockItems.SupplierID = Suppliers.SupplierID
WHERE StockItems.StockItemName LIKE 'Shipping Carton%';

/*	CPU: Can be gotten using 3rd party tools, server-level metrics, or via SQL. There are MANY
	ways to do this! CPU should be tracked over time for ideal usage. Spikes happen. Long-term
	trends help to understand overall workload and patterns	*/
WITH CTE_CPU AS (
	SELECT TOP 1 CONVERT(XML, record) AS XmlRecord
				FROM sys.dm_os_ring_buffers
				WHERE dm_os_ring_buffers.ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
				AND dm_os_ring_buffers.record LIKE '% %'
				ORDER BY dm_os_ring_buffers.[timestamp] DESC)
SELECT
	CTE_CPU.XmlRecord.[value]('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT') AS CPUIdle,
	CTE_CPU.XmlRecord.[value]('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT') AS CPUSqlServer
FROM CTE_CPU;

/*	Performance counters: There are a ton of these. This is a sample of what is available.
	These should be tracked over time for the most useful analysis. Long-term trending provides
	invaluable context */
	SELECT
		/*	The first 12 of these are cumulative over time and MUST be stored/diffed to be meaningful! These
			reset on server restart, as well. */
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Extents Allocated/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS ExtentsAllocated,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Full Scans/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS FullScans,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Page Splits/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS PageSplits,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Pages Allocated/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS PagesAllocated,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Worktables Created/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS WorktablesCreated,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Free list stalls/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS FreeListStalls,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Lazy writes/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS LazyWrites,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Logins/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS Logins,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Logouts/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS Logouts,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Batch Requests/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS BatchRequests,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'SQL Compilations/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS SqlComplilations,
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'SQL Re-Compilations/sec' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS SqlRecomplilations,
		-- The rest of these are point-in-time, and can be used as-is:
		SUM(CAST(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Page life expectancy' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4)) AS DECIMAL(18,4))) AS PageLifeExpectancySeconds,	
		SUM(CASE WHEN dm_os_performance_counters.counter_name = 'Average Latch Wait Time (ms)' THEN CAST(dm_os_performance_counters.cntr_value AS DECIMAL(18,4)) ELSE 0 END) /
			SUM(CASE WHEN dm_os_performance_counters.counter_name = 'Average Latch Wait Time Base' THEN CAST(dm_os_performance_counters.cntr_value AS DECIMAL(18,4)) ELSE 0 END) AS AverageLatchWaitTimeMS,
		SUM(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Connection Memory (KB)' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4))) AS ConnectionMemoryKB,
		SUM(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Granted Workspace Memory (KB)' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4))) AS GrantedWorkspaceMemoryKB,
		SUM(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Memory Grants Pending' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4))) AS MemoryGrantsPending,
		SUM(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'User Connections' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS INT)) AS UserConnectionCount,
		CAST(SUM(CAST(CASE WHEN dm_os_performance_counters.counter_name = 'Free Memory (KB)' THEN dm_os_performance_counters.cntr_value ELSE 0 END AS DECIMAL(18,4))) / 1024.0000 AS INT) AS FreeMemoryMB
	FROM sys.dm_os_performance_counters
	WHERE (dm_os_performance_counters.object_name LIKE '%Buffer Manager%' AND dm_os_performance_counters.counter_name IN ('Free list stalls/sec', 'Lazy writes/sec', 'Page life expectancy'))
	OR (dm_os_performance_counters.object_name LIKE '%General Statistics%' AND dm_os_performance_counters.counter_name IN ('Logins/sec', 'Logouts/sec', 'User Connections'))
	OR (dm_os_performance_counters.object_name LIKE '%Access Methods%' AND dm_os_performance_counters.counter_name IN ('Full Scans/sec', 'Worktables Created/sec', 'Pages Allocated/sec', 'Extents Allocated/sec', 'Page Splits/sec'))
	OR (dm_os_performance_counters.object_name LIKE '%SQL Statistics%' AND dm_os_performance_counters.counter_name IN ('Batch Requests/sec', 'SQL Compilations/sec', 'SQL Re-Compilations/sec'))
	OR (dm_os_performance_counters.object_name LIKE '%Memory Manager%' AND dm_os_performance_counters.counter_name IN ('Connection Memory (KB)', 'Granted Workspace Memory (KB)', 'Memory Grants Pending', 'Free Memory (KB)'))
	OR (dm_os_performance_counters.object_name LIKE '%Latches%' AND dm_os_performance_counters.counter_name IN ('Average Latch Wait Time (ms)', 'Average Latch Wait Time Base'));

	-- Blocked processes
	SELECT
		COUNT(*) AS BlockedProcessCount
	FROM sys.dm_exec_requests
	WHERE dm_exec_requests.blocking_session_id <> 0
	AND dm_exec_requests.blocking_session_id IS NOT NULL;

	/*	Median plan age: Provides info on how long execution plans are staying in cache.
		No results means nothing in cache */
	SELECT DISTINCT
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY DATEDIFF(SECOND, dm_exec_query_stats.creation_time, GETDATE()))
			OVER (PARTITION BY 1) / 60 AS Median_Cont
	FROM sys.dm_exec_query_stats;

	/*	Currently running processes, sorted by TOP CPU consumers first	*/
	SELECT TOP 100 s.session_id,
		DB_NAME(r.database_id) AS databasename,
        r.status,
        r.cpu_time,
        r.logical_reads,
        r.reads,
        r.writes,
        r.total_elapsed_time / (1000 * 60) 'Elaps M',
        r.total_elapsed_time / 1000 'Elaps s',
        SUBSTRING(st.TEXT, (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.TEXT)
            ELSE r.statement_end_offset
        END - r.statement_start_offset) / 2) + 1) AS statement_text,
        COALESCE(QUOTENAME(DB_NAME(st.dbid)) + N'.' + QUOTENAME(OBJECT_SCHEMA_NAME(st.objectid, st.dbid)) 
        + N'.' + QUOTENAME(OBJECT_NAME(st.objectid, st.dbid)), '') AS command_text,
        r.command,
        s.login_name,
        s.host_name,
        s.program_name,
        s.last_request_end_time,
        s.login_time,
        r.open_transaction_count,
		r.row_count,
		dm_exec_connections.client_net_address,
		dm_exec_connections.client_tcp_port
	FROM sys.dm_exec_sessions AS s WITH (NOLOCK)
	JOIN sys.dm_exec_requests AS r WITH (NOLOCK) ON r.session_id = s.session_id CROSS APPLY sys.Dm_exec_sql_text(r.sql_handle) AS st
	LEFT JOIN sys.dm_exec_connections WITH (NOLOCK) ON dm_exec_connections.connection_id = r.connection_id
	-- WHERE r.session_id != @@SPID
	ORDER BY r.cpu_time DESC;

-----------------------------------------------------------------------------------------------------------------------------
-----------------------------------------Implicit Conversions----------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------
/*	SQL Server will automatically convert a column of one data type to another that is compared against it whenever possible.
	Oftentimes, these conversions will result in a index scan as part of the conversion, as the optimizer is incapable of determining
	statistics on a column without the data types matching.  The result can be poor performance that is easily fixable by us.
*/

SELECT
	Invoices.InvoiceID,
	Invoices.ContactPersonID,
	Invoices.IsCreditNote,
	Invoices.CustomerID
FROM Sales.Invoices
WHERE Invoices.CustomerPurchaseOrderNumber = 17913;

CREATE NONCLUSTERED INDEX IX_Invoices_CustomerPurchaseOrderNumber
ON Sales.Invoices (CustomerPurchaseOrderNumber);

SELECT
	Invoices.InvoiceID,
	Invoices.ContactPersonID,
	Invoices.IsCreditNote,
	Invoices.CustomerID
FROM Sales.Invoices
WHERE Invoices.CustomerPurchaseOrderNumber = 17913;

SELECT
	Invoices.InvoiceID,
	Invoices.ContactPersonID,
	Invoices.IsCreditNote,
	Invoices.CustomerID
FROM Sales.Invoices
WHERE Invoices.CustomerPurchaseOrderNumber = '17913';

DROP INDEX IX_Invoices_CustomerPurchaseOrderNumber
ON Sales.Invoices;

-- This query has an OR in the join predicate.  This forces SQL Server to do many scans to figure out the union of the two data sets.
SELECT
	Invoices.InvoiceID,
	Invoices.ContactPersonID,
	Invoices.IsCreditNote,
	Invoices.CustomerID
FROM Sales.Invoices
INNER JOIN Sales.Orders
ON Orders.OrderID = Invoices.OrderID
OR Orders.CustomerID = Invoices.CustomerID
-- Here, OR was likely a typo. Otherwise, split into 2 queries with UNION or UNION ALL to resolve!
SELECT
	Invoices.InvoiceID,
	Invoices.ContactPersonID,
	Invoices.IsCreditNote,
	Invoices.CustomerID
FROM Sales.Invoices
INNER JOIN Sales.Orders
ON Orders.OrderID = Invoices.OrderID
AND Orders.CustomerID = Invoices.CustomerID

-- Leading wildcard forces an index scan. Fuzzy searches are EXPENSIVE!
SELECT
	People.PersonID,
	People.FullName,
	People.IsPermittedToLogon
FROM [Application].People
WHERE People.FullName LIKE '%Oliver%';
-- Remove whenever possible. Transactional tables are not ideal for text search. Use a better tool for that.
SELECT
	People.PersonID,
	People.FullName,
	People.IsPermittedToLogon
FROM [Application].People
WHERE People.FullName LIKE 'Oliver%';
-- Wildcard searches are (by definition) table scans

-- Avoid functions on columns! They help create lousy plans that need more data than they should:
SELECT
	People.PersonID,
	People.FullName,
	People.IsPermittedToLogon
FROM [Application].People
WHERE CAST(People.FullName AS VARCHAR(50)) LIKE 'Oliver%';

-- Move functions to scalars:
SELECT
	People.PersonID,
	People.FullName,
	People.IsPermittedToLogon
FROM [Application].People
WHERE People.FullName LIKE CAST('Oliver%' AS VARCHAR(50));

-- Is CAST even needed?
SELECT
	People.PersonID,
	People.FullName,
	People.IsPermittedToLogon
FROM [Application].People
WHERE People.FullName LIKE 'Oliver%';

-----------------------------------------------------------------------------------------------------------------------------
-----------------------------------------Iteration vs. Set-based operations--------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------
/*	Iteration is typically less efficient for any operations in which larger volumes of data are needed.  Each iteration/loop
	requires accessing data, pulling pages from memory or storage, which can be expensive when repeated over and over again.
*/

DECLARE @id INT = (SELECT MIN(People.PersonID) FROM [Application].People)
WHILE @id <= 100
BEGIN
	UPDATE [Application].People
		SET IsExternalLogonProvider = 0
	WHERE PersonID = @id;
	
	SET @id = @id + 1;
END

UPDATE [Application].People
SET IsExternalLogonProvider = 0
WHERE PersonID <= 100;
-----------------------------------------------------------------------------------------------------------------------------
-----------------------------------------Reduce Table Count------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------
/*	The query optimizer has to sift through a large number of candidate execution plans in order to make a good decision as to
	the best plan to choose.  Table order, join type, and decisions about when to sort, filter, and aggregate will all play a part
	in this decisioin making process.

	The number of plans the optimizer must search grows by a factorial expression with each added table.  There is some variability
	based on the type of query, but you can estimate the work that the	optimizer needs to do by taking the factorial of the number
	of tables involved in the query.

	The query tree for a given query determines how scary the numbers are here.  A left-deep query tree is one in which there is a
	single anchor table, and each additional table joins to that via the next table.  Ie, Table A joins B, which joins C, which joins D.
	A bushy tree is one in which different tables join to each other in a somewhat evently distributed pattern.  Ie, Table A joins B,
	Table C joins D, and Table A joins D.  The latter scenario is more complex and presents more work for the optimizer.

	For example, for 6 tables, the number of candidate plans for a left-deep tree would be approximately 6! = 6*5*4*3*2*1 = 720.
	For a bushy tree, the number of candidate plans would be (2n-2)!/(n-1)! = (6*2-2)!/(6-1)! = 10!/5! = 10*9*8*7*6 = 30,240.
	
	To keep things simple, knowing that the order of magnitude of # of plans possible is based on factorial math is good enough
	for our needs.
*/
-- Scary query with too many tables & too many joins.  Tries to do too much at once!
SELECT TOP 25
	[Product].*,
	CostMeasure.*,
	ProductVendor.*,
	ProductReview.*
FROM Production.[Product]
INNER JOIN Production.ProductSubCategory
ON ProductSubCategory.ProductSubcategoryID = [Product].ProductSubcategoryID
INNER JOIN Production.ProductCategory
ON ProductCategory.ProductCategoryID = ProductSubCategory.ProductCategoryID
INNER JOIN Production.UnitMeasure SizeUnitMeasureCode
ON [Product].SizeUnitMeasureCode = SizeUnitMeasureCode.UnitMeasureCode
INNER JOIN Production.UnitMeasure WeightUnitMeasureCode
ON [Product].WeightUnitMeasureCode = WeightUnitMeasureCode.UnitMeasureCode
INNER JOIN Production.ProductModel
ON ProductModel.ProductModelID = [Product].ProductModelID
LEFT JOIN Production.ProductModelIllustration
ON ProductModel.ProductModelID = ProductModelIllustration.ProductModelID
LEFT JOIN Production.ProductModelProductDescriptionCulture
ON ProductModelProductDescriptionCulture.ProductModelID = ProductModel.ProductModelID
LEFT JOIN Production.ProductDescription
ON ProductDescription.ProductDescriptionID = ProductModelProductDescriptionCulture.ProductDescriptionID
LEFT JOIN Production.ProductReview
ON ProductReview.ProductID = [Product].ProductID
LEFT JOIN Purchasing.ProductVendor
ON ProductVendor.ProductID = [Product].ProductID
LEFT JOIN Production.UnitMeasure CostMeasure
ON ProductVendor.UnitMeasureCode = CostMeasure.UnitMeasureCode
ORDER BY [Product].ProductID DESC;

-- Break the scary query into a few smaller ones, and be sure to only include tables you need and only return
-- the columns that are required by the application.
SELECT TOP 25
	[Product].ProductID,
	[Product].[Name] AS ProductName,
	[Product].ProductNumber,
	ProductCategory.[Name] AS ProductCategory,
	ProductSubCategory.[Name] AS ProductSubCategory,
	[Product].ProductModelID
INTO #Product
FROM Production.[Product]
INNER JOIN Production.ProductSubCategory
ON ProductSubCategory.ProductSubcategoryID = [Product].ProductSubcategoryID
INNER JOIN Production.ProductCategory
ON ProductCategory.ProductCategoryID = ProductSubCategory.ProductCategoryID
ORDER BY ProductID DESC;

SELECT TOP 25
	[Product].ProductID,
	[Product].ProductName,
	[Product].ProductNumber,
	[Product].ProductCategory,
	[Product].ProductSubCategory,
	CostMeasure.[Name] AS CostMeasureName,
	ProductVendor.StandardPrice,
	ProductReview.Rating
FROM #Product [Product]
INNER JOIN Production.ProductModel
ON ProductModel.ProductModelID = [Product].ProductModelID
LEFT JOIN Production.ProductModelIllustration
ON ProductModel.ProductModelID = ProductModelIllustration.ProductModelID
LEFT JOIN Production.ProductModelProductDescriptionCulture
ON ProductModelProductDescriptionCulture.ProductModelID = ProductModel.ProductModelID
LEFT JOIN Production.ProductDescription
ON ProductDescription.ProductDescriptionID = ProductModelProductDescriptionCulture.ProductDescriptionID
LEFT JOIN Production.ProductReview
ON ProductReview.ProductID = [Product].ProductID
LEFT JOIN Purchasing.ProductVendor
ON ProductVendor.ProductID = [Product].ProductID
LEFT JOIN Production.UnitMeasure CostMeasure
ON ProductVendor.UnitMeasureCode = CostMeasure.UnitMeasureCode;

DROP TABLE #Product;
GO
-----------------------------------------------------------------------------------------------------------------------------
-------------------------------------------Nested Objects--------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------
SET STATISTICS TIME OFF;

SELECT
	*
FROM Website.Customers -- Do we really need all of these tables?!
WHERE CustomerID = 1;

SELECT
	*
FROM Sales.Customers
WHERE CustomerID = 1;