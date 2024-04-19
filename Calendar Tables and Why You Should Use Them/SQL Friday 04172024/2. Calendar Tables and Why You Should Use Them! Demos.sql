USE AdventureWorks2022;
GO
/*	Calendar Tables and Why You Should Use Them!
	
	Lightning talk content.  Zoom!
*/

-- Example of how ugly queries get uglier with lots of date math in filters, aggregates, and selection criteria.
SELECT
	*
FROM Sales.SalesOrderDetail
WHERE DATEPART(DAY, CAST(ModifiedDate AS DATE)) = 3
AND DATEADD(MONTH, 3, ModifiedDate) <= CAST(GETUTCDATE() AS DATE)
AND DATEDIFF(DAY, ModifiedDate, DATEADD(QUARTER, 1, GETUTCDATE())) < 2750;

/*********************************************************************************
					Simplifying Code
*********************************************************************************/
-- Find all orders from Q4 2013 that occurred on Thursday/Friday and not on Thanksgiving
SELECT
	*
FROM AdventureWorks2017.Sales.SalesOrderHeader
WHERE SalesOrderHeader.OrderDate >= '10/1/2013'
AND SalesOrderHeader.OrderDate < '1/1/2014'
AND DATEPART(DW, SalesOrderHeader.OrderDate) IN (5, 6)
AND NOT (DATEPART(DW, SalesOrderHeader.OrderDate) = 5 AND DATEPART(MONTH, SalesOrderHeader.OrderDate) = 11 AND DATEPART(DAY, SalesOrderHeader.OrderDate) BETWEEN 22 AND 28)
ORDER BY SalesOrderHeader.OrderDate ASC;

-- That's quite ugly.  Let's use a calendar table to simplify it!
SELECT
	*
FROM AdventureWorks2017.Sales.SalesOrderHeader
INNER JOIN dbo.Dim_Date
ON SalesOrderHeader.OrderDate = Dim_Date.Calendar_Date
WHERE Dim_Date.Calendar_Year = 2013
AND Dim_Date.Calendar_Quarter = 4
AND Dim_Date.Day_Name IN ('Thursday', 'Friday')
AND Dim_Date.Holiday_Name <> 'Thanksgiving';
GO

/*********************************************************************************
					Generate Date Ranges Quickly Without Iteration or Scary Code
*********************************************************************************/
-- Let's say we want to report on a set of sales orders and want counts for every day in a year, whether data exists or not?
WITH CTE_ORDERS AS (
	SELECT
		SalesOrderHeader.OrderDate,
		COUNT(*) AS OrderCount
	FROM AdventureWorks2017.Sales.SalesOrderHeader
	WHERE SalesOrderHeader.SalesPersonID = 279
	AND SalesOrderHeader.OrderDate >= '1/1/2013'
	AND SalesOrderHeader.OrderDate < '1/1/2014'
	GROUP BY SalesOrderHeader.OrderDate)
SELECT
	Dim_Date.Calendar_Date,
	ISNULL(CTE_ORDERS.OrderCount, 0) AS OrderCount
FROM dbo.Dim_Date
LEFT JOIN CTE_ORDERS
ON CTE_ORDERS.OrderDate = Dim_Date.Calendar_Date
WHERE Dim_Date.Calendar_Year = 2013
ORDER BY Dim_Date.Calendar_Date;

-- Similarly, subsets of the calendar table can be pulled for reporting needs:
-- One year of data
SELECT
	Calendar_Date
FROM dbo.Dim_Date
WHERE Calendar_Date >= '1/1/2024'
AND Calendar_Date < '1/1/2025'
ORDER BY Calendar_Date ASC;

-- All week days
SELECT
	Calendar_Date,
	Day_Name
FROM dbo.Dim_Date
WHERE Calendar_Date >= '1/1/2024'
AND Calendar_Date < '1/1/2025'
AND Is_Weekday = 1
ORDER BY Calendar_Date ASC;
/*********************************************************************************
					Correlate data to holidays, weekdays, or business days
*********************************************************************************/
SELECT -- Find all sales in 2014 that did not occur on business days (not weekdays, include holidays)
	*
FROM AdventureWorks2017.Sales.SalesOrderHeader
INNER JOIN dbo.Dim_Date
ON SalesOrderHeader.OrderDate = Dim_Date.Calendar_Date
WHERE Dim_Date.Calendar_Year = 2014
AND Dim_Date.Is_Business_Day = 0;

SELECT -- Groups data by year & quarter.  No date math needed!
	Dim_Date.Calendar_Year,
	Dim_Date.Calendar_Quarter,
	COUNT(*) AS Order_Count
FROM AdventureWorks2017.Sales.SalesOrderHeader
INNER JOIN dbo.Dim_Date
ON SalesOrderHeader.OrderDate = Dim_Date.Calendar_Date
GROUP BY Dim_Date.Calendar_Year, Dim_Date.Calendar_Quarter
ORDER BY Dim_Date.Calendar_Year ASC, Dim_Date.Calendar_Quarter ASC;
GO

USE BaseballStats;
GO

SELECT -- Find all baseball games that have ever occurred on Easter
	*
FROM BaseballStats.dbo.GameLog
INNER JOIN dbo.Dim_Date
ON Dim_Date.Calendar_Date = GameLog.GameDate
WHERE Dim_Date.Holiday_Name = 'Easter'
ORDER BY GameDate ASC;

SELECT -- Find all baseball games in 2018 that occurred on weekdays
	*
FROM BaseballStats.dbo.GameLog
INNER JOIN dbo.Dim_Date
ON Dim_Date.Calendar_Date = GameLog.GameDate
WHERE Dim_Date.Calendar_Year = 2018
AND Dim_Date.Is_Weekday = 1;

SELECT -- Find total runs scored in games that occur on Wednesdays at night, but not on holidays
	SUM(VisitingScore + HomeScore) AS TotalRuns
FROM BaseballStats.dbo.GameLog
INNER JOIN dbo.Dim_Date
ON Dim_Date.Calendar_Date = GameLog.GameDate
WHERE Dim_Date.Day_Name = 'Wednesday'
AND GameLog.DayorNight = 'N'
AND Dim_Date.Is_Holiday = 0;

SELECT -- Find total runs scored in games that occur on Wednesdays at night on holidays
	SUM(VisitingScore + HomeScore) AS TotalRuns
FROM BaseballStats.dbo.GameLog
INNER JOIN dbo.Dim_Date
ON Dim_Date.Calendar_Date = GameLog.GameDate
WHERE Dim_Date.Day_Name = 'Wednesday'
AND GameLog.DayorNight = 'N'
AND Dim_Date.Is_Holiday = 1;

SELECT -- Find total runs scored in games that occur on Wednesdays at night on holidays
	Dim_Date.Holiday_Name,
	SUM(VisitingScore + HomeScore) AS TotalRuns
FROM BaseballStats.dbo.GameLog
INNER JOIN dbo.Dim_Date
ON Dim_Date.Calendar_Date = GameLog.GameDate
WHERE Dim_Date.Day_Name = 'Wednesday'
AND GameLog.DayorNight = 'N'
AND Dim_Date.Is_Holiday = 1
GROUP BY Dim_Date.Holiday_Name;

SELECT -- Find total runs scored in games that occur on Wednesdays at night on holidays
	Dim_Date.Holiday_Name,
	SUM(VisitingScore + HomeScore) AS TotalRuns
FROM BaseballStats.dbo.GameLog
INNER JOIN dbo.Dim_Date
ON Dim_Date.Calendar_Date = GameLog.GameDate
WHERE Dim_Date.Is_Holiday = 1
GROUP BY Dim_Date.Holiday_Name
ORDER BY SUM(VisitingScore + HomeScore) DESC;