USE WideWorldImportersDW;
GO

-- Dictionary Metadata in sys.column_store_dictionaries.
SELECT * FROM sys.column_store_dictionaries;

-- Dictionary detail for each column/partition in the table
SELECT
	partitions.partition_number,
	objects.name AS table_name,
	columns.name AS column_name,
	types.name AS data_type,
	types.max_length,
	types.precision,
	types.scale,
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
	column_store_dictionaries.on_disk_size
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
WHERE objects.name = 'Sale';

-- Dictionary data for a specific column, including some columnstore segment metadata
SELECT
	partitions.partition_number,
	types.name AS data_type,
	types.max_length,
	types.precision,
	types.scale,
	CASE
		WHEN PRIMARY_DICTIONARY.dictionary_id IS NOT NULL THEN 1
		ELSE 0
	END AS does_global_dictionary_exist,
	PRIMARY_DICTIONARY.entry_count AS global_dictionary_entry_count,
	PRIMARY_DICTIONARY.on_disk_size AS global_dictionary_on_disk_size,
	CASE
		WHEN SECONDARY_DICTIONARY.dictionary_id IS NOT NULL THEN 1
		ELSE 0
	END AS does_local_dictionary_exist,
	SECONDARY_DICTIONARY.entry_count AS local_dictionary_entry_count,
	SECONDARY_DICTIONARY.on_disk_size AS local_dictionary_on_disk_size,
	column_store_segments.has_nulls,
	column_store_segments.row_count,
	column_store_segments.base_id,
	column_store_segments.magnitude,
	column_store_segments.min_data_id,
	column_store_segments.max_data_id
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
AND columns.name = 'Bill To Customer Key';

-- Check which rowgroups benefit from Vertipaq Optimization
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
