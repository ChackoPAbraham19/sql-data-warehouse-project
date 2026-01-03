CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    BEGIN TRY
        --------------------------------------------------
        -- TIMERS & COUNTERS
        --------------------------------------------------
        DECLARE 
            @proc_start DATETIME,
            @proc_end   DATETIME,
            @crm_start  DATETIME,
            @crm_end    DATETIME,
            @erp_start  DATETIME,
            @erp_end    DATETIME,
            @start      DATETIME,
            @end        DATETIME,
            @rows       INT;

        SET @proc_start = GETDATE();

        PRINT '==============================================';
        PRINT '           BRONZE LAYER LOAD';
        PRINT '==============================================';

        --------------------------------------------------
        -- CRM SECTION
        --------------------------------------------------
        PRINT '********** CRM TABLES **********';
        SET @crm_start = GETDATE();

        -- crm_cust_info
        PRINT '----------------------------------------------';
        PRINT 'Truncating bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT 'Loading bronze.crm_cust_info';
        SET @start = GETDATE();
        BULK INSERT bronze.crm_cust_info
        FROM 'D:\datawarehouse\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        SET @end = GETDATE();

        SELECT @rows = COUNT(*) FROM bronze.crm_cust_info;
        PRINT 'Completed bronze.crm_cust_info | Rows: ' 
              + CAST(@rows AS NVARCHAR(10)) 
              + ' | Time: ' 
              + CAST(DATEDIFF(SECOND, @start, @end) AS NVARCHAR(10)) + ' sec';

        -- crm_prd_info
        PRINT '----------------------------------------------';
        PRINT 'Truncating bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT 'Loading bronze.crm_prd_info';
        SET @start = GETDATE();
        BULK INSERT bronze.crm_prd_info
        FROM 'D:\datawarehouse\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        SET @end = GETDATE();

        SELECT @rows = COUNT(*) FROM bronze.crm_prd_info;
        PRINT 'Completed bronze.crm_prd_info | Rows: ' 
              + CAST(@rows AS NVARCHAR(10)) 
              + ' | Time: ' 
              + CAST(DATEDIFF(SECOND, @start, @end) AS NVARCHAR(10)) + ' sec';

        -- crm_sales_details
        PRINT '----------------------------------------------';
        PRINT 'Truncating bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT 'Loading bronze.crm_sales_details';
        SET @start = GETDATE();
        BULK INSERT bronze.crm_sales_details
        FROM 'D:\datawarehouse\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        SET @end = GETDATE();

        SELECT @rows = COUNT(*) FROM bronze.crm_sales_details;
        PRINT 'Completed bronze.crm_sales_details | Rows: ' 
              + CAST(@rows AS NVARCHAR(10)) 
              + ' | Time: ' 
              + CAST(DATEDIFF(SECOND, @start, @end) AS NVARCHAR(10)) + ' sec';

        SET @crm_end = GETDATE();
        PRINT '==============================================';
        PRINT 'CRM TOTAL TIME: ' 
              + CAST(DATEDIFF(SECOND, @crm_start, @crm_end) AS NVARCHAR(10)) + ' sec';
        PRINT '==============================================';

        --------------------------------------------------
        -- ERP SECTION
        --------------------------------------------------
        PRINT '********** ERP TABLES **********';
        SET @erp_start = GETDATE();

        -- erp_cust_az12
        PRINT '----------------------------------------------';
        PRINT 'Truncating bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT 'Loading bronze.erp_cust_az12';
        SET @start = GETDATE();
        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\datawarehouse\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        SET @end = GETDATE();

        SELECT @rows = COUNT(*) FROM bronze.erp_cust_az12;
        PRINT 'Completed bronze.erp_cust_az12 | Rows: ' 
              + CAST(@rows AS NVARCHAR(10)) 
              + ' | Time: ' 
              + CAST(DATEDIFF(SECOND, @start, @end) AS NVARCHAR(10)) + ' sec';

        -- erp_loc_a101
        PRINT '----------------------------------------------';
        PRINT 'Truncating bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT 'Loading bronze.erp_loc_a101';
        SET @start = GETDATE();
        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\datawarehouse\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        SET @end = GETDATE();

        SELECT @rows = COUNT(*) FROM bronze.erp_loc_a101;
        PRINT 'Completed bronze.erp_loc_a101 | Rows: ' 
              + CAST(@rows AS NVARCHAR(10)) 
              + ' | Time: ' 
              + CAST(DATEDIFF(SECOND, @start, @end) AS NVARCHAR(10)) + ' sec';

        -- erp_px_cat_g1v2
        PRINT '----------------------------------------------';
        PRINT 'Truncating bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT 'Loading bronze.erp_px_cat_g1v2';
        SET @start = GETDATE();
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\datawarehouse\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        SET @end = GETDATE();

        SELECT @rows = COUNT(*) FROM bronze.erp_px_cat_g1v2;
        PRINT 'Completed bronze.erp_px_cat_g1v2 | Rows: ' 
              + CAST(@rows AS NVARCHAR(10)) 
              + ' | Time: ' 
              + CAST(DATEDIFF(SECOND, @start, @end) AS NVARCHAR(10)) + ' sec';

        SET @erp_end = GETDATE();
        PRINT '==============================================';
        PRINT 'ERP TOTAL TIME: ' 
              + CAST(DATEDIFF(SECOND, @erp_start, @erp_end) AS NVARCHAR(10)) + ' sec';
        PRINT '==============================================';

        --------------------------------------------------
        -- TOTAL PIPELINE TIME
        --------------------------------------------------
        SET @proc_end = GETDATE();

        PRINT '********** BRONZE LOAD COMPLETE **********';
        PRINT 'TOTAL PIPELINE TIME: ' 
              + CAST(DATEDIFF(SECOND, @proc_start, @proc_end) AS NVARCHAR(10)) + ' sec';
        PRINT '==============================================';

    END TRY
    BEGIN CATCH
        PRINT '********** ERROR OCCURRED **********';
        PRINT 'ERROR NUMBER: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        PRINT 'ERROR SEVERITY: ' + CAST(ERROR_SEVERITY() AS NVARCHAR(10));
        PRINT 'ERROR STATE: ' + CAST(ERROR_STATE() AS NVARCHAR(10));
        PRINT 'ERROR LINE: ' + CAST(ERROR_LINE() AS NVARCHAR(10));
        PRINT 'ERROR MESSAGE: ' + ERROR_MESSAGE();
    END CATCH
END
