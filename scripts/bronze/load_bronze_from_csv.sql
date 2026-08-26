/*
===============================================================================
ETL Script: Load Bronze Layer from CSV Files
===============================================================================

Script Purpose:
    This script loads raw CRM and ERP data from CSV files into Bronze tables
    using SQL Server BULK INSERT.

Actions Performed:
    - Truncates existing data from Bronze tables.
    - Imports six CSV files from the local laptop folder.
    - Loads data inside a transaction.
    - Rolls back all changes if any CSV import fails.
    - Displays final row counts for validation.

Source Folder:
    C:\sql_server_retail_dw\datasets\

Required CSV Files:
    - crm_customer_master.csv
    - crm_product_catalog.csv
    - crm_sales_transactions.csv
    - erp_customer_profile.csv
    - erp_customer_location.csv
    - erp_product_category.csv

Execution Notes:
    - Run 01_create_bronze_tables.sql before this script.
    - SQL Server service account needs Read permission on the dataset folder.
    - Change the file paths below if your CSV files are in another folder.
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
    PRINT 'Starting Bronze Layer Load';
    PRINT '================================================';

    ---------------------------------------------------------------------------
    -- Step 1: Clear existing raw data
    ---------------------------------------------------------------------------
    TRUNCATE TABLE bronze.crm_customer_master;
    TRUNCATE TABLE bronze.crm_product_catalog;
    TRUNCATE TABLE bronze.crm_sales_transactions;
    TRUNCATE TABLE bronze.erp_customer_profile;
    TRUNCATE TABLE bronze.erp_customer_location;
    TRUNCATE TABLE bronze.erp_product_category;

    ---------------------------------------------------------------------------
    -- Step 2: Load CRM Customer Master
    ---------------------------------------------------------------------------
    BULK INSERT bronze.crm_customer_master
    FROM 'C:\sql_server_retail_dw\datasets\crm_customer_master.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        TABLOCK
    );

    ---------------------------------------------------------------------------
    -- Step 3: Load CRM Product Catalog
    ---------------------------------------------------------------------------
    BULK INSERT bronze.crm_product_catalog
    FROM 'C:\sql_server_retail_dw\datasets\crm_product_catalog.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        TABLOCK
    );

    ---------------------------------------------------------------------------
    -- Step 4: Load CRM Sales Transactions
    ---------------------------------------------------------------------------
    BULK INSERT bronze.crm_sales_transactions
    FROM 'C:\sql_server_retail_dw\datasets\crm_sales_transactions.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        TABLOCK
    );

    ---------------------------------------------------------------------------
    -- Step 5: Load ERP Customer Profile
    ---------------------------------------------------------------------------
    BULK INSERT bronze.erp_customer_profile
    FROM 'C:\sql_server_retail_dw\datasets\erp_customer_profile.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        TABLOCK
    );

    ---------------------------------------------------------------------------
    -- Step 6: Load ERP Customer Location
    ---------------------------------------------------------------------------
    BULK INSERT bronze.erp_customer_location
    FROM 'C:\sql_server_retail_dw\datasets\erp_customer_location.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        TABLOCK
    );

    ---------------------------------------------------------------------------
    -- Step 7: Load ERP Product Category
    ---------------------------------------------------------------------------
    BULK INSERT bronze.erp_product_category
    FROM 'C:\sql_server_retail_dw\datasets\erp_product_category.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        TABLOCK
    );

    COMMIT TRANSACTION;

    PRINT 'Bronze Layer Load Completed Successfully.';

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Bronze Layer Load Failed. All changes were rolled back.';

    THROW;

END CATCH;
GO

-------------------------------------------------------------------------------
-- Step 8: Validate loaded row counts
-------------------------------------------------------------------------------
SELECT 'crm_customer_master' AS table_name, COUNT(*) AS total_rows
FROM bronze.crm_customer_master

UNION ALL

SELECT 'crm_product_catalog', COUNT(*)
FROM bronze.crm_product_catalog

UNION ALL

SELECT 'crm_sales_transactions', COUNT(*)
FROM bronze.crm_sales_transactions

UNION ALL

SELECT 'erp_customer_profile', COUNT(*)
FROM bronze.erp_customer_profile

UNION ALL

SELECT 'erp_customer_location', COUNT(*)
FROM bronze.erp_customer_location

UNION ALL

SELECT 'erp_product_category', COUNT(*)
FROM bronze.erp_product_category;
GO
