🧪 Section 1: ETL/Data Warehouse Validation
🚨 Section 2: Data Quality Checks
📊 Section 3: Analyst Practice Queries
📈 Section 4: Advanced Analyst Queries
🏆 Section 5: Interview/Real-job Checks

  
/* =========================================================
   VERTEX RETAIL DW
   STEP 4 — VALIDATION & ANALYST PRACTICE
   ========================================================= */

USE VertexRetailDW;
GO


-- Source/Silver-এ যত sales transaction আছে, Gold Fact-এও একই সংখ্যক row আছে কি না।
/* =========================================================
   SECTION 1: ETL RECONCILIATION
   Purpose:
   Validate Silver → Gold row count
   ========================================================= */

SELECT
    'Silver Source Sales' AS check_name,
    COUNT(*) AS row_count
FROM silver.crm_sales_transactions

UNION ALL

SELECT
    'Gold Fact Sales' AS check_name,
    COUNT(*) AS row_count
FROM gold.fact_sales;



/* =========================================================
   RECONCILIATION: SOURCE vs FACT
   Expected:
   difference = 0
   ========================================================= */

SELECT
    COUNT(*) AS source_count
FROM silver.crm_sales_transactions;

SELECT
    COUNT(*) AS fact_count
FROM gold.fact_sales;

SELECT
    (
        SELECT COUNT(*)
        FROM silver.crm_sales_transactions
    )
    -
    (
        SELECT COUNT(*)
        FROM gold.fact_sales
    ) AS row_count_difference;




/* =========================================================
   DATA QUALITY CHECK #1
   Validate sales calculation

   Expected:
   Zero rows
   ========================================================= */

SELECT
    sales_key,
    order_date_key,
    customer_key,
    product_key,
    quantity,
    unit_price,
    sales_amount
FROM gold.fact_sales
WHERE sales_amount <> quantity * unit_price;




-- Real-world এ floating/decimal calculation-এর কারণে <> সবসময় ideal না।
/* =========================================================
   BETTER SALES AMOUNT VALIDATION
   Allows small decimal tolerance
   ========================================================= */

SELECT
    sales_key,
    quantity,
    unit_price,
    sales_amount,
    quantity * unit_price AS calculated_amount,
    sales_amount - (quantity * unit_price) AS difference
FROM gold.fact_sales
WHERE ABS(
        sales_amount - (quantity * unit_price)
      ) > 0.01;




/* =========================================================
   DATA QUALITY CHECK #2
   Check rejected customer records
   ========================================================= */

SELECT
    COUNT(*) AS rejected_customer_records
FROM silver.crm_customer_master_rejected;


-- তারপর rejected data দেখতে:
/* =========================================================
   VIEW REJECTED CUSTOMER RECORDS
   ========================================================= */

SELECT *
FROM silver.crm_customer_master_rejected;


-- Duplicate Customers
/* =========================================================
   DATA QUALITY CHECK #3
   Duplicate customer_id
   Expected:
   Zero rows
   ========================================================= */

SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;



-- Duplicate Products
/* =========================================================
   DATA QUALITY CHECK #4
   Duplicate product_code
   Expected:
   Zero rows
   ========================================================= */

SELECT
    product_code,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_code
HAVING COUNT(*) > 1;




-- NULL Foreign Key Check
-- এটা খুব important। কারণ Fact table-এর foreign keys dimension-এর সাথে relationship তৈরি করে।
/* =========================================================
   DATA QUALITY CHECK #5
   NULL Foreign Keys
   Expected:
   Zero rows
   ========================================================= */

SELECT
    *
FROM gold.fact_sales
WHERE order_date_key IS NULL
   OR customer_key IS NULL
   OR product_key IS NULL;




-- Better NULL Summary
-- একসাথে কতগুলো NULL আছে দেখতে পারো:
/* =========================================================
   NULL SUMMARY
   ========================================================= */

SELECT
    SUM(CASE WHEN order_date_key IS NULL THEN 1 ELSE 0 END)
        AS null_date_keys,

    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END)
        AS null_customer_keys,

    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END)
        AS null_product_keys
FROM gold.fact_sales;




-- Referential Integrity Check 🔥
-- এটা তোমার original code-এর চেয়েও important।
-- Fact → Customer
/* =========================================================
   REFERENTIAL INTEGRITY CHECK
   Fact records without matching customer dimension
   Expected:
   Zero rows
   ========================================================= */

SELECT
    f.sales_key,
    f.customer_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;




-- Fact → Product
/* =========================================================
   Fact records without matching product dimension
   Expected:
   Zero rows
   ========================================================= */

SELECT
    f.sales_key,
    f.product_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;



-- Fact → Date
/* =========================================================
   Fact records without matching date dimension
   Expected:
   Zero rows
   ========================================================= */

SELECT
    f.sales_key,
    f.order_date_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_date d
    ON f.order_date_key = d.date_key
WHERE d.date_key IS NULL;





-- Analyst Practice শুরু
-- উপরের validation queries ঠিক থাকার পর এগুলো run করবে।
-- Practice 1 — Top 10 Countries by Revenue
/* =========================================================
   ANALYST PRACTICE #1
   TOP 10 COUNTRIES BY REVENUE
   ========================================================= */

SELECT TOP (10)
    c.country,
    SUM(f.sales_amount) AS revenue,
    SUM(f.quantity) AS units_sold
FROM gold.fact_sales AS f
INNER JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
GROUP BY
    c.country
ORDER BY
    revenue DESC;



-- Practice 2 — Monthly Revenue + MoM Growth
/* =========================================================
   ANALYST PRACTICE #2
   MONTHLY REVENUE
   MONTH-OVER-MONTH CHANGE
   ========================================================= */

WITH monthly AS
(
    SELECT
        DATEFROMPARTS(
            d.calendar_year,
            d.calendar_month,
            1
        ) AS month_start,

        SUM(f.sales_amount) AS revenue

    FROM gold.fact_sales AS f

    INNER JOIN gold.dim_date AS d
        ON d.date_key = f.order_date_key

    GROUP BY
        d.calendar_year,
        d.calendar_month
)

SELECT
    month_start,
    revenue,

    LAG(revenue) OVER (
        ORDER BY month_start
    ) AS previous_month_revenue,

    revenue
        - LAG(revenue) OVER (
            ORDER BY month_start
          ) AS mom_change,

    CAST(
        (
            revenue
            - LAG(revenue) OVER (
                ORDER BY month_start
            )
        )
        * 100.0
        / NULLIF(
            LAG(revenue) OVER (
                ORDER BY month_start
            ),
            0
        )
        AS DECIMAL(10,2)
    ) AS mom_growth_pct

FROM monthly
ORDER BY
    month_start;



-- Practice 3 — Customers With No Purchase
/* =========================================================
   ANALYST PRACTICE #3
   CUSTOMERS WITH NO PURCHASE
   ========================================================= */

SELECT
    c.customer_id,
    c.customer_name,
    c.country
FROM gold.dim_customers AS c

LEFT JOIN gold.fact_sales AS f
    ON f.customer_key = c.customer_key

WHERE f.sales_key IS NULL;




-- /* =========================================================
   ANALYST PRACTICE #3
   CUSTOMERS WITH NO PURCHASE
   ========================================================= */

SELECT
    c.customer_id,
    c.customer_name,
    c.country
FROM gold.dim_customers AS c

LEFT JOIN gold.fact_sales AS f
    ON f.customer_key = c.customer_key

WHERE f.sales_key IS NULL;




-- Practice 4 — Product Ranking by Category
/* =========================================================
   ANALYST PRACTICE #4
   PRODUCT REVENUE RANKING
   WITHIN EACH CATEGORY
   ========================================================= */

WITH product_revenue AS
(
    SELECT
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS revenue

    FROM gold.fact_sales AS f

    INNER JOIN gold.dim_products AS p
        ON p.product_key = f.product_key

    GROUP BY
        p.category,
        p.product_name
)

SELECT
    category,
    product_name,
    revenue,

    DENSE_RANK() OVER
    (
        PARTITION BY category
        ORDER BY revenue DESC
    ) AS category_rank

FROM product_revenue

ORDER BY
    category,
    category_rank;




-- আরও গুরুত্বপূর্ণ Analyst Queries
-- Top 10 Products
/* =========================================================
   ANALYST PRACTICE #5
   TOP 10 PRODUCTS BY REVENUE
   ========================================================= */

SELECT TOP (10)
    p.product_code,
    p.product_name,
    p.category,
    SUM(f.quantity) AS units_sold,
    SUM(f.sales_amount) AS revenue

FROM gold.fact_sales AS f

INNER JOIN gold.dim_products AS p
    ON p.product_key = f.product_key

GROUP BY
    p.product_code,
    p.product_name,
    p.category

ORDER BY
    revenue DESC;




-- Customer Revenue Ranking
/* =========================================================
   ANALYST PRACTICE #6
   CUSTOMER REVENUE RANKING
   ========================================================= */

SELECT
    c.customer_id,
    c.customer_name,
    c.country,

    SUM(f.sales_amount) AS revenue,

    DENSE_RANK() OVER
    (
        ORDER BY SUM(f.sales_amount) DESC
    ) AS customer_rank

FROM gold.fact_sales AS f

INNER JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key

GROUP BY
    c.customer_id,
    c.customer_name,
    c.country;




-- Yearly Revenue
/* =========================================================
   ANALYST PRACTICE #7
   YEARLY REVENUE
   ========================================================= */

SELECT
    d.calendar_year,
    SUM(f.sales_amount) AS revenue,
    SUM(f.quantity) AS units_sold,
    COUNT(*) AS sales_transactions

FROM gold.fact_sales AS f

INNER JOIN gold.dim_date AS d
    ON d.date_key = f.order_date_key

GROUP BY
    d.calendar_year

ORDER BY
    d.calendar_year;



-- Year-over-Year Growth
/* =========================================================
   ANALYST PRACTICE #8
   YEAR-OVER-YEAR REVENUE GROWTH
   ========================================================= */

WITH yearly AS
(
    SELECT
        d.calendar_year,
        SUM(f.sales_amount) AS revenue

    FROM gold.fact_sales AS f

    INNER JOIN gold.dim_date AS d
        ON d.date_key = f.order_date_key

    GROUP BY
        d.calendar_year
)

SELECT
    calendar_year,
    revenue,

    LAG(revenue) OVER
    (
        ORDER BY calendar_year
    ) AS previous_year_revenue,

    revenue
        - LAG(revenue) OVER
        (
            ORDER BY calendar_year
        ) AS yoy_change

FROM yearly

ORDER BY
    calendar_year;




-- Average Order Value
/* =========================================================
   ANALYST PRACTICE #9
   AVERAGE ORDER VALUE
   ========================================================= */

SELECT
    SUM(sales_amount) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,

    CAST(
        SUM(sales_amount)
        / NULLIF(COUNT(DISTINCT order_id), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value

FROM gold.fact_sales;




-- Category Performance
/* =========================================================
   ANALYST PRACTICE #10
   CATEGORY PERFORMANCE
   ========================================================= */

SELECT
    p.category,

    SUM(f.quantity) AS units_sold,

    SUM(f.sales_amount) AS revenue,

    AVG(f.unit_price) AS average_unit_price

FROM gold.fact_sales AS f

INNER JOIN gold.dim_products AS p
    ON p.product_key = f.product_key

GROUP BY
    p.category

ORDER BY
    revenue DESC;

