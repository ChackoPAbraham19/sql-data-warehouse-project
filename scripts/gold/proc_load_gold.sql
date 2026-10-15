CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @start_time  DATETIME2,
        @end_time    DATETIME2,
        @proc_start  DATETIME2 = SYSDATETIME(),
        @duration_ms INT;

    /* =====================================================
       gold.dim_customers
    ===================================================== */
    BEGIN TRY
        PRINT '----------------------------------------';
        PRINT 'Loading gold.dim_customers';

        SET @start_time = SYSDATETIME();

        TRUNCATE TABLE gold.dim_customers;

        INSERT INTO gold.dim_customers (
            customer_key,
            customer_id,
            customer_number,
            first_name,
            last_name,
            country,
            marital_status,
            gender,
            birthdate,
            create_date
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY ci.cst_id),
            ci.cst_id,
            ci.cst_key,
            ci.cst_firstname,
            ci.cst_lastname,
            la.cntry,
            ci.cst_marital_status,
            CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr   -- CRM is the master source for gender
                 ELSE COALESCE(ca.gen,'n/a')
            END,
            ca.bdate,
            ci.cst_create_date
        FROM silver.crm_cust_info ci
        LEFT JOIN silver.erp_cust_az12 ca
            ON ci.cst_key = ca.cid
        LEFT JOIN silver.erp_loc_a101 la
            ON ci.cst_key = la.cid;

        SET @end_time = SYSDATETIME();
        SET @duration_ms = DATEDIFF(MILLISECOND, @start_time, @end_time);

        PRINT 'Completed gold.dim_customers';
        PRINT 'Time taken (ms): ' + CAST(@duration_ms AS VARCHAR);
    END TRY
    BEGIN CATCH
        PRINT 'Error in gold.dim_customers';
        PRINT ERROR_MESSAGE();
        PRINT 'Line: ' + CAST(ERROR_LINE() AS VARCHAR);
        THROW;
    END CATCH;


    /* =====================================================
       gold.dim_products
    ===================================================== */
    BEGIN TRY
        PRINT '----------------------------------------';
        PRINT 'Loading gold.dim_products';

        SET @start_time = SYSDATETIME();

        TRUNCATE TABLE gold.dim_products;

        INSERT INTO gold.dim_products (
            product_key,
            product_id,
            product_number,
            product_name,
            category_id,
            category,
            subcategory,
            maintenance_required,
            cost,
            product_line,
            start_date
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key),
            pn.prd_id,
            pn.prd_key,
            pn.prd_nm,
            pn.cat_id,
            pc.cat,
            pc.subcat,
            pc.maintenance,
            pn.prd_cost,
            pn.prd_line,
            pn.prd_start_dt
        FROM silver.crm_prd_info pn
        LEFT JOIN silver.erp_px_cat_g1v2 pc
            ON pn.cat_id = pc.id
        WHERE pn.prd_end_dt IS NULL;   -- current products only, drop historical versions

        SET @end_time = SYSDATETIME();
        SET @duration_ms = DATEDIFF(MILLISECOND, @start_time, @end_time);

        PRINT 'Completed gold.dim_products';
        PRINT 'Time taken (ms): ' + CAST(@duration_ms AS VARCHAR);
    END TRY
    BEGIN CATCH
        PRINT 'Error in gold.dim_products';
        PRINT ERROR_MESSAGE();
        PRINT 'Line: ' + CAST(ERROR_LINE() AS VARCHAR);
        THROW;
    END CATCH;


    /* =====================================================
       gold.fact_sales
    ===================================================== */
    BEGIN TRY
        PRINT '----------------------------------------';
        PRINT 'Loading gold.fact_sales';

        SET @start_time = SYSDATETIME();

        TRUNCATE TABLE gold.fact_sales;

        INSERT INTO gold.fact_sales (
            order_number,
            product_key,
            customer_key,
            order_date,
            shipping_date,
            due_date,
            sales_amount,
            quantity,
            price
        )
        SELECT
            sd.sls_ord_num,
            pr.product_key,
            cu.customer_key,
            sd.sls_order_dt,
            sd.sls_ship_dt,
            sd.sls_due_dt,
            sd.sls_sales,
            sd.sls_quantity,
            sd.sls_price
        FROM silver.crm_sales_details sd
        LEFT JOIN gold.dim_products pr
            ON sd.sls_prd_key = pr.product_number
        LEFT JOIN gold.dim_customers cu
            ON sd.sls_cust_id = cu.customer_id;

        SET @end_time = SYSDATETIME();
        SET @duration_ms = DATEDIFF(MILLISECOND, @start_time, @end_time);

        PRINT 'Completed gold.fact_sales';
        PRINT 'Time taken (ms): ' + CAST(@duration_ms AS VARCHAR);
    END TRY
    BEGIN CATCH
        PRINT 'Error in gold.fact_sales';
        PRINT ERROR_MESSAGE();
        PRINT 'Line: ' + CAST(ERROR_LINE() AS VARCHAR);
        THROW;
    END CATCH;


    /* =====================================================
       gold.agg_sales_monthly
    ===================================================== */
    BEGIN TRY
        PRINT '----------------------------------------';
        PRINT 'Loading gold.agg_sales_monthly';

        SET @start_time = SYSDATETIME();

        TRUNCATE TABLE gold.agg_sales_monthly;

        INSERT INTO gold.agg_sales_monthly (
            order_month,
            category,
            subcategory,
            country,
            sales_amount,
            quantity,
            order_lines
        )
        SELECT
            DATEFROMPARTS(YEAR(f.order_date), MONTH(f.order_date), 1),
            p.category,
            p.subcategory,
            c.country,
            SUM(f.sales_amount),
            SUM(f.quantity),
            COUNT(*)
        FROM gold.fact_sales f
        LEFT JOIN gold.dim_products p
            ON f.product_key = p.product_key
        LEFT JOIN gold.dim_customers c
            ON f.customer_key = c.customer_key
        GROUP BY
            DATEFROMPARTS(YEAR(f.order_date), MONTH(f.order_date), 1),
            p.category,
            p.subcategory,
            c.country;

        SET @end_time = SYSDATETIME();
        SET @duration_ms = DATEDIFF(MILLISECOND, @start_time, @end_time);

        PRINT 'Completed gold.agg_sales_monthly';
        PRINT 'Time taken (ms): ' + CAST(@duration_ms AS VARCHAR);
    END TRY
    BEGIN CATCH
        PRINT 'Error in gold.agg_sales_monthly';
        PRINT ERROR_MESSAGE();
        PRINT 'Line: ' + CAST(ERROR_LINE() AS VARCHAR);
        THROW;
    END CATCH;

    PRINT '========================================';
    PRINT 'Gold load total time (ms): '
          + CAST(DATEDIFF(MILLISECOND, @proc_start, SYSDATETIME()) AS VARCHAR);
END;
