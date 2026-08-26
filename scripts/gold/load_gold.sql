/*
===============================================================================
ETL Script: Load Gold Layer
===============================================================================

Script Purpose:
    Builds the reporting-ready Gold layer using a star-schema design.

Tables Created:
    - gold.dim_customers
    - gold.dim_products
    - gold.dim_date
    - gold.fact_sales
    - gold.vw_sales_analysis

Data Quality Rules:
    - Latest product version is retained for each product code.
    - Missing order dates use the Unknown Date member with date_key = -1.
    - Fact table joins only valid customers and products.
===============================================================================
*/

USE VertexRetailDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY

    BEGIN TRANSACTION;

    PRINT 'Starting Gold Layer Load...';

    ---------------------------------------------------------------------------
    -- Step 1: Drop existing Gold objects
    ---------------------------------------------------------------------------
    DROP VIEW IF EXISTS gold.vw_sales_analysis;

    DROP TABLE IF EXISTS gold.fact_sales;
    DROP TABLE IF EXISTS gold.dim_date;
    DROP TABLE IF EXISTS gold.dim_products;
    DROP TABLE IF EXISTS gold.dim_customers;

    ---------------------------------------------------------------------------
    -- Step 2: Create Customer Dimension
    ---------------------------------------------------------------------------
    CREATE TABLE gold.dim_customers
    (
        customer_key        INT IDENTITY(1,1) PRIMARY KEY,
        customer_id         INT NOT NULL UNIQUE,
        customer_code       NVARCHAR(50) NOT NULL,
        customer_name       NVARCHAR(205) NOT NULL,
        marital_status      NVARCHAR(20) NULL,
        gender              NVARCHAR(20) NULL,
        birth_date          DATE NULL,
        country             NVARCHAR(100) NULL,
        create_date         DATE NULL,
        dwh_create_date     DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    INSERT INTO gold.dim_customers
    (
        customer_id,
        customer_code,
        customer_name,
        marital_status,
        gender,
        birth_date,
        country,
        create_date
    )
    SELECT
        c.customer_id,
        c.customer_key,
        CONCAT(c.first_name, ' ', c.last_name),
        c.marital_status,
        COALESCE(p.gender, c.gender),
        p.birth_date,
        l.country,
        c.create_date
    FROM silver.crm_customer_master AS c
    LEFT JOIN silver.erp_customer_profile AS p
        ON p.customer_key = c.customer_key
    LEFT JOIN silver.erp_customer_location AS l
        ON l.customer_key = c.customer_key;

    ---------------------------------------------------------------------------
    -- Step 3: Create Product Dimension
    ---------------------------------------------------------------------------
    CREATE TABLE gold.dim_products
    (
        product_key             INT IDENTITY(1,1) PRIMARY KEY,
        product_id              INT NOT NULL,
        product_code            NVARCHAR(50) NOT NULL UNIQUE,
        product_name            NVARCHAR(255) NULL,
        product_cost            DECIMAL(12, 2) NULL,
        product_line            NVARCHAR(20) NULL,
        category                NVARCHAR(100) NULL,
        subcategory             NVARCHAR(100) NULL,
        maintenance_required    NVARCHAR(20) NULL,
        start_date              DATE NULL,
        end_date                DATE NULL,
        dwh_create_date         DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    -- Keep the latest version of each sales product code.
    ;WITH latest_product AS
    (
        SELECT
            *,
            ROW_NUMBER() OVER
            (
                PARTITION BY product_code
                ORDER BY start_date DESC, product_id DESC
            ) AS record_rank
        FROM silver.crm_product_catalog
    )
    INSERT INTO gold.dim_products
    (
        product_id,
        product_code,
        product_name,
        product_cost,
        product_line,
        category,
        subcategory,
        maintenance_required,
        start_date,
        end_date
    )
    SELECT
        p.product_id,
        p.product_code,
        p.product_name,
        p.product_cost,
        p.product_line,
        c.category,
        c.subcategory,
        c.maintenance_required,
        p.start_date,
        p.end_date
    FROM latest_product AS p
    LEFT JOIN silver.erp_product_category AS c
        ON c.category_id = p.category_id
    WHERE p.record_rank = 1;

    ---------------------------------------------------------------------------
    -- Step 4: Create Date Dimension
    ---------------------------------------------------------------------------
    CREATE TABLE gold.dim_date
    (
        date_key            INT NOT NULL PRIMARY KEY,
        full_date           DATE NOT NULL UNIQUE,
        calendar_year       SMALLINT NOT NULL,
        calendar_month      TINYINT NOT NULL,
        month_name          NVARCHAR(12) NOT NULL,
        quarter_number      TINYINT NOT NULL,
        dwh_create_date     DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    -- Unknown date member: used when a sales record has no order date.
    INSERT INTO gold.dim_date
    (
        date_key,
        full_date,
        calendar_year,
        calendar_month,
        month_name,
        quarter_number
    )
    VALUES
    (
        -1,
        '1900-01-01',
        1900,
        0,
        'Unknown',
        0
    );

    -- Load distinct valid order dates from sales.
    INSERT INTO gold.dim_date
    (
        date_key,
        full_date,
        calendar_year,
        calendar_month,
        month_name,
        quarter_number
    )
    SELECT DISTINCT
        CONVERT(INT, CONVERT(CHAR(8), order_date, 112)),
        order_date,
        YEAR(order_date),
        MONTH(order_date),
        DATENAME(MONTH, order_date),
        DATEPART(QUARTER, order_date)
    FROM silver.crm_sales_transactions
    WHERE order_date IS NOT NULL;

    ---------------------------------------------------------------------------
    -- Step 5: Create Sales Fact Table
    ---------------------------------------------------------------------------
    CREATE TABLE gold.fact_sales
    (
        sales_key           BIGINT IDENTITY(1,1) PRIMARY KEY,
        order_number        NVARCHAR(50) NOT NULL,
        order_date_key      INT NOT NULL,
        ship_date_key       INT NULL,
        due_date_key        INT NULL,
        customer_key        INT NOT NULL,
        product_key         INT NOT NULL,
        sales_amount        DECIMAL(12, 2) NOT NULL,
        quantity            INT NOT NULL,
        unit_price          DECIMAL(12, 2) NOT NULL,
        dwh_create_date     DATETIME2 NOT NULL DEFAULT GETDATE(),

        CONSTRAINT FK_fact_sales_order_date
            FOREIGN KEY (order_date_key)
            REFERENCES gold.dim_date(date_key),

        CONSTRAINT FK_fact_sales_customer
            FOREIGN KEY (customer_key)
            REFERENCES gold.dim_customers(customer_key),

        CONSTRAINT FK_fact_sales_product
            FOREIGN KEY (product_key)
            REFERENCES gold.dim_products(product_key)
    );

    INSERT INTO gold.fact_sales
    (
        order_number,
        order_date_key,
        ship_date_key,
        due_date_key,
        customer_key,
        product_key,
        sales_amount,
        quantity,
        unit_price
    )
    SELECT
        s.order_number,

        COALESCE
        (
            CONVERT(INT, CONVERT(CHAR(8), s.order_date, 112)),
            -1
        ) AS order_date_key,

        CONVERT(INT, CONVERT(CHAR(8), s.ship_date, 112)) AS ship_date_key,
        CONVERT(INT, CONVERT(CHAR(8), s.due_date, 112)) AS due_date_key,

        c.customer_key,
        p.product_key,
        s.sales_amount,
        s.quantity,
        s.unit_price
    FROM silver.crm_sales_transactions AS s
    INNER JOIN gold.dim_customers AS c
        ON c.customer_id = s.customer_id
    INNER JOIN gold.dim_products AS p
        ON p.product_code = s.product_key;

    ---------------------------------------------------------------------------
    -- Step 6: Create performance indexes
    ---------------------------------------------------------------------------
    CREATE INDEX IX_fact_sales_order_date
        ON gold.fact_sales(order_date_key);

    CREATE INDEX IX_fact_sales_customer
        ON gold.fact_sales(customer_key);

    CREATE INDEX IX_fact_sales_product
        ON gold.fact_sales(product_key);

    COMMIT TRANSACTION;

    PRINT 'Gold Layer Load Completed Successfully.';

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Gold Layer Load Failed.';

    THROW;

END CATCH;
GO

-------------------------------------------------------------------------------
-- Step 7: Create reporting view for Power BI
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_sales_analysis
AS
SELECT
    f.order_number,
    d.full_date AS order_date,
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    d.quarter_number,

    c.customer_name,
    c.country,
    c.gender,

    p.product_name,
    p.category,
    p.subcategory,
    p.product_line,

    f.quantity,
    f.unit_price,
    f.sales_amount
FROM gold.fact_sales AS f
INNER JOIN gold.dim_date AS d
    ON d.date_key = f.order_date_key
INNER JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
INNER JOIN gold.dim_products AS p
    ON p.product_key = f.product_key;
GO

-------------------------------------------------------------------------------
-- Step 8: Validate Gold Layer
-------------------------------------------------------------------------------
SELECT 'gold.dim_customers' AS table_name, COUNT(*) AS total_rows
FROM gold.dim_customers

UNION ALL

SELECT 'gold.dim_products', COUNT(*)
FROM gold.dim_products

UNION ALL

SELECT 'gold.dim_date', COUNT(*)
FROM gold.dim_date

UNION ALL

SELECT 'gold.fact_sales', COUNT(*)
FROM gold.fact_sales;
GO
