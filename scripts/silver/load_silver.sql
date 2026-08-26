/*
===============================================================================
ETL Script: Load Silver Layer
===============================================================================

Script Purpose:
    This script transforms raw Bronze data into cleaned and standardized
    Silver-layer tables.

Actions Performed:
    - Drops and recreates all Silver tables.
    - Cleans text, dates, numeric values, and business descriptions.
    - Keeps one latest valid record for each customer ID.
    - Sends invalid or duplicate customer records to a rejected table.
    - Creates indexes to improve Gold-layer join performance.

Data Quality Rules:
    - Invalid customer IDs are rejected.
    - Duplicate customer IDs retain only the latest create-date record.
    - Empty values are converted to NULL where appropriate.
    - CRM codes are standardized for ERP enrichment joins.

Execution Notes:
    - Run after 02_load_bronze_from_csv.sql.
    - Run 04_load_gold.sql after this script.
===============================================================================
*/

USE VertexRetailDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY

    BEGIN TRANSACTION;

    PRINT '================================================';
    PRINT 'Starting Silver Layer Load';
    PRINT '================================================';

    ---------------------------------------------------------------------------
    -- Step 1: Drop existing Silver tables
    ---------------------------------------------------------------------------
    DROP TABLE IF EXISTS silver.crm_customer_master;
    DROP TABLE IF EXISTS silver.crm_customer_master_rejected;
    DROP TABLE IF EXISTS silver.crm_product_catalog;
    DROP TABLE IF EXISTS silver.crm_sales_transactions;
    DROP TABLE IF EXISTS silver.erp_customer_profile;
    DROP TABLE IF EXISTS silver.erp_customer_location;
    DROP TABLE IF EXISTS silver.erp_product_category;

    ---------------------------------------------------------------------------
    -- Step 2: Clean CRM Customer Master
    -- Rule: Keep only the latest valid record for each customer_id.
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

    -- Valid and latest customer records
    SELECT
        customer_id,
        customer_key,
        first_name,
        last_name,
        marital_status,
        gender,
        create_date
    INTO silver.crm_customer_master
    FROM #customer_ranked
    WHERE customer_id IS NOT NULL
      AND record_rank = 1;

    -- Invalid or duplicate customer records for data-quality auditing
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
    INTO silver.crm_customer_master_rejected
    FROM #customer_ranked
    WHERE customer_id IS NULL
       OR record_rank > 1;

    ---------------------------------------------------------------------------
    -- Step 3: Clean CRM Product Catalog
    ---------------------------------------------------------------------------
    SELECT
        TRY_CONVERT(INT, NULLIF(TRIM(prd_id), '')) AS product_id,
        NULLIF(TRIM(prd_key), '') AS product_key,
        NULLIF(TRIM(prd_nm), '') AS product_name,
        TRY_CONVERT(DECIMAL(12, 2), NULLIF(TRIM(prd_cost), '')) AS product_cost,

        CASE TRIM(prd_line)
            WHEN 'P' THEN 'Premium'
            WHEN 'S' THEN 'Standard'
            WHEN 'E' THEN 'Economy'
            ELSE 'Unknown'
        END AS product_line,

        TRY_CONVERT(DATE, NULLIF(TRIM(prd_start_dt), '')) AS start_date,
        TRY_CONVERT(DATE, NULLIF(TRIM(prd_end_dt), '')) AS end_date,

        -- Converts catalog product key to sales-product matching key
        CONCAT('N', SUBSTRING(TRIM(prd_key), 8, 100)) AS product_code,

        -- Converts product category key for ERP category join
        REPLACE(LEFT(TRIM(prd_key), 5), '-', '_') AS category_id
    INTO silver.crm_product_catalog
    FROM bronze.crm_product_catalog;

    ---------------------------------------------------------------------------
    -- Step 4: Clean CRM Sales Transactions
    ---------------------------------------------------------------------------
    SELECT
        NULLIF(TRIM(sls_ord_num), '') AS order_number,
        NULLIF(TRIM(sls_prd_key), '') AS product_key,
        TRY_CONVERT(INT, NULLIF(TRIM(sls_cust_id), '')) AS customer_id,

        TRY_CONVERT(DATE, NULLIF(TRIM(sls_order_dt), ''), 112) AS order_date,
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_ship_dt), ''), 112) AS ship_date,
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_due_dt), ''), 112) AS due_date,

        TRY_CONVERT(DECIMAL(12, 2), NULLIF(TRIM(sls_sales), '')) AS sales_amount,
        TRY_CONVERT(INT, NULLIF(TRIM(sls_quantity), '')) AS quantity,
        TRY_CONVERT(DECIMAL(12, 2), NULLIF(TRIM(sls_price), '')) AS unit_price
    INTO silver.crm_sales_transactions
    FROM bronze.crm_sales_transactions;

    ---------------------------------------------------------------------------
    -- Step 5: Clean ERP Customer Profile
    ---------------------------------------------------------------------------
    SELECT
        TRIM(SUBSTRING(CID, 6, 60)) AS customer_key,
        TRY_CONVERT(DATE, NULLIF(TRIM(BDATE), '')) AS birth_date,

        CASE TRIM(GEN)
            WHEN 'Male' THEN 'Male'
            WHEN 'Female' THEN 'Female'
            ELSE 'Unknown'
        END AS gender
    INTO silver.erp_customer_profile
    FROM bronze.erp_customer_profile;

    ---------------------------------------------------------------------------
    -- Step 6: Clean ERP Customer Location
    ---------------------------------------------------------------------------
    SELECT
        REPLACE(TRIM(CID), '-', '') AS customer_key,
        NULLIF(TRIM(CNTRY), '') AS country
    INTO silver.erp_customer_location
    FROM bronze.erp_customer_location;

    ---------------------------------------------------------------------------
    -- Step 7: Clean ERP Product Category
    ---------------------------------------------------------------------------
    SELECT
        NULLIF(TRIM(ID), '') AS category_id,
        NULLIF(TRIM(CAT), '') AS category,
        NULLIF(TRIM(SUBCAT), '') AS subcategory,

        CASE TRIM(MAINTENANCE)
            WHEN 'Yes' THEN 'Yes'
            WHEN 'No' THEN 'No'
            ELSE 'Unknown'
        END AS maintenance_required
    INTO silver.erp_product_category
    FROM bronze.erp_product_category;

    ---------------------------------------------------------------------------
    -- Step 8: Create indexes for efficient Gold-layer joins
    ---------------------------------------------------------------------------
    CREATE UNIQUE CLUSTERED INDEX CX_silver_customer
        ON silver.crm_customer_master(customer_id);

    CREATE INDEX IX_silver_sales_customer
        ON silver.crm_sales_transactions(customer_id);

    CREATE INDEX IX_silver_sales_product
        ON silver.crm_sales_transactions(product_key);

    COMMIT TRANSACTION;

    PRINT 'Silver Layer Load Completed Successfully.';

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Silver Layer Load Failed. All changes were rolled back.';

    THROW;

END CATCH;
GO

-------------------------------------------------------------------------------
-- Step 9: Validate Silver Layer
-------------------------------------------------------------------------------

SELECT
    'silver.crm_customer_master' AS table_name,
    COUNT(*) AS total_rows
FROM silver.crm_customer_master

UNION ALL

SELECT
    'silver.crm_customer_master_rejected',
    COUNT(*)
FROM silver.crm_customer_master_rejected

UNION ALL

SELECT
    'silver.crm_product_catalog',
    COUNT(*)
FROM silver.crm_product_catalog

UNION ALL

SELECT
    'silver.crm_sales_transactions',
    COUNT(*)
FROM silver.crm_sales_transactions

UNION ALL

SELECT
    'silver.erp_customer_profile',
    COUNT(*)
FROM silver.erp_customer_profile

UNION ALL

SELECT
    'silver.erp_customer_location',
    COUNT(*)
FROM silver.erp_customer_location

UNION ALL

SELECT
    'silver.erp_product_category',
    COUNT(*)
FROM silver.erp_product_category;
GO
