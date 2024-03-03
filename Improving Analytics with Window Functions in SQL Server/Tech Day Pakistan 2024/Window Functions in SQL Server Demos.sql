USE AdventureWorks2022;
GO
/*************************************************************************************************
*************************** Demo: Window Functions ***********************************************
*************************************************************************************************/

SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderHeader.SubTotal,
	-- Total item count per SalesOrderID. Note it is not a running total.
	COUNT(*) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS ItemCount,
	-- Lowest unit price per SalesOrderID
	MIN(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS MinUnitPrice,
	-- Highest unit price per SalesOrderID
	MAX(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS MaxUnitPrice,
	-- Row numbers, ordering by SalesOrderID. Note there's no PARTITION BY
	ROW_NUMBER() OVER (ORDER BY SalesOrderDetail.SalesOrderID ASC) AS RowNum,
	-- Total of price of the past 5 orders
	SUM(UnitPrice) OVER (ORDER BY SalesOrderHeader.OrderDate ASC
		ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS UnitPriceTotalPast5Orders,
	-- Total of price of the past 2 and next 2 orders
	SUM(UnitPrice) OVER (ORDER BY SalesOrderHeader.OrderDate ASC
		ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS UnitPriceTotalSurrounding2Orders
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID;
-- No WHERE clause, so we are evaluating the entire data set.

/*************************************************************************************************
*************************** Demo: Running Totals *************************************************
*************************************************************************************************/

SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderHeader.SubTotal,
	-- Total item count per SalesOrderID. Note it is not a running total.
	COUNT(*) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS ItemCount,
	COUNT(*) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ItemCountRunningTotal,
	-- Total price per order
	SUM(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	-- This is the default window
	ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS TotalUnitPrice,
	SUM(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS UnitPriceRunningTotal
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.SalesOrderDetailID;

/*************************************************************************************************
*************************** Demo: Median *********************************************************
*************************************************************************************************/

SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderHeader.SubTotal,
	SalesOrderDetail.UnitPrice,
	ROW_NUMBER() OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice ASC) AS RowNum,
	-- Median of unit prices in the window's data.
	-- Note that window frame is ALWAYS unbounded and cannot be provided.
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS MedianUnitPrice_Disc,
	-- Median of unit prices that may or may not be in the window's data.
	-- Note that window frame is ALWAYS unbounded and cannot be provided.
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS MedianUnitPrice_Cont,
	-- Adjusting the percentage will determine where the value is calculated from:
	PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS UnitPrice_Disc_25,
	PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS UnitPrice_Disc_75,
	PERCENTILE_DISC(0.00) WITHIN GROUP (ORDER BY UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS UnitPrice_Disc_0,
	PERCENTILE_DISC(1.00) WITHIN GROUP (ORDER BY UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID) AS UnitPrice_Disc_100,
	FIRST_VALUE(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY UnitPrice) AS FirstValue,
	-- By not specifying a window, this defaults to ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	LAST_VALUE(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY UnitPrice) AS LastValue,
	-- Adding an explicit window ensures the last value really is the last value in the window
	LAST_VALUE(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY UnitPrice
	ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastValueForReal
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;

/*************************************************************************************************
*************************** Demo: Window Clause **************************************************
*************************************************************************************************/

-- Without WINDOW clause
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderHeader.SubTotal,
	COUNT(*) OVER (PARTITION BY SalesOrderDetail.SalesOrderID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ItemCountRunningTotal,
	SUM(UnitPrice) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS UnitPriceRunningTotal,
	MAX(SalesOrderDetail.ModifiedDate) OVER (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS MostRecentModifiedDateThusFar
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID;

-- With WINDOW clause
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderHeader.SubTotal,
	COUNT(*) OVER RunningTotal AS ItemCountRunningTotal,
	SUM(UnitPrice) OVER RunningTotal AS UnitPriceRunningTotal,
	MAX(SalesOrderDetail.ModifiedDate) OVER RunningTotal AS MostRecentModifiedDateThusFar
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW RunningTotal AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.SalesOrderDetailID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
-- These are logically identical

/*************************************************************************************************
*************************** Demo: Ranking ********************************************************
*************************************************************************************************/

-- Ranking functions do not allow a window frame to be provided. They rank an entire data set. Adding one results in an error.
-- Note that the ranking order and ORDER BY clause are different. This is intentionally confusing :-)
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	RANK() OVER EntireWindow AS ItemRankByUnitPrice, -- Ranking where ranks will be skipped when ties occur.
	DENSE_RANK() OVER EntireWindow AS ItemDenseRankByUnitPrice, -- Ranking where ranks will not be skipped when ties occur.
	NTILE(5) OVER EntireWindow AS ItemRankByQuintile, -- Breaks the data set into quintiles and assigns them to percentiles.
	PERCENT_RANK() OVER EntireWindow AS ItemPercentRank, -- Provides a 0-1 percent rank for each value.
	CUME_DIST() OVER EntireWindow AS ItemCumulativeDistribution -- Calculates relative location of a value within the window.
	-- CUME_DIST is defined as: # of rows with values <= to current value divided by total evaluated rows.
	-- CUME_DIST is always > 0 and <= 1
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.SalesOrderDetailID;
-- Use the WINDOW name to reduce code size.

-- The ORDER BY is aligned with the ranking order.
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	RANK() OVER EntireWindow AS ItemRankByUnitPrice, -- Ranking where ranks will be skipped when ties occur.
	DENSE_RANK() OVER EntireWindow AS ItemDenseRankByUnitPrice, -- Ranking where ranks will not be skipped when ties occur.
	NTILE(5) OVER EntireWindow AS ItemRankByQuintile, -- Breaks the data set into quintiles and assigns them to percentiles.
	PERCENT_RANK() OVER EntireWindow AS ItemPercentRank, -- Provides a 0-1 percent rank for each value.
	CUME_DIST() OVER EntireWindow AS ItemCumulativeDistribution -- Calculates relative location of a value within the window.
	-- CUME_DIST is defined as: # of rows with values <= to current value divided by total evaluated rows.
	-- CUME_DIST is always > 0 and <= 1
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;

/*************************************************************************************************
*************************** Demo: Retrieving Specific Values from a Window ***********************
*************************************************************************************************/

SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	FIRST_VALUE(UnitPrice) OVER EntireWindow AS FirstUnitPrice,
	LAST_VALUE(UnitPrice) OVER EntireWindow AS LastUnitPrice,
	FIRST_VALUE(SalesOrderDetailID) OVER EntireWindow AS FirstSalesOrderDetailID,
	LAST_VALUE(SalesOrderDetailID) OVER EntireWindow AS LastSalesOrderDetailID
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;

-- Note that LEAD and LAG cannot have a window frame assigned and will throw an error if you try.
-- LAG for first item in a window frame is NULL. No prior row --> no value.
-- LEAD for last item in a window frame is NULL. No next row --> no value.
-- LEAD/LAG have 2 optional parameters: OFFSET and DEFAULT
-- Examples below offset by 1 (the default)
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	LAG(UnitPrice, 1) OVER EntireWindow AS PriorUnitPrice,
	LEAD(UnitPrice, 1) OVER EntireWindow AS NextUnitPrice,
	LAG(SalesOrderDetailID, 1) OVER EntireWindow AS PriorSalesOrderDetailID,
	LEAD(SalesOrderDetailID, 1) OVER EntireWindow AS NextSalesOrderDetailID
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;

-- Examples below offset by 2
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	LAG(UnitPrice, 2) OVER EntireWindow AS PriorUnitPriceOffset2,
	LEAD(UnitPrice, 2) OVER EntireWindow AS NextUnitPriceOffset2,
	LAG(SalesOrderDetailID, 2) OVER EntireWindow AS PriorSalesOrderDetailIDOffset2,
	LEAD(SalesOrderDetailID, 2) OVER EntireWindow AS NextSalesOrderDetailIDOffset2
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;

-- Add defaults for LEAD/LAG to replace NULL (you may not want to do this, depending on your analytic needs)
-- Default values must be a non-negative value, otherwise an error is thrown.
SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	LAG(UnitPrice, 1, 0) OVER EntireWindow AS PriorUnitPrice,
	LEAD(UnitPrice, 1, 0) OVER EntireWindow AS NextUnitPrice,
	LAG(SalesOrderDetailID, 1, 0) OVER EntireWindow AS PriorSalesOrderDetailID,
	LEAD(SalesOrderDetailID, 1, 0) OVER EntireWindow AS NextSalesOrderDetailID
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;

/*************************************************************************************************
*************************** Demo: Retrieving Specific Values from a Window ***********************
*************************************************************************************************/

SELECT
	SalesOrderDetail.SalesOrderID,
	SalesOrderDetail.SalesOrderDetailID,
	SalesOrderHeader.OrderDate,
	SalesOrderHeader.PurchaseOrderNumber,
	SalesOrderDetail.UnitPrice,
	STDEV(UnitPrice) OVER EntireWindow AS StandardDeviation,
	STDEVP(UnitPrice) OVER EntireWindow AS StandardDeviationPopulation,
	VAR(UnitPrice) OVER EntireWindow AS Variance,
	VARP(UnitPrice) OVER EntireWindow AS VariancePopulation
FROM Sales.SalesOrderHeader
INNER JOIN Sales.SalesOrderDetail
ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
WINDOW EntireWindow AS (PARTITION BY SalesOrderDetail.SalesOrderID ORDER BY SalesOrderDetail.UnitPrice
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
ORDER BY SalesOrderDetail.SalesOrderID, SalesOrderDetail.UnitPrice;
