USE WideWorldImportersDW;
/*	SOME FUNCTIONS REQUIRE COMPATABILITY LEVEL 170!	*/
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 170;
GO
/*	REGEXP_LIKE: Returns a 1 if a Regex pattern is found within a string.
	Otherwise, returns 0.
*/
SELECT 
	* -- Finds any string ending in "NY)"
FROM Dimension.Customer
WHERE REGEXP_LIKE(Customer.Customer, ' NY[)]');

SELECT
	* -- Finds strings starting (^) in capital A and ending ($) in lowercase a
FROM Dimension.Customer
WHERE REGEXP_LIKE(Customer.[Primary Contact], '^A.*a$');

SELECT
	* -- Finds strings containing the letter "s" twice consecutively
FROM Dimension.Customer
WHERE REGEXP_LIKE(Customer.Customer, '[sS]{2,}');

/*	REGEXP_COUNT: Returns the number of times that a Regex pattern is found
	within a string.
*/
-- How many times in a string are there consecutive letter "s"?
SELECT
	[City Key],
	City,
	[State Province],
	REGEXP_COUNT(City.City, '[sS]{2,}') AS SequenceCount
FROM Dimension.City
ORDER BY REGEXP_COUNT(City.City, '[sS]{2,}') DESC;
-- Added parameter specifies what character to begin at:
SELECT
	[City Key],
	City,
	[State Province],
	REGEXP_COUNT(City.City, '[sS]{2,}', 6) AS SequenceCount
FROM Dimension.City
ORDER BY REGEXP_COUNT(City.City, '[sS]{2,}', 6) DESC;

SELECT
	City.City,
	-- All cities starting with "New" followed immediately by a space "\s"
	REGEXP_COUNT(City.City, '^New\s')
FROM Dimension.City
WHERE REGEXP_LIKE(City.City, '^New\s');

/*	REGEXP_INSTR: Finds the start/end position within a string for a given Regex expression.
*/
SELECT -- Finds all strings with "New" in them and returns its start location
	City.City,
	City.[State Province],
	REGEXP_INSTR(City.City, 'New') AS StringLocation
FROM Dimension.City
WHERE REGEXP_LIKE(City.City, 'New');

SELECT -- Added parameter specifies what character to begin searching at.
	City.City,
	City.[State Province],
	REGEXP_INSTR(City.City, 'New', 2) AS StringLocation
FROM Dimension.City
WHERE REGEXP_LIKE(City.City, 'New');

SELECT -- The third parameter specifies which occurrence of the expression to locate.
	City.City,
	City.[State Province],
	REGEXP_INSTR(City.City, 'New', 1, 2) AS StringLocation
FROM Dimension.City
WHERE REGEXP_INSTR(City.City, 'New', 1, 2) > 0;

SELECT -- Final parameter specifies whether the starting (0) or ending position (1) should be returned
	City.City,
	City.[State Province],
	REGEXP_INSTR(City.City, 'New', 1, 2, 1) AS StringLocation
FROM Dimension.City
WHERE REGEXP_INSTR(City.City, 'New', 1, 2, 1) > 0;

SELECT -- We can get silly here, too:
	City.City,
	City.[State Province],
	REGEXP_INSTR(City.City, ' N.*?w', 1, 1, 0, 'i') AS StringLocation
FROM Dimension.City
WHERE REGEXP_INSTR(City.City, ' N.*?w', 1, 1, 0, 'i') > 0;
/*	Return the start position in any city where the second (or later) word starts with "N"
	and is followed by a "w" later in the string.
	The "i" flag at the end makes the regular expression case-insensitive,
	which can be a handy flag for databases that use case-insensitive collations. */

/*	REGEXP_REPLACE: Works like REPLACE(), but using Regex expressions instead of string literals
*/
-- Replaces "New" with "Old". Just for fun :-)
SELECT
	City.City,
	City.[State Province],
	REGEXP_REPLACE(City.City, 'New', 'Old') AS OldCityName
FROM Dimension.City
WHERE REGEXP_COUNT(City.City, 'New') > 0;

-- Starting at character 5, this replaces "New" or "Old" with "Mid". Case-sensitive by default.
SELECT
	City.City,
	City.[State Province],
	REGEXP_REPLACE(City.City, 'New|Old', 'Mid', 5) AS MidCityName
FROM Dimension.City
WHERE REGEXP_COUNT(City.City, 'New|Old', 5) > 0;

/* Added parameter tells the function to only return results for the nth occurrence.
   In this case, it looks only for the 2nd occurrence, instead of the first	*/
SELECT
	City.City,
	City.[State Province],
	REGEXP_REPLACE(City.City, 'New|Old', 'Mid', 1, 2, 'i') AS MidCityName
FROM Dimension.City
WHERE REGEXP_REPLACE(City.City, 'New|Old', 'Mid', 1, 2, 'i') <> City.City;

/*	REGEXP_SUBSTR: Finds a Regex pattern and returns the substring that matches it.
*/
-- This returns the contents of parenthesis. If results are not found, NULL is returned.
SELECT
	Customer.[Customer Key],
	Customer.Customer,
	REGEXP_SUBSTR(Customer.Customer, '\(([^)]+)\)') AS OfficeLocation
FROM Dimension.Customer;

-- Returns the letter prefix, if one exists. 
SELECT
	Supplier.[Supplier Key],
	Supplier.[Supplier Reference],
	REGEXP_SUBSTR(Supplier.[Supplier Reference], '[a-zA-Z]+') AS LetterCode
FROM Dimension.Supplier;

-- Adjusting + to * allows for an empty string to be returned, instead of NULL, if not found.
SELECT
	Supplier.[Supplier Key],
	Supplier.[Supplier Reference],
	REGEXP_SUBSTR(Supplier.[Supplier Reference], '[a-zA-Z]*') AS LetterCode
FROM Dimension.Supplier;

/*	REGEXP_MATCHES: Returns a set of Regex matches, along with useful details
	This is a lot of detail and can get large if the data size is big.
*/
/*	This finds all matches where a city contains multiple sets of consecutive letter "s"
	For each match, the start position, end position, match value, and JSON with those
	details are provided for your use.
*/
SELECT
	[City Key],
	City,
	[State Province],
	RegexMatchData.*
FROM Dimension.City
CROSS APPLY REGEXP_MATCHES(City.City, '[sS]{2,}') AS RegexMatchData
WHERE REGEXP_COUNT(City.City, '[sS]{2,}') > 1
ORDER BY City.City ASC;

/*	REGEXP_SPLIT_TO_TABLE: Behaves like STRING_SPLIT, except it can be used for any Regex
	expression
*/
-- Splits on spaces:
SELECT * FROM REGEXP_SPLIT_TO_TABLE ('the quick brown fox jumps over the lazy dog', '\s+')

-- Finds cities with multiple pairs of the letter "s" and splits it on that pattern:
SELECT
	[City Key],
	City,
	[State Province],
	RegexSplitData.*
FROM Dimension.City
CROSS APPLY REGEXP_SPLIT_TO_TABLE(City.City, '[sS]{2,}') AS RegexSplitData
WHERE REGEXP_COUNT(City.City, '[sS]{2,}') > 1
ORDER BY City.City ASC;

/*	This tries to split on two characters, but doesn't work as STRING_SPLIT only accepts
	a ***single character*** as the split criteria */
SELECT
	*
FROM STRING_SPLIT(N'"Taco", "Pizza", "Cheeseburger", "Salad", "Apple", "Carrot"', N'", "');

-- This ALMOST works, except that the double-quotes remain:
SELECT
	*
FROM REGEXP_SPLIT_TO_TABLE('"Taco", "Pizza", "Cheeseburger", "Salad", "Apple", "Carrot"', '", "');

-- This trims out the double-quotes:
SELECT
	*
FROM REGEXP_SPLIT_TO_TABLE('"Taco", "Pizza", "Cheeseburger", "Salad", "Apple", "Carrot"', '", "|^"|"$')
WHERE [value] <> '';

/*	FLAGS
		There are a variety of flags that can augment these functions. Feel free to experiement
		with them to learn their function:

	i: Case Insensitive 
	When the "i" flag is used, all string characters in the regular expression
	will be treated as case insensitive, allowing capital and lowercase letters
	to match patterns for each other. This is not a default setting. 

	c: Case Sensitive
	This forces regex pattern matching to be case sensitive. This is the default
	setting and does not need to be explicitly used to ensure case sensitive regular
	expression matching. 

	m: Multi-Line Mode
	When this flag is used, the carat (^) and dollar sign ($) will match the begin/end
	line characters in addition to begin/end text. This is not a default setting. 

	s: New Line Character Matching 
	This flag allows a period (.) to match a new line character (\n). This is not a
	default setting. Normally a period will match most characters, but not a new line.
*/
