/*
===============================================================================
Purpose     : Shows logical reads and CPU time for every benchmark query, so
              you can explain WHY the gold variant is faster (fewer pages read,
              fewer joins), not just that it is.

Usage       : Run in SSMS / Azure Data Studio and read the Messages tab.
              Turn on "Include Actual Execution Plan" (Ctrl+M) to compare plans.
===============================================================================
*/

USE DataWarehouse;
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE
    @name    NVARCHAR(100),
    @variant VARCHAR(10),
    @sql     NVARCHAR(MAX);

DECLARE q CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        name,
        variant,
        N'SELECT * INTO #r FROM (' + sql_text + N') q; DROP TABLE #r;'
    FROM bench.queries
    ORDER BY query_id, variant;

OPEN q;
FETCH NEXT FROM q INTO @name, @variant, @sql;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '';
    PRINT '==================== ' + @name + ' [' + @variant + '] ====================';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM q INTO @name, @variant, @sql;
END

CLOSE q;
DEALLOCATE q;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
