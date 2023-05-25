/*	My Favorite New T-SQL in SQL Server 2022
	Ed Pollack
	
	Created and tested using SQL Server 2022: 16.0.1050.5 (February, 2023)
	Future/previous versions will have different features sets and
	may behave differently.
*/
USE WideWorldImporters;
SET STATISTICS IO ON;
GO
/**************************************************************************************
*****************************Compatibility Level Notes*********************************
***************************************************************************************/

ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL = 150; -- SQL Server 2019
GO
-- IS DISTINCT/IS NOT DISTINCT is SQL Server 2022+ syntax
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID IS DISTINCT FROM BackOrderOrderID;
-- Works in 2019 compatibility level.
ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL = 100; -- SQL Server 2008R2
GO
-- Works in 2008R2 compatibility level.
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID IS DISTINCT FROM BackOrderOrderID;

ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL = 160; -- SQL Server 2022
GO
-- ***NOT ALL FEATURES/SYNTAX WORK ACROSS ALL COMPATIBILITY LEVELS, BUT MOST DO***
/**************************************************************************************
*****************************IS (NOT) DISTINCT FROM************************************
***************************************************************************************/
-- Returns 59,390 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID <> 3; -- Does not include NULL.  Incurs ANSI_NULLS risk.  Did you want NULLs included?

-- Returns 59,390 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE ISNULL(PickedByPersonID, 3) <> 3 ; -- Does not include NULL.
-- Does not incur ANSI_NULLS risk, but execution plan will have trouble with it (seek-->scan in this example)

-- Returns 59,390 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID <> 3
AND PickedByPersonID IS NOT NULL; -- Does not include NULL.
-- Does not incur ANSI_NULLS risk, but has to deal with NULL separately.

-- Returns 14,205 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE ISNULL(PickedByPersonID, 3) = 3; -- This returns 3 and includes NULLs in the results.

-- Returns 14,205 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID = 3
OR PickedByPersonID IS NULL; -- This returns 3 and includes NULLs in the results.  Execution plan is complex, but you do get a seek.

-- Returns 70,013 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID IS DISTINCT FROM 3; -- Includes NULL.  No impact from ANSI_NULLS.  Can be effectively used by the query optimizer.
-- Scan for this example is expected as most of the index is not the value of 3.

-- Returns 3,582 rows
SELECT
	COUNT(*)
FROM Sales.Orders
WHERE PickedByPersonID IS NOT DISTINCT FROM 3; -- Only returns values of 3.
-- Considers NULL to be different from 3 and will not return NULL.  Performance = A+

/**************************************************************************************
*****************************APPROX_PERCENTILE_****************************************
***************************************************************************************/
-- Needs to sort the entire result set and perform complex calculations to arrive at the requested percentile (median).
SELECT DISTINCT
	SalespersonPersonID,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(Quantity * UnitPrice AS INT) ASC)
		OVER (PARTITION BY SalespersonPersonID) AS median_cont,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY CAST(Quantity * UnitPrice AS INT) ASC)
		OVER (PARTITION BY SalespersonPersonID) AS median_disc
FROM Sales.Orders
INNER JOIN Sales.OrderLines
ON Orders.OrderID = OrderLines.OrderID
ORDER BY SalespersonPersonID;
-- This may not reduce reads, but creates a simpler execution plan, reducing CPU/duration.
SELECT DISTINCT
	SalespersonPersonID,
	APPROX_PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(Quantity * UnitPrice AS INT) ASC) AS median,
	APPROX_PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY CAST(Quantity * UnitPrice AS INT) ASC) AS median
FROM Sales.Orders
INNER JOIN Sales.OrderLines
ON Orders.OrderID = OrderLines.OrderID
GROUP BY SalespersonPersonID
ORDER BY SalespersonPersonID;

/**************************************************************************************
*****************************DATETRUNC()***********************************************
***************************************************************************************/

SELECT DATETRUNC(DAY, SYSDATETIME()); -- Rounds to today's date at midnight.

SELECT DATETRUNC(MINUTE, SYSDATETIME()); -- Rounds to current datetime second

SELECT DATETRUNC(SECOND, SYSDATETIME()); -- Rounds to current datetime second

CREATE NONCLUSTERED INDEX IX_Orders_PickingCompletedWhen ON Sales.Orders (PickingCompletedWhen);
-- Note that functions in the WHERE clause may not perform well, but this syntax is valid.  Test performance to ensure it is adequate.
SELECT
	*
FROM Sales.Orders
WHERE DATETRUNC(HOUR, PickingCompletedWhen) = '1/1/2013 12:00:00'

-- Generally speaking, do this instead :-)
-- It can ensure that the index on PickingCompletedWhen can be used
SELECT
	*
FROM Sales.Orders
WHERE PickingCompletedWhen >= '1/1/2013 12:00:00' AND PickingCompletedWhen < '1/1/2013 13:00:00'

DROP INDEX IX_Orders_PickingCompletedWhen ON Sales.Orders;

-- With no filter, this is relatively efficient, even if it may not appear to be.  This performs better than the old fashioned way below.
SELECT
	DATETRUNC(HOUR, Orders.PickingCompletedWhen) AS PickedHour,
	SUM(Quantity * UnitPrice) AS TotalValue
FROM Sales.Orders
INNER JOIN Sales.OrderLines
ON OrderLines.OrderID = Orders.OrderID
GROUP BY DATETRUNC(HOUR, Orders.PickingCompletedWhen)
ORDER BY DATETRUNC(HOUR, Orders.PickingCompletedWhen);

-- This is how that USED to look!
SELECT
	CAST(Orders.PickingCompletedWhen AS DATE) AS PickedDate,
	DATEPART(HOUR, Orders.PickingCompletedWhen) AS PickedHour,
	SUM(Quantity * UnitPrice) AS TotalValue
FROM Sales.Orders
INNER JOIN Sales.OrderLines
ON OrderLines.OrderID = Orders.OrderID
GROUP BY CAST(Orders.PickingCompletedWhen AS DATE), DATEPART(HOUR, Orders.PickingCompletedWhen)
ORDER BY CAST(Orders.PickingCompletedWhen AS DATE), DATEPART(HOUR, Orders.PickingCompletedWhen)

/**************************************************************************************
*****************************Bit Manipulation******************************************
***************************************************************************************/

SELECT
	16 AS [16], -- 10000 (16)
	LEFT_SHIFT(16, 1) AS [Times 2], -- 100000 (32)
	LEFT_SHIFT(16, 2) AS [Times 4]; -- 1000000 (64)

SELECT
	16 AS [16], -- 10000 (16)
	RIGHT_SHIFT(16, 1) AS [Divided by 2], -- 1000 (8)
	RIGHT_SHIFT(16, 2) AS [Divided by 4], -- 1000 (8)
	RIGHT_SHIFT(16, 5) AS [Divided by 32]; -- Right shifting bits past the decimal point removes them, therefore this is now zero.

SELECT
	BIT_COUNT(16) AS [16], -- 10000 (16)
	BIT_COUNT(15) AS [15], -- 1111 (15)
	BIT_COUNT(1) AS [1], -- 1
	BIT_COUNT(0) AS [0]; -- 0

-- Beware negative numbers - they are not mathematically what you'd expect.  They are inverses, not negatives w/ respect to bit counting.
SELECT
	BIT_COUNT(-1), -- all bits -1 for an INT, therefore 32 (int is a 32 bit numeric)
	BIT_COUNT(-2), -- all bits -1, execpt for the second position, therefore 31
	BIT_COUNT(-7), -- all bits -1, execpt for the second position, therefore 31
	BIT_COUNT(CAST(-2 AS SMALLINT)), -- all bits -1, execpt for the second position, therefore 15 in SMALLINT (16 bit numeric)
	BIT_COUNT(CAST(-32768 AS SMALLINT)); -- all bits 0, execpt for the lead position, therefore 1 in SMALLINT (16 bit numeric)

-- If you intend to get a bit count for a negative number that is formatted like a positive number, use ABS:
SELECT
	BIT_COUNT(ABS(-1)), -- all bits -1 for an INT, therefore 32 (int is a 32 bit numeric)
	BIT_COUNT(ABS(-2)), -- all bits -1, execpt for the second position, therefore 31
	BIT_COUNT(ABS(-7)), -- all bits -1, execpt for the second position, therefore 31
	BIT_COUNT(ABS(CAST(-2 AS SMALLINT))), -- all bits -1, execpt for the second position, therefore 15 in SMALLINT (16 bit numeric)
	BIT_COUNT(ABS(CAST(-32768 AS SMALLINT))); -- all bits 0, execpt for the lead position, therefore 1 in SMALLINT (16 bit numeric)

-- Gets the 0/1 bit at the position indicated in a number (integer or hex)
-- Note that the 0th bit is the rightmost bit
-- 53 is 110101 (32 + 16 + 0 + 4 + 0 + 1 = 53)
SELECT
	GET_BIT(53, 5),
	GET_BIT(53, 4),
	GET_BIT(53, 3),
	GET_BIT(53, 2),
	GET_BIT(53, 1),
	GET_BIT(53, 0);
-- 0x35 is 110101 or 53 in hex (16 * 3 + 5 = 48 + 5 = 53)
SELECT
	GET_BIT(0x35, 5),
	GET_BIT(0x35, 4),
	GET_BIT(0x35, 3),
	GET_BIT(0x35, 2),
	GET_BIT(0x35, 1),
	GET_BIT(0x35, 0);
-- SET_BIT adjusts a given bit in a number to 1
-- In this example, the 0 in the #3 position (4th from the right) is changed to a 1:
-- 110101 --> 111101, adding 8 to the number:
SELECT
	GET_BIT(53, 5),
	SET_BIT(53, 5),
	SET_BIT(53, 5, 0), -- Sets the 32-bit to 0 from 1, subtracting 32 from the result.
	SET_BIT(53, 3), -- Sets the 8-bit to 1 from 0, adding 8 to the result.
	GET_BIT(SET_BIT(53, 3), 3);

/**************************************************************************************
*****************************Resumable Constraint Add/Alter****************************
***************************************************************************************/
CREATE TABLE dbo.SalesOrderLinesTest (
	OrderLineID int NOT NULL,
	OrderID int NOT NULL,
	StockItemID int NOT NULL,
	Description nvarchar(100) NOT NULL,
	PackageTypeID int NOT NULL,
	Quantity int NOT NULL,
	UnitPrice decimal(18, 2) NULL,
	TaxRate decimal(18, 3) NOT NULL,
	PickedQuantity int NOT NULL,
	PickingCompletedWhen datetime2(7) NULL,
	LastEditedBy int NOT NULL,
	LastEditedWhen datetime2(7) NOT NULL);

ALTER TABLE dbo.SalesOrderLinesTest
ADD CONSTRAINT PK_SalesOrderLinesTest
PRIMARY KEY CLUSTERED (OrderLineID)
WITH (ONLINE = ON, RESUMABLE = ON, MAX_DURATION = 15); -- 15 minute duration limit.

INSERT INTO dbo.SalesOrderLinesTest
SELECT * FROM sales.OrderLines;

-- Execute in another window first, to prevent this session from being killed.
ALTER INDEX PK_SalesOrderLinesTest
ON dbo.SalesOrderLinesTest
REBUILD
WITH (ONLINE = ON, RESUMABLE = ON, MAX_DURATION = 15);

-- Execute in another window as soon as the ALTER INDEX is running:
-- 1. Pause the rebuild
ALTER INDEX PK_SalesOrderLinesTest ON dbo.SalesOrderLinesTest PAUSE;
-- 2. Check its status
SELECT
	*
FROM sys.index_resumable_operations;

-- Note that the session kill errors are normal and not a bad thing here.

ALTER INDEX PK_SalesOrderLinesTest ON dbo.SalesOrderLinesTest RESUME;

SELECT
	*
FROM sys.index_resumable_operations;

DROP TABLE dbo.SalesOrderLinesTest;
/**************************************************************************************
*****************************Greatest() and Least()************************************
***************************************************************************************/

SELECT
	Orders.OrderID,
	OrderLines.OrderLineID,
	GREATEST(Orders.PickingCompletedWhen, Orders.LastEditedWhen, OrderLines.PickingCompletedWhen, OrderLines.LastEditedWhen) AS LastModifiedTime,
	LEAST(Orders.OrderDate, Orders.ExpectedDeliveryDate, Orders.PickingCompletedWhen, Orders.LastEditedWhen, OrderLines.PickingCompletedWhen, OrderLines.LastEditedWhen) AS FirstModifiedDate
FROM sales.Orders
INNER JOIN sales.OrderLines
ON OrderLines.OrderID = Orders.OrderID
WHERE Orders.SalespersonPersonID = 8;

/**************************************************************************************
*****************************STRING_SPLIT() w/ Ordinal*********************************
***************************************************************************************/
-- Brief review of STRING_SPLIT():
SELECT
	value
FROM STRING_SPLIT('Frog,17,Yellow Pig,Pikachu,Carrot Cake,Hot Pepper,Syntax Error', ',');

SELECT
	value
FROM STRING_SPLIT('Frog,17,Yellow Pig,Pikachu,Carrot Cake,Hot Pepper,Syntax Error', ' ');

-- Using the new ordinal parameter, which locates where in a list the item is.
-- The added parameter when set to 1 enables using the ordinal, otherwise it is unavailable.
SELECT
	value,
	ordinal
FROM STRING_SPLIT('Frog,17,Yellow Pig,Pikachu,Carrot Cake,Hot Pepper,Syntax Error', ',', 1)
ORDER BY ordinal;

-- Nope!
SELECT
	value,
	ordinal
FROM STRING_SPLIT('Frog,17,Yellow Pig,Pikachu,Carrot Cake,Hot Pepper,Syntax Error', ',', 0)
ORDER BY ordinal;

-- Nope!
SELECT
	value,
	ordinal
FROM STRING_SPLIT('Frog,17,Yellow Pig,Pikachu,Carrot Cake,Hot Pepper,Syntax Error', ',')
ORDER BY ordinal;

SELECT
	value,
	ordinal
FROM STRING_SPLIT('Frog,17,Yellow Pig,Pikachu,Carrot Cake,Hot Pepper,Syntax Error', ',', 1)
WHERE ordinal % 3 = 0
ORDER BY ordinal;

/**************************************************************************************
*****************************DATE_BUCKET()*********************************************
***************************************************************************************/
DECLARE @datetime2 DATETIME2(3) = '5/25/2023 12:35:12.196';
SELECT
	DATE_BUCKET(HOUR, 1, @datetime2) AS date_bucket_1_hour,
	DATE_BUCKET(HOUR, 2, @datetime2) AS date_bucket_2_hours,
	DATE_BUCKET(HOUR, 8, @datetime2) AS date_bucket_8_hours,
	DATE_BUCKET(MINUTE, 1, @datetime2) AS date_bucket_1_minute,
	DATE_BUCKET(DAY, 1, @datetime2) AS date_bucket_1_day;

SELECT
	Orders.OrderID,
	Orders.ExpectedDeliveryDate,
	DATE_BUCKET(WEEK, 1, Orders.ExpectedDeliveryDate) AS date_bucket_1_week,
	DATE_BUCKET(WEEK, 2, Orders.ExpectedDeliveryDate) AS date_bucket_2_weeks,
	DATE_BUCKET(MONTH, 1, Orders.ExpectedDeliveryDate) AS date_bucket_1_month
FROM Sales.Orders;

-- Shows how to use the @origin parameter, which allows the buckets' start point to be configured:
DECLARE @datetime2 DATETIME2(3) = '5/25/2023 12:35:12.196';
DECLARE @origin DATETIME2(3) = '1/1/2022 00:00:00'; -- Default
DECLARE @origin1 DATETIME2(3) = '1/1/2022 01:00:00'; -- Default plus 1 hour
DECLARE @origin2 DATETIME2(3) = '1/1/2022 02:00:00'; -- Default plus 2 hours
DECLARE @origin3 DATETIME2(3) = '1/1/2022 03:00:00'; -- Default plus 3 hours
SELECT
	DATE_BUCKET(HOUR, 8, @datetime2, @origin) AS date_bucket_8_hours_0,
	DATE_BUCKET(HOUR, 8, @datetime2, @origin1) AS date_bucket_8_hours_1,
	DATE_BUCKET(HOUR, 8, @datetime2, @origin2) AS date_bucket_8_hours_2,
	DATE_BUCKET(HOUR, 8, @datetime2, @origin3) AS date_bucket_8_hours_3;

/**************************************************************************************
*****************************GENERATE_SERIES()*****************************************
***************************************************************************************/
-- Great for generating numbers tables or on-the-fly PKs.
SELECT
	value
FROM GENERATE_SERIES(1, 17, 1); -- Start at 1, End at 17, increment by 1

SELECT
	value
FROM GENERATE_SERIES(1, 1100000000, 1000000); -- Start at 1, End at 1,100,000,000, increment by 1,000,000

SELECT
	value
FROM GENERATE_SERIES(100, 250, 10); -- Start at 100, End at 250, increment by 10

DECLARE @start DECIMAL(4,2) = 0.00;
DECLARE @stop DECIMAL(4,2) = 1.00;
DECLARE @increment DECIMAL(4,2) = 0.01;
SELECT
	value
FROM GENERATE_SERIES(@start, @stop, @increment); -- Start at 0, End at 1, increment by 0.01

/**************************************************************************************
*************************************WINDOW********************************************
***************************************************************************************/
-- The old way - reusing the same window over and over.
SELECT
	OrderID,
	Orders.CustomerID,
	Orders.SalespersonPersonID,
	ROW_NUMBER() OVER (PARTITION BY Orders.CustomerID ORDER BY SalespersonPersonID) AS row_num,
	COUNT(*) OVER (PARTITION BY Orders.CustomerID ORDER BY SalespersonPersonID) AS row_count_total,
	MAX(Orders.OrderDate) OVER (PARTITION BY Orders.CustomerID ORDER BY SalespersonPersonID) AS most_recent_order_date
FROM sales.Orders;
-- The new way - declaring the window and reusing it over and over.
SELECT
	OrderID,
	Orders.CustomerID,
	Orders.SalespersonPersonID,
	ROW_NUMBER() OVER CustomerWindow AS row_num,
	COUNT(*) OVER CustomerWindow AS row_count_total,
	MAX(Orders.OrderDate) OVER CustomerWindow AS most_recent_order_date
FROM sales.Orders
WINDOW CustomerWindow AS (PARTITION BY Orders.CustomerID ORDER BY SalespersonPersonID);
-- Note that the WINDOW can include all details, such as ROWS UNBOUNDED PRECEEDING, FOLLOWING, etc...
/**************************************************************************************
*************************************FIRST_VALUE() and LAST_VALUE()********************
***************************************************************************************/
-- Previously available syntax:
SELECT
	OrderID,
	Orders.CustomerID,
	Orders.SalespersonPersonID,
	ROW_NUMBER() OVER CustomerWindow AS row_num,
	COUNT(*) OVER CustomerWindow AS row_count_total,
	MAX(Orders.OrderDate) OVER CustomerWindow AS most_recent_order_date,
	FIRST_VALUE(Orders.OrderDate) OVER CustomerWindow AS first_order_date, -- First order date per CustomerID when ordered by SalespersonPersonID
	LAST_VALUE(Orders.OrderDate) OVER CustomerWindow AS last_order_date -- Last order date per CustomerID when ordered by SalespersonPersonID
FROM sales.Orders
WINDOW CustomerWindow AS (PARTITION BY Orders.CustomerID ORDER BY SalespersonPersonID);
-- Note that these are ordered by the window ORDER BY, not by the column being analyzed!

-- New syntax w/ SQL Server 2022+
SELECT
	OrderID,
	Orders.CustomerID,
	Orders.SalespersonPersonID,
	ROW_NUMBER() OVER CustomerWindow AS row_num,
	COUNT(*) OVER CustomerWindow AS row_count_total,
	MAX(Orders.OrderDate) OVER CustomerWindow AS most_recent_order_date,
	FIRST_VALUE(Orders.OrderDate) OVER CustomerWindow AS first_order_date, -- First order date per CustomerID when ordered by SalespersonPersonID
	LAST_VALUE(Orders.OrderDate) OVER CustomerWindow AS last_order_date, -- Last order date per CustomerID when ordered by SalespersonPersonID
	FIRST_VALUE(Orders.BackorderOrderID) OVER CustomerWindow AS BackorderOrderID,
	FIRST_VALUE(Orders.BackorderOrderID) RESPECT NULLS OVER CustomerWindow AS BackorderOrderID_First_Respect,
	FIRST_VALUE(Orders.BackorderOrderID) IGNORE NULLS OVER CustomerWindow AS BackorderOrderID_First_Ignore
FROM sales.Orders
WINDOW CustomerWindow AS (PARTITION BY Orders.CustomerID ORDER BY SalespersonPersonID);
-- Default is to RESPECT NULLS
/**************************************************************************************
*********************************TRIM, LTRIM, RTRIM************************************
***************************************************************************************/
-- Removes characters from the start or end (or both) of a string.  New syntax allows for far greater flexibility.
DECLARE @stringy_mcstringface VARCHAR(50);
SELECT @stringy_mcstringface = 'aaaEDWARDaaa';
SELECT
	TRIM('a' FROM @stringy_mcstringface),
	TRIM(LEADING 'a' FROM @stringy_mcstringface), -- Trims right until a non-trimmable character is encountered.
	TRIM(TRAILING 'a' FROM @stringy_mcstringface), -- Trims left until a non-trimmable character is encountered.
	TRIM(BOTH 'a' FROM @stringy_mcstringface), -- Trims right and left until a non-trimmable character is encountered.
	TRIM(LEADING 'adew' FROM @stringy_mcstringface), -- Trims right until a non-trimmable character is encountered.
	TRIM(TRAILING 'adew' FROM @stringy_mcstringface), -- Trims left until a non-trimmable character is encountered.
	TRIM(BOTH 'adew' FROM @stringy_mcstringface); -- Trims right and left until a non-trimmable character is encountered.
