/*
	3/17/2023 Edward Pollack
	SQL Friday
	All About SQL Injection

	This file contains a variety of SQL demos that demonstrate ways in which TSQL can be used to modify form fields,
	insert unauthrorized, scripts, modify existing scripts, and otherwise perform unintended actions.
*/
USE AdventureWorks2017;
SET NOCOUNT ON;
GO
/******************************************************************************************************************************************************
*******************************************************************************************************************************************************
*******************************************************************************************************************************************************
************************************Basic Unprotected Dynamic SQL Exploits*****************************************************************************
*******************************************************************************************************************************************************
*******************************************************************************************************************************************************
*******************************************************************************************************************************************************/
-- Example of how a completely unprotected dynamic SQL search can be modified to allow for unintended TSQL execution.
-- This is the classic dynamic SQL exploit and the most common first-attempt that a hacker will make on application inputs.
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Criteria NVARCHAR(MAX);

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Person
	WHERE Person.FirstName = ''';

	SELECT @Search_Criteria = 'Edward'; -- This text is captured by a form field within an application.
	SELECT @Sql_Command = @Sql_Command + @Search_Criteria + '''';

	PRINT @Sql_Command;
	EXEC (@Sql_Command);
GO
-- The same query can be run for many different names that originate from web users.
-- Eventually, with certaintly, someone with an apostrophe in their name will enter their name:
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Criteria NVARCHAR(MAX);

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Person
	WHERE Person.LastName = ''';

	SELECT @Search_Criteria = 'O''Brien'; -- This text is captured by a form field within an application.
	SELECT @Sql_Command = @Sql_Command + @Search_Criteria + '''';

	PRINT @Sql_Command;
	EXEC (@Sql_Command);

	-- If we are fortunate, the resulting error message is captured by the application and NOT returned to the user.
	-- Any unexpected behavior here will be a big tip-off to a would-be hacker that this TSQL is worth exploring further.
GO
-- How can a malicious user take advantage of our inability to search for people with the last name of "O'Brien"?
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Criteria NVARCHAR(MAX);

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Person
	WHERE Person.LastName = ''';

	SELECT @Search_Criteria = 'Edward'' OR 1 = 1 AND '''' = '''; -- This text is captured by a form field within an application.
	SELECT @Sql_Command = @Sql_Command + @Search_Criteria + '''';

	PRINT @Sql_Command;
	EXEC (@Sql_Command);
	-- By closing the single-quotes in the search criteria, the user can now enter whatever they want into the TSQL statement.
	-- In this scenario, OR 1 = 1 is added, which causes the query to return all results from the table, regardless of whether 
	-- this user should be allowed to do so or not.  The additional "AND '' = ''" allows the user input to match the single-quotes
	-- that are added to the query on the next line.
GO
/******************************************************************************************************************************************************
***************************************************Input Form Search Abuse*****************************************************************************
*******************************************************************************************************************************************************/
-- SQL injection is not solely a dynamic SQL attack!  There are many ways in which standard TSQL can be abused to return unintended results.
-- In this example, user input is adjusted with SQL Server reserved characters in order to change the behavior of the search.
DECLARE @Search_Criteria NVARCHAR(MAX) = 'Thomas' -- User searches for "Thom", and gets no results returned.

SELECT
	*
FROM Person.Person
WHERE Person.FirstName LIKE @Search_Criteria;
GO

-- User adds in % delimiters around their string to expand the search set:
DECLARE @Search_Criteria NVARCHAR(MAX) = '%Thom%' -- User searches for "%Thom%", and gets every row with "Thom" somewhere in the first name.

SELECT
	*
FROM Person.Person
WHERE Person.FirstName LIKE @Search_Criteria;
GO
-- From here, they could get all results with little difficulty:
DECLARE @Search_Criteria NVARCHAR(MAX) = '%%' -- User searches for "%%", and gets everything in the table.

SELECT
	*
FROM Person.Person
WHERE Person.FirstName LIKE @Search_Criteria;
GO

-- Abuse Regex comparisons to get more out of the TSQL
DECLARE @Search_Criteria NVARCHAR(MAX) = '%[a-zA-Z0-9]%' -- User searches for "%[a-zA-Z0-9]%", and gets all results with alphanumeric in the first name.  This
														 -- could be expanded to provide more in-depth search analytics based on the type of text being searched.
SELECT
	*
FROM Person.Person
WHERE Person.FirstName LIKE @Search_Criteria;
GO
/******************************************************************************************************************************************************
***************************************************Login Form Abuse************************************************************************************
*******************************************************************************************************************************************************/
-- Similar behaviors can be used in order to force-validate a username/password field:
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @id NVARCHAR(MAX) = '3';
DECLARE @password NVARCHAR(128) = '12345';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Password
	WHERE Password.BusinessEntityID = ' + @id + '
	AND PasswordHash = ''' + @password + '''';
PRINT @Sql_Command;
EXEC (@Sql_Command);
GO
-- The above TSQL validates a password hash that is generated from user input.  In this case, the user has no clue
-- what the correct password is.  In the next case, UNION ALL is used to combine the above empty set with everything
-- in the table
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @id NVARCHAR(MAX) = '3';
DECLARE @password NVARCHAR(128) = ''' UNION ALL SELECT * FROM Person.Password WHERE '''' = ''';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Password
	WHERE Password.BusinessEntityID = ' + @id + '
	AND PasswordHash = ''' + @password + '''';
PRINT @Sql_Command;
EXEC (@Sql_Command);
GO
-- Comments can also be used to alter a TSQL statement in order to bypass a direct username/password check:
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @id NVARCHAR(128) = '3 -- ';
DECLARE @Password NVARCHAR(128) = 'Random Text That Is Definitely Not A Correct Password!!!';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Password
	WHERE Password.BusinessEntityID = ' + @id + ' AND PasswordHash = ''' + @password + '''';
PRINT @Sql_Command;
EXEC (@Sql_Command);
GO
-- This exploit replies on the validation section being on the same line.  More complex hacks can
-- be attempted using /* and */ in order to omit all or some parts of the validation logic:
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @id NVARCHAR(128) = '3 /*';
DECLARE @Password NVARCHAR(128) = 'Random Text That Is Definitely Not A Correct Password!!! */ AND '''' = ''';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Password
	WHERE Password.BusinessEntityID = ' + @id + '
	AND PasswordHash = ''' + @password + '''';
PRINT @Sql_Command;
EXEC (@Sql_Command);
GO
/******************************************************************************************************************************************************
*******************************************************************************************************************************************************
*******************************************************************************************************************************************************
*********************************************************Preventing SQL Injection**********************************************************************
*******************************************************************************************************************************************************
*******************************************************************************************************************************************************
*******************************************************************************************************************************************************/
/*	This covers ways in which we can safeguard our TSQL to be robust against injection attacks.  We hope that other parts of the application are also
	resilient, as layered security greatly reduces opportunities for hackers to gain unauthrized access to our systems.  Despite this, we cannot assume
	that any other component will protect us from harm.  Therefore we must write scripts that do not allow for exploits and provide flexibility in the
	event that any other component is not rock-solid.	*/

-- #1	Use sp_executesql and completely parameterize searches!
-- Searching for any last name works normally:
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Criteria NVARCHAR(25) = 'Clark';
DECLARE @Parameter_List NVARCHAR(MAX) = '@Search_Criteria NVARCHAR(25)';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Person
	WHERE Person.lastName = @Search_Criteria';

PRINT @Sql_Command;
EXEC sp_executesql @Sql_Command, @Parameter_List, @Search_Criteria;
GO
-- A search for O'Brien runs normally and returns the expected data.
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Criteria NVARCHAR(25) = 'O''Brien';
DECLARE @Parameter_List NVARCHAR(MAX) = '@Search_Criteria NVARCHAR(25)';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Person
	WHERE Person.lastName = @Search_Criteria';

PRINT @Sql_Command;
EXEC sp_executesql @Sql_Command, @Parameter_List, @Search_Criteria;
GO
-- An attempt to close the input string and return password data is nullified by parameterization.  The parameter @Search_Criteria is
-- referenced directly within the block of dynamic SQL.  Any attempt to splice in string delimiters fails.
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Criteria NVARCHAR(25) = ''' UNION ALL SELECT * FROM Person.Password WHERE '''' = ''';
DECLARE @Parameter_List NVARCHAR(MAX) = '@Search_Criteria NVARCHAR(25)';

SELECT @Sql_Command = '
	SELECT
		*
	FROM Person.Person
	WHERE Person.lastName = @Search_Criteria';

PRINT @Sql_Command;
EXEC sp_executesql @Sql_Command, @Parameter_List, @Search_Criteria;
GO
/******************************************************************************************************************************************************
****************************************************************Input Cleansing************************************************************************
*******************************************************************************************************************************************************/
-- Always cleanse inputs!  Check for invalid input and remove the ability to pass in unexpected characters.

-- Let's say we only want numbers and letters (a-z, A-Z, 0-9).  We could do something like this:
DECLARE @Input_String VARCHAR(MAX) = 'This i$ 0ne S!lly Strin6'
SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Input_String, ' ', ''), '!', ''), '@', ''), '#', ''), '$', ''), '%', '');
-- While this works, it is fundamentally incomplete and will miss out on unexpected characters, such as tabs, new lines, tildes, etc...)
-- Cleansing inputs should be generic and limit to only what we want, rather than removing undesired characters.

-- This can be accomplished by creating a function to remove non-alphanumeric characters from a string:
IF EXISTS (SELECT * FROM sys.objects WHERE objects.type = 'FN' and objects.name = 'Remove_Non_Alpha_Numeric_Characters')
BEGIN
	DROP FUNCTION dbo.Remove_Non_Alpha_Numeric_Characters;
END
GO

CREATE FUNCTION dbo.Remove_Non_Alpha_Numeric_Characters
	(@Input_String VARCHAR(MAX))
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @Characters_To_Keep VARCHAR(MAX) = '%[^a-z0-9A-Z]%'; -- Keep ONLY letters and numbers.  The carat (^) will invert this input and be used to determine
																 -- what to remove (everything that is not in our list of characters to keep).

	WHILE PATINDEX(@Characters_To_Keep, @Input_String) > 0
	BEGIN
		SELECT
			@Input_String = STUFF(@Input_String, PATINDEX(@Characters_To_Keep, @Input_String), 1, '');
	END

	RETURN @Input_String;
END
GO

SELECT dbo.Remove_Non_Alpha_Numeric_Characters('This is a test!!!!!'); -- Removes all non-alphanumeric characters, including spaces!
SELECT dbo.Remove_Non_Alpha_Numeric_Characters('%%I can''t pad the string, no matter how hard I try!!!%%');
GO

-- Always use schema name on objects.  Delimiting with square brackets greatly reduces the chances that a hacker will be able to
-- inject any meaningful TSQL into your code.  This query searches a dynamically chosen table, in this case Person.Person.
-- Do not skip schema name and do not use the shorthand ".." to skip the schema name.  This is fragile in many ways and should be avoided!
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Schema NVARCHAR(MAX) = 'Person'; -- Automatically provided.
DECLARE @Search_Table NVARCHAR(MAX) = 'Person'; -- User input

SELECT @Sql_Command = '
	SELECT
		*
	FROM '

	SELECT @Sql_Command = @Sql_Command + @Search_Schema + '.' + @Search_Table;

	PRINT @Sql_Command;
	EXEC (@Sql_Command);
GO
-- Messing with the input allows a user to add more TSQL to the table name and search Person.Password as well.
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Schema NVARCHAR(MAX) = 'Person'; -- Automatically provided.
DECLARE @Search_Table NVARCHAR(MAX) = 'Person; SELECT * FROM Person.Password'; -- User input

SELECT @Sql_Command = '
	SELECT
		*
	FROM '

	SELECT @Sql_Command = @Sql_Command + @Search_Schema + '.' + @Search_Table;

	PRINT @Sql_Command;
	EXEC (@Sql_Command);
GO
-- Adding brackets will prevent the previous hack from working.  But...
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Schema NVARCHAR(MAX) = 'Person'; -- Automatically provided.
DECLARE @Search_Table NVARCHAR(MAX) = 'Person; SELECT * FROM Person.Password'; -- User input

SELECT @Sql_Command = '
	SELECT
		*
	FROM '

	SELECT @Sql_Command = @Sql_Command + '['+ @Search_Schema + '].[' + @Search_Table + ']'

	PRINT @Sql_Command;
	EXEC (@Sql_Command);
GO
-- ...the addition of brackets slows hackers down, but does not stop them.  Eventually they find ways to adapt:
DECLARE @Sql_Command NVARCHAR(MAX);
DECLARE @Search_Schema NVARCHAR(MAX) = 'Person'; -- Automatically provided.
DECLARE @Search_Table NVARCHAR(MAX) = 'Person]; SELECT * FROM [Person].[Password'; -- User input

SELECT @Sql_Command = '
	SELECT
		*
	FROM '

	SELECT @Sql_Command = @Sql_Command + '['+ @Search_Schema + '].[' + @Search_Table + ']'

	PRINT @Sql_Command;
	EXEC (@Sql_Command);
GO
/******************************************************************************************************************************************************
****************************************************************Input Cleansing************************************************************************
*******************************************************************************************************************************************************/
-- User input should be validated in application and database code as needed.  Do not assume that the data you receive will be perfect.  Applications
-- and database scripts should both perform necessary validation to ensure that the data that is passed into your script will not somehow break
-- your code.  The following stored procedure validates NULL input, strips all non-alphanumeric characters from the input string, and limits
-- the result set to 25 rows.  Any of these options can be configured, but are valuable when used.
IF EXISTS (SELECT * FROM sys.procedures WHERE procedures.name = 'web_search')
BEGIN
	DROP PROCEDURE dbo.web_search;
END
GO

CREATE PROCEDURE dbo.web_search
	@PurchaseOrderNumber_Search_Data VARCHAR(50) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	IF @PurchaseOrderNumber_Search_Data IS NULL -- Prevent anomalous conditions, such as NULL, empty, or unusually long/short strings.
	BEGIN
		SELECT '';
	END
	ELSE
	BEGIN
		SELECT @PurchaseOrderNumber_Search_Data = dbo.Remove_Non_Alpha_Numeric_Characters(@PurchaseOrderNumber_Search_Data) + '%';

		SELECT TOP 25 -- Limit rows returned to prevent performance bombs via SQL Server
			PurchaseOrderNumber,
			SalesOrderNumber,
			AccountNumber,
			OrderDate,
			TotalDue
		FROM Sales.SalesOrderHeader
		WHERE PurchaseOrderNumber LIKE @PurchaseOrderNumber_Search_Data
		ORDER BY OrderDate DESC;
	END
END
GO

EXEC dbo.web_search @PurchaseOrderNumber_Search_Data = 'PO166';

EXEC dbo.web_search @PurchaseOrderNumber_Search_Data = NULL;

EXEC dbo.web_search @PurchaseOrderNumber_Search_Data = '''SELECT * FROM PERSON.PASSWORD';

