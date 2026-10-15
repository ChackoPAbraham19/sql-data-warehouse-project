/*
===============================================================================
Purpose     : Benchmark harness comparing reporting queries against
              - baseline : the original view-based Gold layer (joins computed
                           on every read from Silver), recreated in schema bench
              - gold     : the materialized, indexed Gold tables + agg table

Objects     :
- bench.dim_customers / bench.dim_products / bench.fact_sales  (baseline views)
- bench.queries          the business questions, one row per (query, variant)
- bench.results          raw timings, one row per execution
- bench.check_results    verifies baseline and gold return identical results
- bench.run_benchmark    times every query, @iterations times each
- bench.summary          median/avg per query and % reduction

Usage       :
    EXEC silver.load_silver;  EXEC gold.load_gold;   -- data must be loaded
    EXEC bench.check_results;                       -- must be all PASS
    EXEC bench.run_benchmark @iterations = 30;      -- prints summary
===============================================================================
*/

USE DataWarehouse;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bench')
    EXEC ('CREATE SCHEMA bench');
GO


/* =====================================================
   Baseline: the original Gold views, unchanged logic
===================================================== */
CREATE OR ALTER VIEW bench.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id             AS customer_id,
    ci.cst_key            AS customer_number,
    ci.cst_firstname      AS first_name,
    ci.cst_lastname       AS last_name,
    la.cntry              AS country,
    ci.cst_marital_status AS marital_status,
    CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
         ELSE COALESCE(ca.gen,'n/a')
    END                   AS gender,
    ca.bdate              AS birthdate,
    ci.cst_create_date    AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid;
GO

CREATE OR ALTER VIEW bench.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
    pn.prd_id       AS product_id,
    pn.prd_key      AS product_number,
    pn.prd_nm       AS product_name,
    pn.cat_id       AS category_id,
    pc.cat          AS category,
    pc.subcat       AS subcategory,
    pc.maintenance  AS maintenance_required,
    pn.prd_cost     AS cost,
    pn.prd_line     AS product_line,
    pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;
GO

CREATE OR ALTER VIEW bench.fact_sales AS
SELECT
    sd.sls_ord_num  AS order_number,
    pr.product_key,
    cu.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt  AS shipping_date,
    sd.sls_due_dt   AS due_date,
    sd.sls_sales    AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price    AS price
FROM silver.crm_sales_details sd
LEFT JOIN bench.dim_products pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN bench.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
GO


/* =====================================================
   Query catalog
   Each query_id has a baseline and a gold variant that answer the same
   question with identical output columns (checked by bench.check_results).
===================================================== */
IF OBJECT_ID('bench.queries','U') IS NOT NULL DROP TABLE bench.queries;
GO

CREATE TABLE bench.queries (
    query_id INT           NOT NULL,
    name     NVARCHAR(100) NOT NULL,
    variant  VARCHAR(10)   NOT NULL,   -- 'baseline' | 'gold'
    sql_text NVARCHAR(MAX) NOT NULL,
    PRIMARY KEY (query_id, variant)
);
GO

INSERT INTO bench.queries (query_id, name, variant, sql_text) VALUES
-- Q1: monthly revenue trend
(1, N'Monthly revenue trend', 'baseline', N'
SELECT DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
       SUM(sales_amount) AS sales_amount,
       SUM(quantity)     AS quantity
FROM bench.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)'),
(1, N'Monthly revenue trend', 'gold', N'
SELECT order_month,
       SUM(sales_amount) AS sales_amount,
       SUM(quantity)     AS quantity
FROM gold.agg_sales_monthly
WHERE order_month IS NOT NULL
GROUP BY order_month'),

-- Q2: revenue by country
(2, N'Revenue by country', 'baseline', N'
SELECT c.country,
       SUM(f.sales_amount) AS sales_amount
FROM bench.fact_sales f
LEFT JOIN bench.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.country'),
(2, N'Revenue by country', 'gold', N'
SELECT country,
       SUM(sales_amount) AS sales_amount
FROM gold.agg_sales_monthly
GROUP BY country'),

-- Q3: revenue by category / subcategory
(3, N'Revenue by category and subcategory', 'baseline', N'
SELECT p.category,
       p.subcategory,
       SUM(f.sales_amount) AS sales_amount,
       SUM(f.quantity)     AS quantity
FROM bench.fact_sales f
LEFT JOIN bench.dim_products p
    ON f.product_key = p.product_key
GROUP BY p.category, p.subcategory'),
(3, N'Revenue by category and subcategory', 'gold', N'
SELECT category,
       subcategory,
       SUM(sales_amount) AS sales_amount,
       SUM(quantity)     AS quantity
FROM gold.agg_sales_monthly
GROUP BY category, subcategory'),

-- Q4: top 10 customers by revenue (customer grain, so uses the fact table, not the agg)
(4, N'Top 10 customers by revenue', 'baseline', N'
SELECT TOP 10
       c.customer_key,
       c.first_name,
       c.last_name,
       SUM(f.sales_amount) AS sales_amount
FROM bench.fact_sales f
JOIN bench.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY SUM(f.sales_amount) DESC, c.customer_key'),
(4, N'Top 10 customers by revenue', 'gold', N'
SELECT TOP 10
       c.customer_key,
       c.first_name,
       c.last_name,
       SUM(f.sales_amount) AS sales_amount
FROM gold.fact_sales f
JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY SUM(f.sales_amount) DESC, c.customer_key');
GO


/* =====================================================
   Results table
===================================================== */
IF OBJECT_ID('bench.results','U') IS NULL
BEGIN
    CREATE TABLE bench.results (
        run_id     INT         NOT NULL,
        run_at     DATETIME2   NOT NULL,
        cold_cache BIT         NOT NULL,
        query_id   INT         NOT NULL,
        variant    VARCHAR(10) NOT NULL,
        iteration  INT         NOT NULL,
        elapsed_us BIGINT      NOT NULL
    );
END
GO


/* =====================================================
   bench.check_results
   A speed-up only counts if both variants return the same rows.
===================================================== */
CREATE OR ALTER PROCEDURE bench.check_results
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @query_id INT,
        @name     NVARCHAR(100),
        @base     NVARCHAR(MAX),
        @gold     NVARCHAR(MAX),
        @sql      NVARCHAR(MAX),
        @diff     INT,
        @rows     INT;

    DECLARE q CURSOR LOCAL FAST_FORWARD FOR
        SELECT b.query_id, b.name, b.sql_text, g.sql_text
        FROM bench.queries b
        JOIN bench.queries g
            ON g.query_id = b.query_id AND g.variant = 'gold'
        WHERE b.variant = 'baseline'
        ORDER BY b.query_id;

    OPEN q;
    FETCH NEXT FROM q INTO @query_id, @name, @base, @gold;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'
            SELECT @diff = COUNT(*) FROM (
                (SELECT * FROM (' + @base + N') b EXCEPT SELECT * FROM (' + @gold + N') g)
                UNION ALL
                (SELECT * FROM (' + @gold + N') g EXCEPT SELECT * FROM (' + @base + N') b)
            ) x;
            SELECT @rows = COUNT(*) FROM (' + @base + N') b;';

        EXEC sp_executesql @sql, N'@diff INT OUTPUT, @rows INT OUTPUT',
             @diff = @diff OUTPUT, @rows = @rows OUTPUT;

        PRINT 'Q' + CAST(@query_id AS VARCHAR) + ' ' + @name + ': '
              + CASE WHEN @diff = 0 THEN 'PASS' ELSE 'FAIL' END
              + ' (' + CAST(@rows AS VARCHAR) + ' rows, '
              + CAST(@diff AS VARCHAR) + ' differing)';

        FETCH NEXT FROM q INTO @query_id, @name, @base, @gold;
    END

    CLOSE q;
    DEALLOCATE q;
END;
GO


/* =====================================================
   bench.summary
===================================================== */
CREATE OR ALTER PROCEDURE bench.summary
    @run_id INT = NULL   -- default: latest run
AS
BEGIN
    SET NOCOUNT ON;

    IF @run_id IS NULL
        SELECT @run_id = MAX(run_id) FROM bench.results;

    WITH medians AS (
        SELECT DISTINCT
            query_id,
            variant,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY elapsed_us)
                OVER (PARTITION BY query_id, variant) AS median_us,
            AVG(CAST(elapsed_us AS FLOAT))
                OVER (PARTITION BY query_id, variant) AS avg_us,
            COUNT(*)
                OVER (PARTITION BY query_id, variant) AS runs
        FROM bench.results
        WHERE run_id = @run_id
    ),
    per_query AS (
        SELECT
            b.query_id,
            q.name,
            b.runs,
            b.median_us AS baseline_median_us,
            g.median_us AS gold_median_us,
            b.avg_us    AS baseline_avg_us,
            g.avg_us    AS gold_avg_us
        FROM medians b
        JOIN medians g
            ON g.query_id = b.query_id AND g.variant = 'gold'
        JOIN bench.queries q
            ON q.query_id = b.query_id AND q.variant = 'baseline'
        WHERE b.variant = 'baseline'
    )
    SELECT
        @run_id                                   AS run_id,
        CAST(query_id AS VARCHAR(10))             AS query_id,
        name,
        runs,
        CAST(baseline_median_us / 1000.0 AS DECIMAL(10,3)) AS baseline_median_ms,
        CAST(gold_median_us     / 1000.0 AS DECIMAL(10,3)) AS gold_median_ms,
        CAST(baseline_avg_us    / 1000.0 AS DECIMAL(10,3)) AS baseline_avg_ms,
        CAST(gold_avg_us        / 1000.0 AS DECIMAL(10,3)) AS gold_avg_ms,
        CAST(100.0 * (1 - gold_median_us / NULLIF(baseline_median_us,0)) AS DECIMAL(5,1))
                                                  AS pct_reduction_median
    FROM per_query

    UNION ALL

    -- Whole workload: sum of per-query medians
    SELECT
        @run_id,
        'ALL',
        N'All queries (sum of medians)',
        MIN(runs),
        CAST(SUM(baseline_median_us) / 1000.0 AS DECIMAL(10,3)),
        CAST(SUM(gold_median_us)     / 1000.0 AS DECIMAL(10,3)),
        CAST(SUM(baseline_avg_us)    / 1000.0 AS DECIMAL(10,3)),
        CAST(SUM(gold_avg_us)        / 1000.0 AS DECIMAL(10,3)),
        CAST(100.0 * (1 - SUM(gold_median_us) / NULLIF(SUM(baseline_median_us),0)) AS DECIMAL(5,1))
    FROM per_query

    ORDER BY query_id;
END;
GO


/* =====================================================
   bench.run_benchmark
   - Iteration 0 is a warm-up (plan compilation, page loads) and is not recorded
   - Baseline and gold variants are interleaved within each iteration so
     background noise affects both equally
   - Each query's output goes into a temp table so the full result is
     computed but not streamed to the client
   - @cold_cache = 1 flushes the buffer pool before every execution
     (needs sysadmin; only on a dev/test instance)
===================================================== */
CREATE OR ALTER PROCEDURE bench.run_benchmark
    @iterations INT = 30,
    @cold_cache BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @run_id   INT = ISNULL((SELECT MAX(run_id) FROM bench.results), 0) + 1,
        @run_at   DATETIME2 = SYSDATETIME(),
        @i        INT = 0,
        @q        INT,
        @n        INT,
        @query_id INT,
        @variant  VARCHAR(10),
        @sql      NVARCHAR(MAX),
        @t0       DATETIME2(7),
        @t1       DATETIME2(7);

    DECLARE @queue TABLE (
        seq      INT IDENTITY(1,1),
        query_id INT,
        variant  VARCHAR(10),
        sql_text NVARCHAR(MAX)
    );

    INSERT INTO @queue (query_id, variant, sql_text)
    SELECT query_id, variant, sql_text
    FROM bench.queries
    ORDER BY query_id, variant;

    SELECT @n = COUNT(*) FROM @queue;

    PRINT 'Benchmark run ' + CAST(@run_id AS VARCHAR) + ': '
          + CAST(@iterations AS VARCHAR) + ' iterations, cold_cache = '
          + CAST(@cold_cache AS VARCHAR);

    WHILE @i <= @iterations
    BEGIN
        SET @q = 1;

        WHILE @q <= @n
        BEGIN
            SELECT
                @query_id = query_id,
                @variant  = variant,
                @sql      = N'SELECT * INTO #r FROM (' + sql_text + N') q; DROP TABLE #r;'
            FROM @queue
            WHERE seq = @q;

            IF @cold_cache = 1
            BEGIN
                CHECKPOINT;
                DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
            END

            SET @t0 = SYSDATETIME();
            EXEC sp_executesql @sql;
            SET @t1 = SYSDATETIME();

            IF @i > 0
                INSERT INTO bench.results
                    (run_id, run_at, cold_cache, query_id, variant, iteration, elapsed_us)
                VALUES
                    (@run_id, @run_at, @cold_cache, @query_id, @variant, @i,
                     DATEDIFF(MICROSECOND, @t0, @t1));

            SET @q += 1;
        END

        SET @i += 1;
    END

    EXEC bench.summary @run_id;
END;
GO
