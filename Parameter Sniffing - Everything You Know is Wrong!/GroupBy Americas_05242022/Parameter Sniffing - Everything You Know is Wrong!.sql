USE WideWorldImporters;
SET STATISTICS IO ON;
GO
/******************************************************************************************
								DEMO: EXECUTION PLANS
******************************************************************************************/
-- View execution plan & details.
SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = 1015;

/******************************************************************************************
								DEMO: The Plan Cache
******************************************************************************************/
-- Completely clears the plan cache
DBCC FREEPROCCACHE; -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING
-- Can also clear specific plan handles or resource pools.

-- Clears the plan cache for the database specified
DECLARE @database_id INT = DB_ID() 
DBCC FLUSHPROCINDB (@database_id); -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING

SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = 1015;

-- Gets details about execution plans in the plan cache
SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
-- AND qt.text NOT LIKE '%dm_exec_query_stats%'

SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = 1018;

SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = 1020;

SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = -1

SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
AND qt.text NOT LIKE '%dm_exec_query_stats%';

/******************************************************************************************
								DEMO: Parameterization
******************************************************************************************/
DBCC FREEPROCCACHE; -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING
GO

CREATE PROCEDURE dbo.get_customer_order_details
	@CustomerID INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		Orders.OrderID,
		Orders.OrderDate,
		Orders.ExpectedDeliveryDate
	FROM Sales.Orders
	WHERE Orders.CustomerID = @CustomerID;
END
GO

EXEC dbo.get_customer_order_details @CustomerID = 1015;

SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
AND qt.text NOT LIKE '%dm_exec_query_stats%';

EXEC dbo.get_customer_order_details @CustomerID = 1015;
EXEC dbo.get_customer_order_details @CustomerID = 1016;
EXEC dbo.get_customer_order_details @CustomerID = 1018;
EXEC dbo.get_customer_order_details @CustomerID = -1;
EXEC dbo.get_customer_order_details @CustomerID = 99999;

SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
AND qt.text NOT LIKE '%dm_exec_query_stats%';

/******************************************************************************************
								DEMO: Parameter Sniffing
******************************************************************************************/
DBCC FREEPROCCACHE; -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING
GO

CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON Sales.Orders (OrderDate);
GO

-- This stored procedure returns some order data for a given date range.
CREATE PROCEDURE dbo.get_order_details_by_date_range
	@start_date DATE, @end_date DATE
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		Orders.OrderID,
		Orders.CustomerID,
		Orders.ExpectedDeliveryDate
	FROM Sales.Orders
	WHERE Orders.OrderDate >= @start_date
	AND Orders.OrderDate < @end_date;
END
GO

EXEC dbo.get_order_details_by_date_range @start_date = '5/30/2016', @end_date = '6/1/2016'

DBCC FREEPROCCACHE; -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING
GO

EXEC dbo.get_order_details_by_date_range @start_date = '5/30/2014', @end_date = '6/1/2016'

DBCC FREEPROCCACHE; -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING
GO

/******************************************************************************************
								DEMO: Redeclare Parameters Locally
******************************************************************************************/
-- This stored procedure redeclares parameters as local variables, providing a mediocre plan.
CREATE PROCEDURE dbo.get_order_details_by_date_range_local_variables
	@start_date DATE, @end_date DATE
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @start_date_local DATE = @start_date;
	DECLARE @end_date_local DATE = @end_date;

	SELECT
		Orders.OrderID,
		Orders.CustomerID,
		Orders.ExpectedDeliveryDate
	FROM Sales.Orders
	WHERE Orders.OrderDate >= @start_date_local
	AND Orders.OrderDate < @end_date_local;
END
GO

EXEC dbo.get_order_details_by_date_range_local_variables @start_date = '5/30/2016', @end_date = '6/1/2016';

EXEC dbo.get_order_details_by_date_range_local_variables @start_date = '5/30/2014', @end_date = '6/1/2016';

EXEC dbo.get_order_details_by_date_range_local_variables @start_date = '5/30/2017', @end_date = '6/1/2017';
GO

/******************************************************************************************
								DEMO: OPTION (RECOMPILED)
******************************************************************************************/
-- Clears the plan cache for the database specified
DECLARE @database_id INT = DB_ID() 
DBCC FLUSHPROCINDB (@database_id); -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING

SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = 1015;

-- Gets details about execution plans in the plan cache
SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
AND qt.text NOT LIKE '%dm_exec_query_stats%';

-- Generates new execution plan using current parameters/values.
SELECT
	Orders.OrderID,
	Orders.OrderDate,
	Orders.ExpectedDeliveryDate
FROM Sales.Orders
WHERE Orders.CustomerID = 1015
OPTION (RECOMPILE);

-- Nothing has changed here
SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
AND qt.text NOT LIKE '%dm_exec_query_stats%';
GO
/******************************************************************************************
								DEMO: DYNAMIC SQL
******************************************************************************************/
-- Clears the plan cache for the database specified
DECLARE @database_id INT = DB_ID() 
DBCC FLUSHPROCINDB (@database_id); -- NEVER RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING
GO

CREATE PROCEDURE dbo.get_order_details_by_date_range_dynamic_sql
	@start_date DATE, @end_date DATE
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sql_command NVARCHAR(MAX);
	SELECT @sql_command = '
		SELECT
			Orders.OrderID,
			Orders.CustomerID,
			Orders.ExpectedDeliveryDate
		FROM Sales.Orders
		WHERE Orders.OrderDate >= ''' + CAST(@start_date AS VARCHAR(MAX)) + '''
		AND Orders.OrderDate < ''' + CAST(@end_date AS VARCHAR(MAX)) + ''';';
	-- Note that these become literal SQL strings and plan reuse cannot occur unless parameters are the same as a previous execution.
	EXEC sp_executesql @sql_command;
END
GO

EXEC dbo.get_order_details_by_date_range_dynamic_sql @start_date = '5/30/2016', @end_date = '6/1/2016';

EXEC dbo.get_order_details_by_date_range_dynamic_sql @start_date = '5/30/2014', @end_date = '6/1/2016';

EXEC dbo.get_order_details_by_date_range_dynamic_sql @start_date = '5/30/2017', @end_date = '6/1/2017';
-- Note that execution plans are created for each set of parameters.
GO

SELECT
	DB_NAME(qt.dbid) AS [Database_Name],
	qt.text AS [Query_Text],
	qs.execution_count AS [Execution_Count],
	qs.total_logical_reads AS [Total_Logical_Reads],
	qs.last_logical_reads AS [Last_Logical_Reads],
	qs.total_logical_writes AS [Total_Logical_Writes],
	qs.last_logical_writes AS [Last_Logical_Writes],
	qs.total_worker_time AS [Total_Worker_Time],
	qs.last_worker_time AS [Last_Worker_Time],
	qs.total_elapsed_time/1000000 AS [Total_Elapsed_Time_In_S],
	qs.last_elapsed_time/1000000 AS [Last_Elapsed_Time_In_S],
	qs.last_execution_time AS [Last_Execution_Time],
	qp.query_plan AS [Query_Plan],
	tqp.query_plan AS [Text_Query_Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 0, -1) tqp
WHERE qt.text LIKE '%Sales.Orders%'
AND qt.text NOT LIKE '%dm_exec_query_stats%';
GO

/******************************************************************************************
								DEMO: OPTIMIZE FOR
******************************************************************************************/
-- This stored procedure returns some order data for a given date range and uses the OPTIMIZE FOR hint
CREATE PROCEDURE dbo.get_order_details_by_date_range_optimize_for
	@start_date DATE, @end_date DATE
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		Orders.OrderID,
		Orders.CustomerID,
		Orders.ExpectedDeliveryDate
	FROM Sales.Orders
	WHERE Orders.OrderDate >= @start_date
	AND Orders.OrderDate < @end_date
	OPTION (OPTIMIZE FOR (@start_date = '1/1/2016', @end_date = '1/3/2016'));
END
GO
-- This is optimal
EXEC dbo.get_order_details_by_date_range_optimize_for @start_date = '5/30/2016', @end_date = '6/1/2016';
-- This is the wrong plan :-\
EXEC dbo.get_order_details_by_date_range_optimize_for @start_date = '5/30/2014', @end_date = '6/1/2016';
-- This is optimal
EXEC dbo.get_order_details_by_date_range_optimize_for @start_date = '5/30/2017', @end_date = '6/1/2017';
-- This is optimal
EXEC dbo.get_order_details_by_date_range_optimize_for @start_date = '1/1/2016', @end_date = '1/5/2016';
GO
/******************************************************************************************
								DEMO: Temporary Stored Procedures
******************************************************************************************/
-- This stored procedure returns some order data for a given date range and persists until dropped or the session ends
CREATE PROCEDURE #get_order_details_by_date_range_temporary
	@start_date DATE, @end_date DATE
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		Orders.OrderID,
		Orders.CustomerID,
		Orders.ExpectedDeliveryDate
	FROM Sales.Orders
	WHERE Orders.OrderDate >= @start_date
	AND Orders.OrderDate < @end_date;
END
GO

EXEC #get_order_details_by_date_range_temporary @start_date = '5/30/2016', @end_date = '6/1/2016';

EXEC #get_order_details_by_date_range_temporary @start_date = '6/1/2016', @end_date = '6/8/2016';

EXEC #get_order_details_by_date_range_temporary @start_date = '6/1/2014', @end_date = '6/8/2016';

DROP PROCEDURE #get_order_details_by_date_range_temporary;
GO
/******************************************************************************************
								DEMO: Query hint: DISABLE_PARAMETER_SNIFFING
******************************************************************************************/
-- This stored procedure returns some order data for a given date range using the DISABLE_PARAMETER_SNIFFING hint
CREATE PROCEDURE dbo.get_order_details_by_date_range_disable_parameter_sniffing
	@start_date DATE, @end_date DATE
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		Orders.OrderID,
		Orders.CustomerID,
		Orders.ExpectedDeliveryDate
	FROM Sales.Orders
	WHERE Orders.OrderDate >= @start_date
	AND Orders.OrderDate < @end_date
	OPTION (USE HINT ('DISABLE_PARAMETER_SNIFFING'));
END
GO

EXEC dbo.get_order_details_by_date_range_disable_parameter_sniffing @start_date = '5/30/2016', @end_date = '6/1/2016';

EXEC dbo.get_order_details_by_date_range_disable_parameter_sniffing @start_date = '5/30/2014', @end_date = '6/1/2016';

EXEC dbo.get_order_details_by_date_range_disable_parameter_sniffing @start_date = '5/30/2017', @end_date = '6/1/2017';

EXEC dbo.get_order_details_by_date_range_disable_parameter_sniffing @start_date = '1/1/2016', @end_date = '1/5/2016';
GO
-- Lots of garbage plans based on average statistics :-\

-- CLEANUP:
DROP PROCEDURE dbo.get_customer_order_details;
GO
DROP PROCEDURE dbo.get_order_details_by_date_range;
GO
DROP PROCEDURE dbo.get_order_details_by_date_range_local_variables;
GO
DROP PROCEDURE dbo.get_order_details_by_date_range_dynamic_sql;
GO
DROP PROCEDURE dbo.get_order_details_by_date_range_optimize_for;
GO
DROP PROCEDURE dbo.get_order_details_by_date_range_disable_parameter_sniffing;
GO
