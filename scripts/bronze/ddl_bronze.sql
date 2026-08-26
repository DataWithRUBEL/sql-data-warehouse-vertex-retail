/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================

Script Purpose:
    This script creates raw landing tables in the 'bronze' schema.

Actions Performed:
    - Creates the VertexRetailDW database if it does not exist.
    - Creates bronze, silver, and gold schemas if they do not exist.
    - Drops existing Bronze tables if they already exist.
    - Creates six raw Bronze tables for CRM and ERP CSV source files.
    - Uses VARCHAR columns to preserve all incoming raw source values.

Source Tables:
    - crm_customer_master
    - crm_product_catalog
    - crm_sales_transactions
    - erp_customer_profile
    - erp_customer_location
    - erp_product_category

Execution Notes:
    - Run this script before 02_load_bronze_from_csv.sql.
    - Existing Bronze data will be deleted because tables are dropped and recreated.
===============================================================================
*/

USE master;
GO

IF DB_ID('VertexRetailDW') IS NULL
BEGIN
    CREATE DATABASE VertexRetailDW;
END;
GO

USE VertexRetailDW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA silver');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO

DROP TABLE IF EXISTS bronze.crm_customer_master;
DROP TABLE IF EXISTS bronze.crm_product_catalog;
DROP TABLE IF EXISTS bronze.crm_sales_transactions;
DROP TABLE IF EXISTS bronze.erp_customer_profile;
DROP TABLE IF EXISTS bronze.erp_customer_location;
DROP TABLE IF EXISTS bronze.erp_product_category;
GO

-- CRM: Customer master raw data
CREATE TABLE bronze.crm_customer_master
(
    cst_id              VARCHAR(50),
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(100),
    cst_lastname        VARCHAR(100),
    cst_marital_status  VARCHAR(20),
    cst_gndr            VARCHAR(20),
    cst_create_date     VARCHAR(20)
);
GO

-- CRM: Product catalog raw data
CREATE TABLE bronze.crm_product_catalog
(
    prd_id          VARCHAR(50),
    prd_key         VARCHAR(50),
    prd_nm          VARCHAR(255),
    prd_cost        VARCHAR(50),
    prd_line        VARCHAR(20),
    prd_start_dt    VARCHAR(20),
    prd_end_dt      VARCHAR(20)
);
GO

-- CRM: Sales transaction raw data
CREATE TABLE bronze.crm_sales_transactions
(
    sls_ord_num     VARCHAR(50),
    sls_prd_key     VARCHAR(50),
    sls_cust_id     VARCHAR(50),
    sls_order_dt    VARCHAR(20),
    sls_ship_dt     VARCHAR(20),
    sls_due_dt      VARCHAR(20),
    sls_sales       VARCHAR(50),
    sls_quantity    VARCHAR(50),
    sls_price       VARCHAR(50)
);
GO

-- ERP: Customer profile raw data
CREATE TABLE bronze.erp_customer_profile
(
    CID     VARCHAR(60),
    BDATE   VARCHAR(20),
    GEN     VARCHAR(20)
);
GO

-- ERP: Customer location raw data
CREATE TABLE bronze.erp_customer_location
(
    CID     VARCHAR(60),
    CNTRY   VARCHAR(100)
);
GO

-- ERP: Product category raw data
CREATE TABLE bronze.erp_product_category
(
    ID              VARCHAR(50),
    CAT             VARCHAR(100),
    SUBCAT          VARCHAR(100),
    MAINTENANCE     VARCHAR(20)
);
GO

-- Verify Bronze tables
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'bronze'
ORDER BY TABLE_NAME;
GO
