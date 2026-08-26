USE VertexRetailDW;
GO

-- Expected raw counts: 18494, 397, 60398, 18484, 18484, 37.
SELECT 
     'bronze.crm_customer_master' AS table_name, 
      COUNT(*) AS row_count 
FROM bronze.crm_customer_master
  UNION ALL
  
SELECT 
      'bronze.crm_product_catalog', 
       COUNT(*) 
FROM bronze.crm_product_catalog
  UNION ALL 
  
SELECT 
      'bronze.crm_sales_transactions', 
       COUNT(*) 
FROM bronze.crm_sales_transactions
  UNION ALL 
  
SELECT 
     'bronze.erp_customer_profile', 
      COUNT(*) 
FROM bronze.erp_customer_profile  
  UNION ALL 
  
SELECT 
      'bronze.erp_customer_location', 
      COUNT(*) 
FROM bronze.erp_customer_location
  UNION ALL 
  
SELECT 
      'bronze.erp_product_category', 
      COUNT(*) 
FROM bronze.erp_product_category;

-- Expected fact count: 60398. Missing order dates are mapped to date key -1.
SELECT 
      COUNT(*) AS total_sales,
      SUM(CASE WHEN order_date_key = -1 THEN 1 ELSE 0 END) AS unknown_date_sales
FROM gold.fact_sales;


SELECT rejection_reason, 
       COUNT(*) AS rejected_rows
FROM silver.crm_customer_master_rejected
GROUP BY rejection_reason;

-- These should return zero rows.
SELECT * 
FROM gold.fact_sales 
WHERE sales_amount <> quantity * unit_price;


SELECT 
     customer_id, 
     COUNT(*) AS duplicate_count 
FROM gold.dim_customers 
GROUP BY customer_id 
HAVING COUNT(*) > 1;


SELECT 
     product_code, 
     COUNT(*) AS duplicate_count 
FROM gold.dim_products 
GROUP BY product_code 
HAVING COUNT(*) > 1;
GO
