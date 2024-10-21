USE AdventureWorks2022; -- This is my local SQL Server 2022 instance
GO

DECLARE @PersonInfo VARCHAR(MAX) =
'[
	{
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	}
]';
DECLARE @IsValidJSON BIT
SELECT @IsValidJSON = ISJSON(@PersonInfo);

IF @IsValidJSON = 0
BEGIN
	RAISERROR('The JSON entered is not valid. Please investigate and resolve this problem!', 16, 1);
	RETURN
END
GO

DECLARE @PersonInfo VARCHAR(MAX) =
'[
	{
		"FirstName": "Edward",
		"LastName": "Pollack",
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	},
	{
		"FirstName": "Edgar",
		"LastName": "Codd",
		"City": "Fortuneswell",
		"State": "Dorset",
		"SpiceLevel": "Medium",
		"FavoriteSport": "Flying",
		"Skills": ["SQL", "Computers", "Flying", "Normalizing Data Models"]
	}
]';
SELECT ISJSON(@PersonInfo);

IF EXISTS (SELECT * FROM sys.tables WHERE tables.name = 'PersonInfo')
BEGIN
	DROP TABLE dbo.PersonInfo;
END
GO

CREATE TABLE dbo.PersonInfo
(	PersonId INT NOT NULL IDENTITY(1,1)
		CONSTRAINT PK_PersonInfo PRIMARY KEY CLUSTERED,
	FirstName VARCHAR(100) NOT NULL,
	LastName VARCHAR(100) NOT NULL,
	PersonMetadata VARCHAR(MAX) NOT NULL); -- This will be our JSON document

INSERT INTO dbo.PersonInfo
	(FirstName, LastName, PersonMetadata)
VALUES
('Edward', 'Pollack',
'{ "PersonInfo":
	{
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	}
}'),
('Edgar', 'Codd',
'{ "PersonInfo":
	{
		"City": "Fortuneswell",
		"State": "Dorset",
		"SpiceLevel": "Medium",
		"FavoriteSport": "Flying",
		"Skills": ["SQL", "Computers", "Flying", "Normalizing Data Models"]
	}
}');
	
INSERT INTO dbo.PersonInfo
	(FirstName, LastName, PersonMetadata)
VALUES
('Thomas', 'Edison',
'{ "PersonInfo":
	{
		"City": "Milan",
		"State": "Ohio",
		"SpiceLevel": "Mild",
		"FavoriteSport": "Reading",
		"Skills": ["Technology", "Business", "Communication"]
	}
}'),
('Nikola', 'Tesla',
'{ "PersonInfo":
	{
		"City": "Smiljan",
		"State": "Croatia",
		"SpiceLevel": "Hot",
		"FavoriteSport": "Inventing",
		"Skills": ["Lighting", "Electricity", "X-Rays", "Motors"]
	}
}');

SELECT
	*
FROM dbo.PersonInfo
WHERE ISJSON(PersonInfo.PersonMetadata) = 1;

SELECT
	*
FROM dbo.PersonInfo
WHERE JSON_VALUE(PersonMetadata, '$.PersonInfo.City') = 'Albany';



/***************************************************************************************************
***************************************************************************************************/
-- In Azure SQL Database (connect to database JSONTest)
GO

DECLARE @PersonInfo JSON =
'[
	{
		"FirstName": "Edward",
		"LastName": "Pollack",
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	},
	{
		"FirstName": "Edgar",
		"LastName": "Codd",
		"City": "Fortuneswell",
		"State": "Dorset",
		"SpiceLevel": "Medium",
		"FavoriteSport": "Flying",
		"Skills": ["SQL", "Computers", "Flying", "Normalizing Data Models"]
	}
]';
SELECT ISJSON(@PersonInfo);
GO

CREATE TABLE dbo.JSONTest
(	ID INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_JSONTest PRIMARY KEY CLUSTERED,
	DocName VARCHAR(50) NOT NULL,
	JSONDocument JSON NOT NULL CONSTRAINT CK_JSONTest_Check_FirstName
		CHECK (JSON_PATH_EXISTS(JSONDocument, '$.FirstName') = 1));
-- JSON_PATH_EXISTS was introduced in SQL Server 2022

-- This works nicely!
INSERT INTO dbo.JSONTest
	(DocName, JSONDocument)
VALUES
(   'A name entry',
    '{
		"FirstName": "Edward",
		"LastName": "Pollack",
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	}');

-- This does not! No FirstName path in the JSON document, so it fails:
INSERT INTO dbo.JSONTest
	(DocName, JSONDocument)
VALUES
(   'A name entry',
    '{
		"LastName": "Pollack",
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	}');

DROP TABLE dbo.JSONTest;
GO

-- This is the same table as earlier, but adjusted from VARCHAR to JSON:
IF EXISTS (SELECT * FROM sys.tables WHERE tables.name = 'PersonInfo')
BEGIN
	DROP TABLE dbo.PersonInfo;
END
GO

CREATE TABLE dbo.PersonInfo
(	PersonId INT NOT NULL IDENTITY(1,1)
		CONSTRAINT PK_PersonInfo PRIMARY KEY CLUSTERED,
	FirstName VARCHAR(100) NOT NULL,
	LastName VARCHAR(100) NOT NULL,
	PersonMetadata JSON NOT NULL); -- This was previously VARCHAR(MAX) in our on-prem SQL Server

-- SAME code as earlier!
INSERT INTO dbo.PersonInfo
	(FirstName, LastName, PersonMetadata)
VALUES
('Edward', 'Pollack',
'{ "PersonInfo":
	{
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	}
}'),
('Edgar', 'Codd',
'{ "PersonInfo":
	{
		"City": "Fortuneswell",
		"State": "Dorset",
		"SpiceLevel": "Medium",
		"FavoriteSport": "Flying",
		"Skills": ["SQL", "Computers", "Flying", "Normalizing Data Models"]
	}
}');
INSERT INTO dbo.PersonInfo
	(FirstName, LastName, PersonMetadata)
VALUES
('Thomas', 'Edison',
'{ "PersonInfo":
	{
		"City": "Milan",
		"State": "Ohio",
		"SpiceLevel": "Mild",
		"FavoriteSport": "Reading",
		"Skills": ["Technology", "Business", "Communication"]
	}
}'),
('Nikola', 'Tesla',
'{ "PersonInfo":
	{
		"City": "Smiljan",
		"State": "Croatia",
		"SpiceLevel": "Hot",
		"FavoriteSport": "Inventing",
		"Skills": ["Lighting", "Electricity", "X-Rays", "Motors"]
	}
}');

SELECT
	*
FROM dbo.PersonInfo
WHERE ISJSON(PersonInfo.PersonMetadata) = 1;
GO

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_VALUE(PersonMetadata, '$.PersonInfo.City') AS PersonCity,
	JSON_VALUE(PersonMetadata, '$.PersonInfo.State') AS PersonState
FROM dbo.PersonInfo;

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_VALUE(PersonMetadata, '$.PersonInfo.VideoGamePreference') AS PersonVideoGamePreference
FROM dbo.PersonInfo;

SELECT
	*
FROM dbo.PersonInfo
WHERE ISJSON(PersonMetadata) = 1
AND JSON_VALUE(PersonMetadata, '$.PersonInfo.City') = 'Albany';

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_PATH_EXISTS(PersonMetadata, '$.PersonInfo.VideoGamePreference') AS PersonVideoGamePreference
FROM dbo.PersonInfo;

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_MODIFY(JSON_MODIFY(PersonMetadata, '$.PersonInfo.City', 'London'), '$.PersonInfo.State', 'London') AS UpdatedDocument
FROM dbo.PersonInfo
WHERE JSON_VALUE(PersonMetadata, '$.PersonInfo.City') = 'Fortuneswell'
AND JSON_VALUE(PersonMetadata, '$.PersonInfo.State') = 'Dorset';

UPDATE PersonInfo
	SET PersonMetadata = 
	JSON_MODIFY(JSON_MODIFY(PersonMetadata, '$.PersonInfo.City', 'London'), '$.PersonInfo.State', 'London')
FROM dbo.PersonInfo
WHERE JSON_VALUE(PersonMetadata, '$.PersonInfo.City') = 'Fortuneswell'
AND JSON_VALUE(PersonMetadata, '$.PersonInfo.State') = 'Dorset';

SELECT
	*
FROM dbo.PersonInfo
WHERE JSON_VALUE(PersonMetadata, '$.PersonInfo.City') = 'London';

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_MODIFY(PersonMetadata, 'append $.PersonInfo.Skills', 'Mustaches')
FROM dbo.PersonInfo
WHERE FirstName = 'Nikola'
AND LastName = 'Tesla';

UPDATE PersonInfo
	SET PersonMetadata = JSON_MODIFY(PersonMetadata, 'append $.PersonInfo.Skills', 'Mustaches')
FROM dbo.PersonInfo
WHERE FirstName = 'Nikola'
AND LastName = 'Tesla';

-- NOTE THAT IT IS IN PREVIEW...AND...
SELECT
	*
FROM dbo.PersonInfo
WHERE 'Mustaches' IN (SELECT [value] FROM OPENJSON(PersonMetadata, '$.PersonInfo.Skills'));
-- OOF!
SELECT
	*
FROM dbo.PersonInfo
CROSS APPLY OPENJSON(PersonMetadata, '$.PersonInfo.Skills')
WHERE [value] = 'Mustaches';
-- OOF!
SELECT
	*
FROM dbo.PersonInfo
WHERE 'Mustaches' IN (SELECT [value] FROM OPENJSON(PersonMetadata, '$.PersonInfo.Skills'));
-- Well, it is in preview. I suppose that is what this preview thing is all about, eh?
SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_MODIFY(PersonMetadata, '$.PersonInfo.State', NULL)
FROM dbo.PersonInfo;

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_MODIFY(JSON_MODIFY(PersonMetadata, '$.PersonInfo.State', NULL), '$.PersonInfo.Region', JSON_VALUE(PersonMetadata, '$.PersonInfo.State'))
FROM dbo.PersonInfo;

SELECT
	PersonId,
	FirstName,
	LastName,
	JSON_MODIFY(JSON_MODIFY(PersonMetadata, '$.PersonInfo.Region', JSON_VALUE(PersonMetadata, '$.PersonInfo.Region')), '$.PersonInfo.State', NULL)
FROM dbo.PersonInfo;

SELECT
	PersonId,
	FirstName,
	LastName,
	PersonMetadata
FROM dbo.PersonInfo;

-- Computed column w/ JSON!
ALTER TABLE dbo.PersonInfo ADD City AS JSON_VALUE(PersonMetadata, '$.PersonInfo.City');

SELECT
	*
FROM dbo.PersonInfo;

-- Nice way to index JSON without indexing JSON.
-- If performance is #1, then create a permanent column, rather than a computed column.
CREATE NONCLUSTERED INDEX IX_PersonInfo_CityJSON
ON dbo.PersonInfo (City ASC);
-- I didn't like the warning message. It makes me nervous.

DROP INDEX IX_PersonInfo_CityJSON ON dbo.PersonInfo;
ALTER TABLE dbo.PersonInfo DROP COLUMN City;

ALTER TABLE dbo.PersonInfo ADD City AS
CAST(JSON_VALUE(PersonMetadata, '$.PersonInfo.City') AS VARCHAR(100));

CREATE NONCLUSTERED INDEX IX_PersonInfo_CityJSON
ON dbo.PersonInfo (City ASC);
-- That's better! 100 character limitation resolves the warning!

SELECT
	COUNT(*)
FROM dbo.PersonInfo
WHERE JSON_VALUE(PersonMetadata, '$.PersonInfo.City') = 'Albany';
-- Index scan
SELECT
	COUNT(*)
FROM dbo.PersonInfo
WHERE City = 'Albany';
-- Index seek!

SELECT
	PersonId,
	FirstName,
	LastName,
	COMPRESS(PersonMetadata) AS PersonMetadataCompressed
FROM dbo.PersonInfo;
-- Compress works on VARCHAR, but not on JSON, since JSON is already a parsed format.
-- It is unclear if JSON will be supported in the future.

DROP TABLE dbo.PersonInfo;
GO

-- This always works, if you do NOT have the JSON data type around:
CREATE TABLE dbo.PersonInfoCompressed
(	PersonId INT NOT NULL IDENTITY(1,1)
		CONSTRAINT PK_PersonInfoCompressed PRIMARY KEY CLUSTERED,
	FirstName VARCHAR(100) NOT NULL,
	LastName VARCHAR(100) NOT NULL,
	PersonMetadata VARBINARY(MAX) NOT NULL);

INSERT INTO dbo.PersonInfoCompressed
	(FirstName, LastName, PersonMetadata)
VALUES
('Edward', 'Pollack',
COMPRESS('{ "PersonInfo":
	{
		"City": "Albany",
		"State": "New York",
		"SpiceLevel": "Extreme",
		"FavoriteSport": "Baseball",
		"Skills": ["SQL", "Baking", "Running", "Minecraft"]
	}
}')),
('Edgar', 'Codd',
COMPRESS('{ "PersonInfo":
	{
		"City": "Fortuneswell",
		"State": "Dorset",
		"SpiceLevel": "Medium",
		"FavoriteSport": "Flying",
		"Skills": ["SQL", "Computers", "Flying", "Normalizing Data Models"]
	}
}'));
	
INSERT INTO dbo.PersonInfoCompressed
	(FirstName, LastName, PersonMetadata)
VALUES
('Thomas', 'Edison',
COMPRESS('{ "PersonInfo":
	{
		"City": "Milan",
		"State": "Ohio",
		"SpiceLevel": "Mild",
		"FavoriteSport": "Reading",
		"Skills": ["Technology", "Business", "Communication"]
	}
}')),
('Nikola', 'Tesla',
COMPRESS('{ "PersonInfo":
	{
		"City": "Smiljan",
		"State": "Croatia",
		"SpiceLevel": "Hot",
		"FavoriteSport": "Inventing",
		"Skills": ["Lighting", "Electricity", "X-Rays", "Motors"]
	}
}'));

SELECT
	*
FROM dbo.PersonInfoCompressed;

SELECT
	PersonId,
	FirstName,
	LastName,
	DECOMPRESS(PersonMetadata) AS PersonMetadata
FROM dbo.PersonInfoCompressed
WHERE LastName = 'Tesla';

SELECT
	CAST(DECOMPRESS(PersonMetadata) AS VARCHAR(MAX)) AS PersonMetadata
FROM dbo.PersonInfoCompressed
WHERE LastName = 'Tesla';

DROP TABLE dbo.PersonInfoCompressed;
GO

-- ONE MORE THING!
-- New functions: JSON_ARRAYAGG (works like STRING_AGG):
SELECT
	objects.[name] AS TableName,
	JSON_ARRAYAGG(columns.[name] ORDER BY columns.column_id) AS ColumnList
FROM sys.objects
INNER JOIN sys.columns
ON objects.[object_id] = columns.[object_id]
GROUP BY objects.[name]
ORDER BY objects.[name];

-- Also new: JSON_OBJECTAGG , which can create key/pair values from a data set
SELECT
	objects.[object_id],
	objects.[name] AS TableName,
	JSON_OBJECTAGG(columns.column_id:columns.[name]) AS ColumnList
FROM sys.objects
INNER JOIN sys.columns
ON objects.[object_id] = columns.[object_id]
GROUP BY objects.[object_id], objects.[name]
ORDER BY objects.[object_id], objects.[name];
