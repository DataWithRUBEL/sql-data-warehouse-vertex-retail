/*
===============================================================================
ETL Script: Load Silver Layer
===============================================================================

Script Purpose:
    Loads cleaned and standardized data from Bronze tables into pre-created
    Silver tables.

Important:
    - Silver tables must already exist.
    - This script uses INSERT INTO; it does not create or drop Silver tables.
    - Duplicate and invalid customer records go to the rejected table.
===============================================================================
*/

USE VertexRetailDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY

    BEGIN TRANSACTION;

    PRINT 'Starting Silver Layer Load...';

    ---------------------------------------------------------------------------
    -- Step 1: Clear existing Silver data
    ---------------------------------------------------------------------------
    TRUNCATE TABLE silver.crm_customer_master;
    TRUNCATE TABLE silver.crm_customer_master_rejected;
    TRUNCATE TABLE silver.crm_product_catalog;
    TRUNCATE TABLE silver.crm_sales_transactions;
    TRUNCATE TABLE silver.erp_customer_profile;
    TRUNCATE TABLE silver.erp_customer_location;
    TRUNCATE TABLE silver.erp_product_category;

    ---------------------------------------------------------------------------
    -- Step 2: Create temporary ranked customer dataset
    ---------------------------------------------------------------------------
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY create_date DESC, customer_key DESC
        ) AS record_rank
    INTO #customer_ranked
    FROM
    (
        SELECT
            TRY_CONVERT(INT, NULLIF(TRIM(cst_id), '')) AS customer_id,
            NULLIF(TRIM(cst_key), '') AS customer_key,
            NULLIF(TRIM(cst_firstname), '') AS first_name,
            NULLIF(TRIM(cst_lastname), '') AS last_name,

            CASE TRIM(cst_marital_status)
                WHEN 'M' THEN 'Married'
                WHEN 'S' THEN 'Single'
                ELSE 'Unknown'
            END AS marital_status,

            CASE TRIM(cst_gndr)
                WHEN 'M' THEN 'Male'
                WHEN 'F' THEN 'Female'
                ELSE 'Unknown'
            END AS gender,

            TRY_CONVERT(DATE, NULLIF(TRIM(cst_create_date), '')) AS create_date
        FROM bronze.crm_customer_master
    ) AS cleaned_customers;

    ---------------------------------------------------------------------------
    -- Step 3: Load valid CRM customers
    ---------------------------------------------------------------------------
    INSERT INTO silver.crm_customer_master
    (
        customer_id,
        customer_key,
        first_name,
        last_name,
        marital_status,
        gender,
        create_date
    )
    SELECT
        customer_id,
        customer_key,
        first_name,
        last_name,
        marital_status,
        gender,
        create_date
    FROM #customer_ranked
    WHERE customer_id IS NOT NULL
      AND record_rank = 1;

    ---------------------------------------------------------------------------
    -- Step 4: Load rejected CRM customers
    ---------------------------------------------------------------------------
    INSERT INTO silver.crm_customer_master_rejected
    (
        customer_id,
        customer_key,
        first_name,
        last_name,
        marital_status,
        gender,
        create_date,
        rejection_reason
    )
    SELECT
        customer_id,
        customer_key,
        first_name,
        last_name,
        marital_status,
        gender,
        create_date,

        CASE
            WHEN customer_id IS NULL
                THEN 'Invalid or missing customer ID'
            ELSE 'Duplicate customer ID - non-current record'
        END AS rejection_reason
    FROM #customer_ranked
    WHERE customer_id IS NULL
       OR record_rank > 1;

    ---------------------------------------------------------------------------
    -- Step 5: Load CRM products
    ---------------------------------------------------------------------------
    INSERT INTO silver.crm_product_catalog
    (
        product_id,
        product_key,
        product_name,
        product_cost,
        product_line,
        start_date,
        end_date,
        product_code,
        category_id
    )
    SELECT
        TRY_CONVERT(INT, NULLIF(TRIM(prd_id), '')),
        NULLIF(TRIM(prd_key), ''),
        NULLIF(TRIM(prd_nm), ''),
        TRY_CONVERT(DECIMAL(12, 2), NULLIF(TRIM(prd_cost), '')),

        CASE TRIM(prd_line)
            WHEN 'P' THEN 'Premium'
            WHEN 'S' THEN 'Standard'
            WHEN 'E' THEN 'Economy'
            ELSE 'Unknown'
        END,

        TRY_CONVERT(DATE, NULLIF(TRIM(prd_start_dt), '')),
        TRY_CONVERT(DATE, NULLIF(TRIM(prd_end_dt), '')),

        CONCAT('N', SUBSTRING(TRIM(prd_key), 8, 100)),
        REPLACE(LEFT(TRIM(prd_key), 5), '-', '_')
    FROM bronze.crm_product_catalog;

    ---------------------------------------------------------------------------
    -- Step 6: Load CRM sales transactions
    ---------------------------------------------------------------------------
    INSERT INTO silver.crm_sales_transactions
    (
        order_number,
        product_key,
        customer_id,
        order_date,
        ship_date,
        due_date,
        sales_amount,
        quantity,
        unit_price
    )
    SELECT
        NULLIF(TRIM(sls_ord_num), ''),
        NULLIF(TRIM(sls_prd_key), ''),
        TRY_CONVERT(INT, NULLIF(TRIM(sls_cust_id), '')),
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_order_dt), ''), 112),
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_ship_dt), ''), 112),
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_due_dt), ''), 112),
        TRY_CONVERT(DECIMAL(12, 2), NULLIF(TRIM(sls_sales), '')),
        TRY_CONVERT(INT, NULLIF(TRIM(sls_quantity), '')),
        TRY_CONVERT(DECIMAL(12, 2), NULLIF(TRIM(sls_price), ''))
    FROM bronze.crm_sales_transactions;

    ---------------------------------------------------------------------------
    -- Step 7: Load ERP customer profiles
    ---------------------------------------------------------------------------
    INSERT INTO silver.erp_customer_profile
    (
        customer_key,
        birth_date,
        gender
    )
    SELECT
        TRIM(SUBSTRING(CID, 6, 60)),
        TRY_CONVERT(DATE, NULLIF(TRIM(BDATE), '')),

        CASE TRIM(GEN)
            WHEN 'Male' THEN 'Male'
            WHEN 'Female' THEN 'Female'
            ELSE 'Unknown'
        END
    FROM bronze.erp_customer_profile;

    ---------------------------------------------------------------------------
    -- Step 8: Load ERP customer locations
    ---------------------------------------------------------------------------
    INSERT INTO silver.erp_customer_location
    (
        customer_key,
        country
    )
    SELECT
        REPLACE(TRIM(CID), '-', ''),
        NULLIF(TRIM(CNTRY), '')
    FROM bronze.erp_customer_location;

    ---------------------------------------------------------------------------
    -- Step 9: Load ERP product categories
    ---------------------------------------------------------------------------
    INSERT INTO silver.erp_product_category
    (
        category_id,
        category,
        subcategory,
        maintenance_required
    )
    SELECT
        NULLIF(TRIM(ID), ''),
        NULLIF(TRIM(CAT), ''),
        NULLIF(TRIM(SUBCAT), ''),

        CASE TRIM(MAINTENANCE)
            WHEN 'Yes' THEN 'Yes'
            WHEN 'No' THEN 'No'
            ELSE 'Unknown'
        END
    FROM bronze.erp_product_category;

    COMMIT TRANSACTION;

    PRINT 'Silver Layer Load Completed Successfully.';

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Silver Layer Load Failed.';

    THROW;

END CATCH;
GO

-- Validate Silver layer row counts
SELECT 'crm_customer_master' AS table_name, COUNT(*) AS total_rows
FROM silver.crm_customer_master

UNION ALL

SELECT 'crm_customer_master_rejected', COUNT(*)
FROM silver.crm_customer_master_rejected

UNION ALL

SELECT 'crm_product_catalog', COUNT(*)
FROM silver.crm_product_catalog

UNION ALL

SELECT 'crm_sales_transactions', COUNT(*)
FROM silver.crm_sales_transactions

UNION ALL

SELECT 'erp_customer_profile', COUNT(*)
FROM silver.erp_customer_profile

UNION ALL

SELECT 'erp_customer_location', COUNT(*)
FROM silver.erp_customer_location

UNION ALL

SELECT 'erp_product_category', COUNT(*)
FROM silver.erp_product_category;
GO
