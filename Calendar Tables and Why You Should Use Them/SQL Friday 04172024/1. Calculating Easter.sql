
/*********************************************************************************
					Calculating Easter
*********************************************************************************/
-- This can be done on the fly using Gauss's Easter Algorithm (ref: https://en.wikipedia.org/wiki/Computus)
DECLARE @year SMALLINT = 2024;
DECLARE @a TINYINT = @year % 19;
DECLARE @b TINYINT = @year % 4;
DECLARE @c TINYINT = @year % 7;
DECLARE @k SMALLINT = @year / 100;
DECLARE @p SMALLINT = (13 + (8 * @k)) / 25;
DECLARE @q SMALLINT = @year / 400;
DECLARE @M TINYINT = (15 - @p + @k - @q) % 30;
DECLARE @N TINYINT = (4 + @k - @q) % 7;
DECLARE @d TINYINT = (19 * @a + @M) % 30;
DECLARE @e TINYINT = (2 * @b + 4 * @c + 6 * @d + @N) % 7;
DECLARE @march_easter TINYINT = 22 + @d + @e;
DECLARE @april_easter TINYINT = @d + @e -9;
IF @d = 29 AND @e = 6
	SELECT @april_easter = 19;
IF @d = 28 AND @e = 6 AND ((11 * @M + 11) % 30) < 19
	SELECT @april_easter = 18;
DECLARE @gregorian_easter TINYINT = 
	CASE
		WHEN @april_easter BETWEEN 1 AND 30 THEN @april_easter
		ELSE @march_easter
	END;
SELECT 
	CASE
		WHEN @april_easter BETWEEN 1 AND 30 THEN 'April'
		ELSE 'March'
	END, @gregorian_easter;
GO


IF EXISTS (SELECT * FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND objects.name = 'fnEasterSunday')
BEGIN
	DROP FUNCTION dbo.fnEasterSunday;
END
GO

CREATE FUNCTION dbo.fnEasterSunday(@year smallint)
    RETURNS DATE
AS
BEGIN
    DECLARE @a SMALLINT, @b SMALLINT, @c SMALLINT, @d SMALLINT, @e SMALLINT, @o SMALLINT, @N SMALLINT, @M SMALLINT, @H1 SMALLINT, @H2 SMALLINT;

    SELECT @a  = @year % 19;
    SELECT @b  = @year % 4;
    SELECT @c  = @year % 7
    SELECT @H1 = @year / 100;
    SELECT @H2 = @year / 400;
    SELECT @N = 4 + @H1 - @H2;
    SELECT @M = 15 + @H1 - @H2 - ((8 * @H1 + 13) / 25);
    SELECT @d = (19 * @a + @M) % 30;
    SELECT @e = (2 * @b + 4 * @c + 6 * @d + @N) % 7;
    SELECT @o = 22 + @d + @e;
 
    -- Exceptions from the base rule.
    IF @o = 57
        SET @o = 50;
    IF (@d = 28) AND (@e = 6) AND (@a > 10) 
        SET @o = 49;
    
    RETURN(DATEADD(DAY, @o - 1, CONVERT(DATETIME, CONVERT(CHAR(4), @year) + '0301', 112)));
END;
GO

SELECT dbo.fnEasterSunday(2012);
GO
SELECT dbo.fnEasterSunday(2024);
GO
SELECT dbo.fnEasterSunday(2058);
GO
