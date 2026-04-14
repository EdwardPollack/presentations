USE WideWorldImportersDW;
SET STATISTICS IO ON;
GO

/******************************************************************************************
*********************************DICTIONARY ENCODING***************************************
*******************************************************************************************/
-- Dictionary Metadata is stored in sys.column_store_dictionaries.
SELECT
	*
FROM sys.column_store_dictionaries;

-- This provides some detail on each dictionary (filtered to a table)
SELECT
	partitions.partition_number,
	objects.name AS table_name,
	columns.name AS column_name,
	types.name AS data_type,
	columns.max_length AS max_length_bytes,
	columns.precision,
	columns.scale,
	CASE
		WHEN column_store_dictionaries.dictionary_id = 0 THEN 'Global Dictionary'
		ELSE 'Local Dictionary'
	END AS dictionary_scope,
	CASE WHEN column_store_dictionaries.type = 1 THEN 'Hash dictionary containing INT values'
		 WHEN column_store_dictionaries.type = 2 THEN 'Not used' -- Included for completeness/future
		 WHEN column_store_dictionaries.type = 3 THEN 'Hash dictionary containing STRING values'
		 WHEN column_store_dictionaries.type = 4 THEN 'Hash dictionary containing FLOAT values'
	END AS dictionary_type,
	column_store_dictionaries.entry_count,
	column_store_dictionaries.on_disk_size AS on_disk_size_in_bytes
FROM sys.column_store_dictionaries
INNER JOIN sys.partitions
ON column_store_dictionaries.hobt_id = partitions.hobt_id
INNER JOIN sys.objects
ON objects.object_id = partitions.object_id
INNER JOIN sys.columns
ON columns.column_id = column_store_dictionaries.column_id
AND columns.object_id = objects.object_id
INNER JOIN sys.types
ON types.user_type_id = columns.user_type_id
WHERE objects.name = 'Order'
ORDER BY objects.name, columns.name, partitions.partition_number;

-- This provides detail about a column and any dictionaries used by it
SELECT
	objects.name AS table_name,
	columns.name AS column_name,
	column_store_segments.segment_id,
	partitions.partition_number,
	types.name AS data_type,
	columns.max_length AS max_length_bytes,
	columns.precision,
	columns.scale,
	CASE
		WHEN PRIMARY_DICTIONARY.dictionary_id IS NOT NULL THEN 1
		ELSE 0
	END AS does_global_dictionary_exist,
	PRIMARY_DICTIONARY.entry_count AS global_dictionary_entry_count,
	PRIMARY_DICTIONARY.on_disk_size AS global_dictionary_on_disk_size_in_bytes,
	CASE
		WHEN SECONDARY_DICTIONARY.dictionary_id IS NOT NULL THEN 1
		ELSE 0
	END AS does_local_dictionary_exist,
	SECONDARY_DICTIONARY.entry_count AS local_dictionary_entry_count,
	SECONDARY_DICTIONARY.on_disk_size AS local_dictionary_on_disk_size_in_bytes
FROM sys.column_store_segments
INNER JOIN sys.partitions
ON column_store_segments.hobt_id = partitions.hobt_id
INNER JOIN sys.objects
ON objects.object_id = partitions.object_id
INNER JOIN sys.columns
ON columns.object_id = objects.object_id
AND column_store_segments.column_id = columns.column_id
INNER JOIN sys.types
ON types.user_type_id = columns.user_type_id
LEFT JOIN sys.column_store_dictionaries PRIMARY_DICTIONARY
ON column_store_segments.primary_dictionary_id = PRIMARY_DICTIONARY.dictionary_id
AND column_store_segments.primary_dictionary_id <> -1
AND PRIMARY_DICTIONARY.column_id = columns.column_id
AND PRIMARY_DICTIONARY.hobt_id = partitions.hobt_id
LEFT JOIN sys.column_store_dictionaries SECONDARY_DICTIONARY
ON column_store_segments.secondary_dictionary_id = SECONDARY_DICTIONARY.dictionary_id
AND column_store_segments.secondary_dictionary_id <> -1
AND SECONDARY_DICTIONARY.column_id = columns.column_id
AND SECONDARY_DICTIONARY.hobt_id = partitions.hobt_id
WHERE objects.name = 'Sale'
ORDER BY objects.name, columns.name;

/* How does normalizing a wide column help? */
-- New version of Sale with a normalized Description column
CREATE TABLE Dimension.Sale_Description
(	Description_Key SMALLINT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	[Description] NVARCHAR(100) NOT NULL);

CREATE TABLE Fact.Sale_Normalized
(	[Sale Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Bill To Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Invoice Date Key] [date] NOT NULL,
	[Delivery Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[WWI Invoice ID] [int] NOT NULL,
	Description_Key SMALLINT NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Profit] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Total Dry Items] [int] NOT NULL,
	[Total Chiller Items] [int] NOT NULL,
	[Lineage Key] [int] NOT NULL);

INSERT INTO Dimension.Sale_Description
	([Description])
SELECT DISTINCT
	Sale.[Description]
FROM fact.Sale;

SELECT * FROM Dimension.Sale_Description;

INSERT INTO Fact.Sale_Normalized
	([Sale Key], [City Key], [Customer Key], [Bill To Customer Key], [Stock Item Key], [Invoice Date Key], [Delivery Date Key],
	 [Salesperson Key], [WWI Invoice ID], Description_Key, Package, Quantity, [Unit Price], [Tax Rate],
	 [Total Excluding Tax], [Tax Amount], Profit, [Total Including Tax], [Total Dry Items],
	 [Total Chiller Items], [Lineage Key])
SELECT
	Sale.[Sale Key], Sale.[City Key], Sale.[Customer Key], Sale.[Bill To Customer Key], Sale.[Stock Item Key], Sale.[Invoice Date Key], Sale.[Delivery Date Key],
	Sale.[Salesperson Key], Sale.[WWI Invoice ID], Sale_Description.Description_Key, Sale.Package, Sale.Quantity, Sale.[Unit Price], Sale.[Tax Rate],
	Sale.[Total Excluding Tax], Sale.[Tax Amount], Sale.Profit, Sale.[Total Including Tax], Sale.[Total Dry Items],
	Sale.[Total Chiller Items], Sale.[Lineage Key]
FROM fact.Sale
INNER JOIN Dimension.Sale_Description
ON Sale_Description.[Description] = Sale.[Description];

-- Create a columnstore index on the table.
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Sale_Normalized ON fact.Sale_Normalized;
GO

-- Compare table sizes between normalized and denormalized table
CREATE TABLE #storage_data
(	table_name VARCHAR(MAX),
	rows_used BIGINT,
	reserved VARCHAR(50),
	data VARCHAR(50),
	index_size VARCHAR(50),
	unused VARCHAR(50));

INSERT INTO #storage_data
	(table_name, rows_used, reserved, data, index_size, unused)
EXEC sp_MSforeachtable "EXEC sp_spaceused '?'";

UPDATE #storage_data
	SET reserved = LEFT(reserved, LEN(reserved) - 3),
		data = LEFT(data, LEN(data) - 3),
		index_size = LEFT(index_size, LEN(index_size) - 3),
		unused = LEFT(unused, LEN(unused) - 3);

SELECT
	table_name,
	rows_used,
	CAST(CAST(reserved AS DECIMAL(18,2)) / 1024.00 AS DECIMAL(18,2)) AS data_space_reserved_mb,
	CAST(CAST(data AS DECIMAL(18,2)) / 1024.00 AS DECIMAL(18,2)) AS data_space_used_mb,
	index_size / 1024 AS index_size_mb,
	unused AS free_space_kb,
	CAST(CAST(data AS DECIMAL(24,2)) / CAST(rows_used AS DECIMAL(24,2)) AS DECIMAL(24,4)) AS kb_per_row
FROM #storage_data
WHERE rows_used > 0
AND table_name IS NOT NULL
AND table_name IN ('Sale', 'Sale_Normalized', 'Sale_Description')
ORDER BY CAST(reserved AS INT) DESC;

DROP TABLE #storage_data;

-- This provides some detail on each dictionary (filtered to a table)
SELECT
	partitions.partition_number,
	objects.[name] AS table_name,
	columns.[name] AS column_name,
	types.name AS data_type,
	columns.max_length AS max_length_bytes,
	columns.precision,
	columns.scale,
	CASE
		WHEN column_store_dictionaries.dictionary_id = 0 THEN 'Global Dictionary'
		ELSE 'Local Dictionary'
	END AS dictionary_scope,
	CASE WHEN column_store_dictionaries.type = 1 THEN 'Hash dictionary containing int values'
		 WHEN column_store_dictionaries.type = 2 THEN 'Not used' -- Included for completeness
		 WHEN column_store_dictionaries.type = 3 THEN 'Hash dictionary containing string values'
		 WHEN column_store_dictionaries.type = 4 THEN 'Hash dictionary containing float values'
	END AS dictionary_type,
	column_store_dictionaries.entry_count,
	column_store_dictionaries.on_disk_size AS on_disk_size_in_bytes
FROM sys.column_store_dictionaries
INNER JOIN sys.partitions
ON column_store_dictionaries.hobt_id = partitions.hobt_id
INNER JOIN sys.objects
ON objects.object_id = partitions.object_id
INNER JOIN sys.columns
ON columns.column_id = column_store_dictionaries.column_id
AND columns.object_id = objects.object_id
INNER JOIN sys.types
ON types.user_type_id = columns.user_type_id
WHERE objects.[name] IN ('Sale', 'Sale_Normalized')
AND columns.[name] = 'Description'
ORDER BY objects.[name], columns.[name], partitions.partition_number;
GO

/*	NOTE THAT TESTING SHOULD ALWAYS OCCUR BEFORE MAKING SCHEMA CHANGES!
	NORMALIZING COLUMNS WITHOUT A GOOD REASON WILL NOT ALWAYS HELP AND CAN
	HARM PERFORMANCE/DECREASE STORAGE EFFICIENCY!	*/

-- Cleanup!
DROP TABLE Dimension.Sale_Description
DROP TABLE Fact.Sale_Normalized
GO
/******************************************************************************************
*********************************VALUE ENCODING********************************************
*******************************************************************************************/

-- This provides some detail on value-encoded columns
SELECT
	partitions.partition_number,
	objects.name AS table_name,
	columns.name AS column_name,
	types.name AS data_type,
	columns.max_length AS max_length_bytes,
	columns.precision,
	columns.scale,
	CASE column_store_segments.encoding_type
		WHEN 1 THEN 'VALUE_BASED' -- Non-string/binary, no dictionary
		WHEN 2 THEN 'VALUE_HASH_BASED' -- Non-string/binary, uses a dictionary
		WHEN 3 THEN 'STRING_HASH_BASED' -- String/binary, uses a dictionary
		WHEN 4 THEN 'STORE_BY_VALUE_BASED' -- Non-string/binary, no dictionary.  Similar to #1, seen less often, minor internals differences.
		WHEN 5 THEN 'STRING_STORE_BY_VALUE_BASED' -- String/binary, no dictionary
	END AS encoding_type,
	column_store_segments.base_id,
	column_store_segments.magnitude
FROM sys.column_store_segments
INNER JOIN sys.partitions
ON column_store_segments.hobt_id = partitions.hobt_id
INNER JOIN sys.objects
ON objects.object_id = partitions.object_id
INNER JOIN sys.columns
ON columns.column_id = column_store_segments.column_id
AND columns.object_id = objects.object_id
INNER JOIN sys.types
ON types.user_type_id = columns.user_type_id
WHERE (base_id <> -1 OR magnitude <> -1) -- -1 is a placeholder when value encoding is not used (any encoding type except 1)
ORDER BY objects.name, columns.name, partitions.partition_number;

-- Note ID columns and how their base is adjusted within each segment to account for different incrementing ID values.
SELECT TOP 100
	[Last Cost Price]
FROM Fact.[Stock Holding]
ORDER BY [Last Cost Price];

-- This provides some detail on value-encoded columns
SELECT
	partitions.partition_number,
	objects.name AS table_name,
	columns.name AS column_name,
	types.name AS data_type,
	columns.max_length AS max_length_bytes,
	columns.precision,
	columns.scale,
	CASE column_store_segments.encoding_type
		WHEN 1 THEN 'VALUE_BASED' -- Non-string/binary, no dictionary
		WHEN 2 THEN 'VALUE_HASH_BASED' -- Non-string/binary, uses a dictionary
		WHEN 3 THEN 'STRING_HASH_BASED' -- String/binary, uses a dictionary
		WHEN 4 THEN 'STORE_BY_VALUE_BASED' -- Non-string/binary, no dictionary.  Similar to #1, seen less often, minor internals differences.
		WHEN 5 THEN 'STRING_STORE_BY_VALUE_BASED' -- String/binary, no dictionary
	END AS encoding_type,
	column_store_segments.base_id,
	column_store_segments.magnitude
FROM sys.column_store_segments
INNER JOIN sys.partitions
ON column_store_segments.hobt_id = partitions.hobt_id
INNER JOIN sys.objects
ON objects.object_id = partitions.object_id
INNER JOIN sys.columns
ON columns.column_id = column_store_segments.column_id
AND columns.object_id = objects.object_id
INNER JOIN sys.types
ON types.user_type_id = columns.user_type_id
WHERE (base_id <> -1 OR magnitude <> -1) -- -1 is a placeholder when value encoding is not used (any encoding type except 1)
AND objects.[name] = 'Stock Holding'
AND columns.[name] = 'Last Cost Price';

/******************************************************************************************
*********************************Vertipaq Optimization*************************************
*******************************************************************************************/

SELECT DISTINCT
	objects.name AS table_name,
	indexes.name AS index_name,
	partitions.partition_number,
	dm_db_column_store_row_group_physical_stats.row_group_id,
	dm_db_column_store_row_group_physical_stats.has_vertipaq_optimization,
	dm_db_column_store_row_group_physical_stats.total_rows,
	dm_db_column_store_row_group_physical_stats.size_in_bytes
FROM sys.dm_db_column_store_row_group_physical_stats
INNER JOIN sys.objects
ON objects.object_id = dm_db_column_store_row_group_physical_stats.object_id
INNER JOIN sys.partitions
ON partitions.object_id = objects.object_id
AND partitions.partition_number = dm_db_column_store_row_group_physical_stats.partition_number
INNER JOIN sys.indexes
ON indexes.object_id = dm_db_column_store_row_group_physical_stats.object_id
AND indexes.index_id = dm_db_column_store_row_group_physical_stats.index_id
AND indexes.type_desc LIKE '%COLUMNSTORE%'
ORDER BY dm_db_column_store_row_group_physical_stats.row_group_id;

-- Recreate the table with Vertipaq Optimization
CREATE TABLE Fact.Sale_OPTIMIZED (
	[Sale Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Bill To Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Invoice Date Key] [date] NOT NULL,
	[Delivery Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[WWI Invoice ID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Profit] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Total Dry Items] [int] NOT NULL,
	[Total Chiller Items] [int] NOT NULL,
	[Lineage Key] [int] NOT NULL)
ON PS_Date ([Invoice Date Key]);
GO

INSERT INTO Fact.Sale_OPTIMIZED
SELECT * FROM Fact.Sale;
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_Sale_OPTIMIZED ON Fact.Sale_OPTIMIZED;
GO
-- 4.8MB-->3.2MB = ~33% savings!
SELECT DISTINCT
	objects.name AS table_name,
	indexes.name AS index_name,
	partitions.partition_number,
	dm_db_column_store_row_group_physical_stats.row_group_id,
	dm_db_column_store_row_group_physical_stats.has_vertipaq_optimization,
	dm_db_column_store_row_group_physical_stats.total_rows,
	dm_db_column_store_row_group_physical_stats.size_in_bytes
FROM sys.dm_db_column_store_row_group_physical_stats
INNER JOIN sys.objects
ON objects.object_id = dm_db_column_store_row_group_physical_stats.object_id
INNER JOIN sys.partitions
ON partitions.object_id = objects.object_id
AND partitions.partition_number = dm_db_column_store_row_group_physical_stats.partition_number
INNER JOIN sys.indexes
ON indexes.object_id = dm_db_column_store_row_group_physical_stats.object_id
AND indexes.index_id = dm_db_column_store_row_group_physical_stats.index_id
AND indexes.type_desc LIKE '%COLUMNSTORE%'
and indexes.name IN ('CCX_Fact_Sale', 'CCI_Sale_OPTIMIZED')
ORDER BY objects.name;

DROP TABLE Fact.Sale_OPTIMIZED;
GO

/******************************************************************************************
*********************************Bulk Insert into a Columnstore Index**********************
*******************************************************************************************/
CREATE TABLE Fact.Sale_Transactional (
	[Sale Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Bill To Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Invoice Date Key] [date] NOT NULL,
	[Delivery Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[WWI Invoice ID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Profit] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Total Dry Items] [int] NOT NULL,
	[Total Chiller Items] [int] NOT NULL,
	[Lineage Key] [int] NOT NULL,
 CONSTRAINT PK_Fact_Sale_Transactional PRIMARY KEY CLUSTERED 
(	[Sale Key] ASC,
	[Invoice Date Key] ASC))
WITH (DATA_COMPRESSION = PAGE);

INSERT INTO fact.Sale_Transactional
	([Sale Key], [City Key],[Customer Key], [Bill To Customer Key], [Stock Item Key], [Invoice Date Key], [Delivery Date Key], [Salesperson Key], [WWI Invoice ID],
     Description, Package, Quantity, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount], Profit, [Total Including Tax], [Total Dry Items],
     [Total Chiller Items], [Lineage Key])
SELECT TOP 102400
	*
FROM Fact.Sale;

-- Gets the log size in bytes
-- It's 489720 bytes!
SELECT
	fn_dblog.allocunitname,
	SUM(fn_dblog.[log record length]) AS log_size_bytes
FROM sys.fn_dblog (NULL, NULL)
WHERE fn_dblog.allocunitname = ('Fact.Sale_Transactional.PK_Fact_Sale_Transactional')
GROUP BY fn_dblog.allocunitname;

CREATE TABLE Fact.Sale_CCI_Clean_Test (
	[Sale Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Bill To Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Invoice Date Key] [date] NOT NULL,
	[Delivery Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[WWI Invoice ID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Profit] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Total Dry Items] [int] NOT NULL,
	[Total Chiller Items] [int] NOT NULL,
	[Lineage Key] [int] NOT NULL);
	
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Sale_CCI_Clean_Test ON Fact.Sale_CCI_Clean_Test;

INSERT INTO fact.Sale_CCI_Clean_Test
	([Sale Key], [City Key],[Customer Key], [Bill To Customer Key], [Stock Item Key], [Invoice Date Key], [Delivery Date Key], [Salesperson Key], [WWI Invoice ID],
     Description, Package, Quantity, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount], Profit, [Total Including Tax], [Total Dry Items],
     [Total Chiller Items], [Lineage Key])
SELECT TOP 102400
	*
FROM Fact.Sale;

-- It's 118,192 bytes!  About 1/4 the size of before.
SELECT
	fn_dblog.allocunitname,
	SUM(fn_dblog.[log record length]) AS log_size
FROM sys.fn_dblog (NULL, NULL)
WHERE fn_dblog.allocunitname = ('Fact.Sale_CCI_Clean_Test.CCI_Sale_CCI_Clean_Test')
GROUP BY fn_dblog.allocunitname;

DROP TABLE Fact.Sale_CCI_Clean_Test;

CREATE TABLE Fact.Sale_CCI_Clean_Test_2 (
	[Sale Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Bill To Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Invoice Date Key] [date] NOT NULL,
	[Delivery Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[WWI Invoice ID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Profit] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Total Dry Items] [int] NOT NULL,
	[Total Chiller Items] [int] NOT NULL,
	[Lineage Key] [int] NOT NULL);

CREATE CLUSTERED COLUMNSTORE INDEX CCI_Sale_CCI_Clean_Test_2 ON Fact.Sale_CCI_Clean_Test_2;

INSERT INTO fact.Sale_CCI_Clean_Test_2
	([Sale Key], [City Key],[Customer Key], [Bill To Customer Key], [Stock Item Key], [Invoice Date Key], [Delivery Date Key], [Salesperson Key], [WWI Invoice ID],
     Description, Package, Quantity, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount], Profit, [Total Including Tax], [Total Dry Items],
     [Total Chiller Items], [Lineage Key])
SELECT TOP 102399
	*
FROM Fact.Sale;

--The log space used by the delta store is significantly greater than both the bulk-logged transaction AND the rowstore transaction!
-- 456 bytes for the table and 1,300,448 (!) for the delta store

SELECT
	fn_dblog.allocunitname,
	SUM(fn_dblog.[log record length]) AS log_size
FROM sys.fn_dblog (NULL, NULL)
WHERE fn_dblog.allocunitname IN ('Fact.Sale_CCI_Clean_Test_2.CCI_Sale_CCI_Clean_Test_2', 'Fact.Sale_CCI_Clean_Test_2.CCI_Sale_CCI_Clean_Test_2(Delta)')
GROUP BY fn_dblog.allocunitname;

-- Check the structure of the table
SELECT
	tables.name AS table_name,
	indexes.name AS index_name,
	partitions.partition_number,
	column_store_row_groups.row_group_id,
	column_store_row_groups.state_description,
	column_store_row_groups.total_rows,
	column_store_row_groups.size_in_bytes,
	column_store_row_groups.deleted_rows,
	internal_partitions.internal_object_type_desc,
	internal_partitions.rows,
	internal_partitions.data_compression_desc
FROM sys.column_store_row_groups
INNER JOIN sys.indexes
ON indexes.index_id = column_store_row_groups.index_id
AND indexes.object_id = column_store_row_groups.object_id
INNER JOIN sys.tables
ON tables.object_id = indexes.object_id
INNER JOIN sys.partitions
ON partitions.partition_number = column_store_row_groups.partition_number
AND partitions.index_id = indexes.index_id
AND partitions.object_id = tables.object_id
LEFT JOIN sys.internal_partitions
ON internal_partitions.object_id = tables.object_id
WHERE tables.name = 'Sale_CCI_Clean_Test_2'
ORDER BY indexes.index_id, column_store_row_groups.row_group_id;

ALTER INDEX CCI_Sale_CCI_Clean_Test_2 ON Fact.Sale_CCI_Clean_Test_2 REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

SELECT
	tables.name AS table_name,
	indexes.name AS index_name,
	partitions.partition_number,
	column_store_row_groups.row_group_id,
	column_store_row_groups.state_description,
	column_store_row_groups.total_rows,
	column_store_row_groups.size_in_bytes,
	column_store_row_groups.deleted_rows,
	internal_partitions.internal_object_type_desc,
	internal_partitions.rows,
	internal_partitions.data_compression_desc
FROM sys.column_store_row_groups
INNER JOIN sys.indexes
ON indexes.index_id = column_store_row_groups.index_id
AND indexes.object_id = column_store_row_groups.object_id
INNER JOIN sys.tables
ON tables.object_id = indexes.object_id
INNER JOIN sys.partitions
ON partitions.partition_number = column_store_row_groups.partition_number
AND partitions.index_id = indexes.index_id
AND partitions.object_id = tables.object_id
LEFT JOIN sys.internal_partitions
ON internal_partitions.object_id = tables.object_id
WHERE tables.name = 'Sale_CCI_Clean_Test_2'
ORDER BY indexes.index_id, column_store_row_groups.row_group_id;

ALTER INDEX CCI_Sale_CCI_Clean_Test_2 ON Fact.Sale_CCI_Clean_Test_2 REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

SELECT
	tables.name AS table_name,
	indexes.name AS index_name,
	partitions.partition_number,
	column_store_row_groups.row_group_id,
	column_store_row_groups.state_description,
	column_store_row_groups.total_rows,
	column_store_row_groups.size_in_bytes,
	column_store_row_groups.deleted_rows,
	internal_partitions.internal_object_type_desc,
	internal_partitions.rows,
	internal_partitions.data_compression_desc
FROM sys.column_store_row_groups
INNER JOIN sys.indexes
ON indexes.index_id = column_store_row_groups.index_id
AND indexes.object_id = column_store_row_groups.object_id
INNER JOIN sys.tables
ON tables.object_id = indexes.object_id
INNER JOIN sys.partitions
ON partitions.partition_number = column_store_row_groups.partition_number
AND partitions.index_id = indexes.index_id
AND partitions.object_id = tables.object_id
LEFT JOIN sys.internal_partitions
ON internal_partitions.object_id = tables.object_id
WHERE tables.name = 'Sale_CCI_Clean_Test_2'
ORDER BY indexes.index_id, column_store_row_groups.row_group_id;

DROP TABLE Fact.Sale_CCI_Clean_Test_2;
DROP TABLE Fact.Sale_Transactional;
/******************************************************************************************
*********************************Rowgroup Elimination**************************************
*******************************************************************************************/
-- Create a test table.  This is already done!!!
CREATE TABLE dbo.fact_order_BIG_CCI (
	[Order Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Order Date Key] [date] NOT NULL,
	[Picked Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[Picker Key] [int] NULL,
	[WWI Order ID] [int] NOT NULL,
	[WWI Backorder ID] [int] NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Lineage Key] [int] NOT NULL);

-- Generate 231,412 * 100 rows of data in an OLTP table.  This is a little faster than with the OLTP table.
INSERT INTO dbo.fact_order_BIG_CCI
SELECT
	 [Order Key] + (250000 * ([Day Number] + ([Calendar Month Number] * 31))) AS [Order Key]
    ,[City Key]
    ,[Customer Key]
    ,[Stock Item Key]
    ,[Order Date Key]
    ,[Picked Date Key]
    ,[Salesperson Key]
    ,[Picker Key]
    ,[WWI Order ID]
    ,[WWI Backorder ID]
    ,[Description]
    ,[Package]
    ,[Quantity]
    ,[Unit Price]
    ,[Tax Rate]
    ,[Total Excluding Tax]
    ,[Tax Amount]
    ,[Total Including Tax]
    ,[Lineage Key]
FROM Fact.[Order]
CROSS JOIN
Dimension.Date
WHERE Date.Date <= '2013-04-10';

-- Create a columnstore index on the table.
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_order_BIG_CCI ON dbo.fact_order_BIG_CCI;
GO
--	How much data do we have?  23,141,200 Rows.
SELECT
	COUNT(*),
	MIN([order date key]),
	MAX([order date key])
FROM dbo.fact_order_BIG_CCI;

SELECT
	tables.name AS table_name,
	indexes.name AS index_name,
	columns.name AS column_name,
	partitions.partition_number,
	column_store_segments.segment_id,
	column_store_segments.min_data_id,
	column_store_segments.max_data_id,
	column_store_segments.row_count
FROM sys.column_store_segments
INNER JOIN sys.partitions
ON column_store_segments.hobt_id = partitions.hobt_id
INNER JOIN sys.indexes
ON indexes.index_id = partitions.index_id
AND indexes.object_id = partitions.object_id
INNER JOIN sys.tables
ON tables.object_id = indexes.object_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id
AND column_store_segments.column_id = columns.column_id
WHERE tables.name = 'fact_order_BIG_CCI'
AND columns.name = 'Order Date Key'
ORDER BY tables.name, columns.name, column_store_segments.segment_id;

SET STATISTICS IO ON;
-- Test analytic query
-- Demo execution plan and STATS IO
SELECT
	SUM([Quantity])
FROM dbo.fact_order_BIG_CCI
WHERE [Order Date Key] >= '1/1/2016'
AND [Order Date Key] < '2/1/2016';

CREATE TABLE dbo.fact_order_BIG_CCI_ORDERED (
	[Order Key] [bigint] NOT NULL,
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Order Date Key] [date] NOT NULL,
	[Picked Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[Picker Key] [int] NULL,
	[WWI Order ID] [int] NOT NULL,
	[WWI Backorder ID] [int] NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Lineage Key] [int] NOT NULL);

CREATE CLUSTERED INDEX CCI_fact_order_BIG_CCI_ORDERED ON dbo.fact_order_BIG_CCI_ORDERED ([Order Date Key]);

INSERT INTO dbo.fact_order_BIG_CCI_ORDERED
SELECT
	 [Order Key] + (250000 * ([Day Number] + ([Calendar Month Number] * 31))) AS [Order Key]
    ,[City Key]
    ,[Customer Key]
    ,[Stock Item Key]
    ,[Order Date Key]
    ,[Picked Date Key]
    ,[Salesperson Key]
    ,[Picker Key]
    ,[WWI Order ID]
    ,[WWI Backorder ID]
    ,[Description]
    ,[Package]
    ,[Quantity]
    ,[Unit Price]
    ,[Tax Rate]
    ,[Total Excluding Tax]
    ,[Tax Amount]
    ,[Total Including Tax]
    ,[Lineage Key]
FROM Fact.[Order]
CROSS JOIN
Dimension.Date
WHERE Date.Date <= '2013-04-10';

-- Use MAPDOP = 1 to ensure that parallelism does not affect data order when the index is built.  We want it in a single ordered thread.
-- Since we do not build columnstore indexes from scratch often, the potential added time is 100% worth the wait.
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_order_BIG_CCI_ORDERED ON dbo.fact_order_BIG_CCI_ORDERED WITH (MAXDOP = 1, DROP_EXISTING = ON);
GO

SELECT
	SUM([Quantity])
FROM dbo.fact_order_BIG_CCI_ORDERED
WHERE [Order Date Key] >= '1/1/2016'
AND [Order Date Key] < '2/1/2016';

SELECT
	tables.name AS table_name,
	indexes.name AS index_name,
	columns.name AS column_name,
	partitions.partition_number,
	column_store_segments.segment_id,
	column_store_segments.min_data_id,
	column_store_segments.max_data_id,
	column_store_segments.row_count
FROM sys.column_store_segments
INNER JOIN sys.partitions
ON column_store_segments.hobt_id = partitions.hobt_id
INNER JOIN sys.indexes
ON indexes.index_id = partitions.index_id
AND indexes.object_id = partitions.object_id
INNER JOIN sys.tables
ON tables.object_id = indexes.object_id
INNER JOIN sys.columns
ON tables.object_id = columns.object_id
AND column_store_segments.column_id = columns.column_id
WHERE tables.name = 'fact_order_BIG_CCI_ORDERED'
AND columns.name = 'Order Date Key'
ORDER BY tables.name, columns.name, column_store_segments.segment_id;

-- Disable Execution Plan (!)

-- Compare table sizes between columnstore indexes.  Order vs. Unordered.
CREATE TABLE #storage_data
(	table_name VARCHAR(MAX),
	rows_used BIGINT,
	reserved VARCHAR(50),
	data VARCHAR(50),
	index_size VARCHAR(50),
	unused VARCHAR(50));

INSERT INTO #storage_data
	(table_name, rows_used, reserved, data, index_size, unused)
EXEC sp_MSforeachtable "EXEC sp_spaceused '?'";

UPDATE #storage_data
	SET reserved = LEFT(reserved, LEN(reserved) - 3),
		data = LEFT(data, LEN(data) - 3),
		index_size = LEFT(index_size, LEN(index_size) - 3),
		unused = LEFT(unused, LEN(unused) - 3);

SELECT
	table_name,
	rows_used,
	reserved / 1024 AS data_space_reserved_mb,
	data / 1024 AS data_space_used_mb,
	index_size / 1024 AS index_size_mb,
	unused AS free_space_kb,
	CAST(CAST(data AS DECIMAL(24,2)) / CAST(rows_used AS DECIMAL(24,2)) AS DECIMAL(24,4)) AS kb_per_row
FROM #storage_data
WHERE rows_used > 0
AND table_name LIKE 'fact_order_BIG_%'
ORDER BY CAST(reserved AS INT) DESC;

DROP TABLE #storage_data;
GO