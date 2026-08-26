/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================

Script Purpose:
    This script creates cleaned and standardized Silver-layer tables.

Actions Performed:
    - Drops existing Silver tables if they already exist.
    - Creates seven Silver tables for CRM and ERP transformed data.
    - Defines appropriate data types for dates, amounts, quantities, and text.
    - Adds a data warehouse audit timestamp to every table.

Execution Notes:
    - Run after 01_create_bronze_tables.sql.
    - Run before 03_load_silver.sql.
    - Running this script deletes existing Silver-layer data.
===============================================================================
*/

USE VertexRetailDW;
GO

DROP TABLE IF EXISTS silver.crm_customer_master;
DROP TABLE IF EXISTS silver.crm_customer_master_rejected;
DROP TABLE IF EXISTS silver.crm_product_catalog;
DROP TABLE IF EXISTS silver.crm_sales_transactions;
DROP TABLE IF EXISTS silver.erp_customer_profile;
DROP TABLE IF EXISTS silver.erp_customer_location;
DROP TABLE IF EXISTS silver.erp_product_category;
GO

-- CRM: Clean customer master
CREATE TABLE silver.crm_customer_master
(
    customer_id       INT NOT NULL,
    customer_key      NVARCHAR(50) NULL,
    first_name        NVARCHAR(100) NULL,
    last_name         NVARCHAR(100) NULL,
    marital_status    NVARCHAR(20) NULL,
    gender            NVARCHAR(20) NULL,
    create_date       DATE NULL,
    dwh_create_date   DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- CRM: Invalid and duplicate customer records for audit
CREATE TABLE silver.crm_customer_master_rejected
(
    customer_id       INT NULL,
    customer_key      NVARCHAR(50) NULL,
    first_name        NVARCHAR(100) NULL,
    last_name         NVARCHAR(100) NULL,
    marital_status    NVARCHAR(20) NULL,
    gender            NVARCHAR(20) NULL,
    create_date       DATE NULL,
    rejection_reason  NVARCHAR(100) NOT NULL,
    dwh_create_date   DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- CRM: Clean product catalog
CREATE TABLE silver.crm_product_catalog
(
    product_id            INT NULL,
    product_key           NVARCHAR(50) NULL,
    product_name          NVARCHAR(255) NULL,
    product_cost          DECIMAL(12, 2) NULL,
    product_line          NVARCHAR(20) NULL,
    start_date            DATE NULL,
    end_date              DATE NULL,
    product_code          NVARCHAR(50) NULL,
    category_id           NVARCHAR(50) NULL,
    dwh_create_date       DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- CRM: Clean sales transactions
CREATE TABLE silver.crm_sales_transactions
(
    order_number        NVARCHAR(50) NULL,
    product_key         NVARCHAR(50) NULL,
    customer_id         INT NULL,
    order_date          DATE NULL,
    ship_date           DATE NULL,
    due_date            DATE NULL,
    sales_amount        DECIMAL(12, 2) NULL,
    quantity            INT NULL,
    unit_price          DECIMAL(12, 2) NULL,
    dwh_create_date     DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ERP: Clean customer profile
CREATE TABLE silver.erp_customer_profile
(
    customer_key        NVARCHAR(50) NULL,
    birth_date          DATE NULL,
    gender              NVARCHAR(20) NULL,
    dwh_create_date     DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ERP: Clean customer location
CREATE TABLE silver.erp_customer_location
(
    customer_key        NVARCHAR(50) NULL,
    country             NVARCHAR(100) NULL,
    dwh_create_date     DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ERP: Clean product category
CREATE TABLE silver.erp_product_category
(
    category_id            NVARCHAR(50) NULL,
    category               NVARCHAR(100) NULL,
    subcategory            NVARCHAR(100) NULL,
    maintenance_required   NVARCHAR(20) NULL,
    dwh_create_date        DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- Indexes for Gold-layer joins
CREATE UNIQUE CLUSTERED INDEX CX_silver_customer
    ON silver.crm_customer_master(customer_id);

CREATE INDEX IX_silver_sales_customer
    ON silver.crm_sales_transactions(customer_id);

CREATE INDEX IX_silver_sales_product
    ON silver.crm_sales_transactions(product_key);

CREATE INDEX IX_silver_product_code
    ON silver.crm_product_catalog(product_code);

CREATE INDEX IX_silver_customer_profile
    ON silver.erp_customer_profile(customer_key);

CREATE INDEX IX_silver_customer_location
    ON silver.erp_customer_location(customer_key);

CREATE INDEX IX_silver_product_category
    ON silver.erp_product_category(category_id);
GO

-- Validate created Silver tables
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'silver'
ORDER BY TABLE_NAME;
GO
