USE WideWorldImporters;
SET STATISTICS IO ON;
GO
-- Get the most recent time per row from a set of 4 columns.
SELECT
	OrderID,
	OrderDate,
	ExpectedDeliveryDate,
	PickingCompletedWhen, -- NULLable
	LastEditedWhen,
	CASE
		WHEN OrderDate >= ExpectedDeliveryDate 
		AND OrderDate >= ISNULL(PickingCompletedWhen, '1/1/1900')
		AND OrderDate >= LastEditedWhen
			THEN OrderDate
		WHEN ExpectedDeliveryDate >= ISNULL(PickingCompletedWhen, '1/1/1900') 
		AND ExpectedDeliveryDate >= LastEditedWhen
			THEN ExpectedDeliveryDate
		WHEN ISNULL(PickingCompletedWhen, '1/1/1900') >= LastEditedWhen
			THEN PickingCompletedWhen
		ELSE LastEditedWhen
	END AS LastModifiedTime
FROM Sales.Orders;

DECLARE @OrderID INT = 17;
SELECT MAX(DateColumn)
FROM (	SELECT OrderDate AS DateColumn FROM Sales.Orders WHERE Orders.OrderID = @OrderID
		UNION ALL
		SELECT ExpectedDeliveryDate FROM Sales.Orders WHERE Orders.OrderID = @OrderID
		UNION ALL
		SELECT ISNULL(PickingCompletedWhen, '1/1/1900') FROM Sales.Orders WHERE Orders.OrderID = @OrderID
		UNION ALL
		SELECT LastEditedWhen FROM Sales.Orders WHERE Orders.OrderID = @OrderID
) AS DATEDATA;

/* For those of us who like challenging their sanity, you can use UNPIVOT to get
	the same results for double the effort :-)	*/
WITH CTE_ORDERS (OrderID, OrderDate, ExpectedDeliveryDate, PickingCompletedWhen, LastEditedWhen)
AS (	SELECT
			OrderID,
			CAST(OrderDate AS DATETIME2(7)) AS OrderDate,
			ISNULL(CAST(ExpectedDeliveryDate AS DATETIME2(7)), '1/1/1900') AS ExpectedDeliveryDate,
			PickingCompletedWhen,
			LastEditedWhen
		FROM Sales.Orders)
SELECT
	CTE_ORDERS.OrderID,
	OrderDate AS OrderDate,
	ExpectedDeliveryDate AS ExpectedDeliveryDate,
	PickingCompletedWhen,
	LastEditedWhen,
	LASTMODIFIED.LastModifiedTime
FROM CTE_ORDERS
INNER JOIN
(	SELECT
        OrderID,
		MAX(DateData) AS LastModifiedTime
    FROM CTE_ORDERS 
    UNPIVOT (DateData for DateColumns IN
		(OrderDate, ExpectedDeliveryDate, PickingCompletedWhen, LastEditedWhen)) AS UNPIVOTDATA
    GROUP BY OrderID
) AS LASTMODIFIED
on CTE_ORDERS.OrderID = LastModified.OrderID;

SELECT
	OrderID,
	OrderDate,
	ExpectedDeliveryDate,
	PickingCompletedWhen,
	LastEditedWhen,
	GREATEST(OrderDate, ExpectedDeliveryDate, PickingCompletedWhen, LastEditedWhen) AS LastModifiedTime
FROM Sales.Orders;

SELECT
	OrderID,
	OrderDate,
	ExpectedDeliveryDate,
	PickingCompletedWhen,
	LastEditedWhen,
	LEAST(OrderDate, ExpectedDeliveryDate, PickingCompletedWhen, LastEditedWhen) AS FirstModifiedTime
FROM Sales.Orders;

SELECT
	OrderDate,
	MAX(GREATEST(OrderDate, ExpectedDeliveryDate, PickingCompletedWhen, LastEditedWhen)) AS GlobalLastModifiedTime
FROM Sales.Orders
GROUP BY OrderDate
ORDER BY OrderDate;

SELECT
	OrderDate,
	MIN(LEAST(OrderDate, ExpectedDeliveryDate, PickingCompletedWhen, LastEditedWhen)) AS GlobalFirstModifiedTime
FROM Sales.Orders
GROUP BY OrderDate
ORDER BY OrderDate;

