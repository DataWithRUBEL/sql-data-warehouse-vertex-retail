# Vertex Retail Data Warehouse — SQL Server

## ✅ Deliverables

- 📁 **datasets/**: six transformed CSV sources, preserving the original row counts.
- 🥉 **01_bronze_layer.sql**: database and raw landing tables.
- 🥈 **02_silver_layer.sql**: cleaning, standardization, and type conversion.
- 🥇 **03_gold_layer.sql**: star schema and reporting views.
- 🧪 **04_quality_and_practice.sql**: reconciliation checks and practical analytics.

## 🚀 Run order

1. Open `01_bronze_layer.sql` in SSMS and replace `CHANGE_TO_YOUR_DATASET_FOLDER` with the full path to `datasets`.
2. Run scripts 01 → 02 → 03 → 04 in this exact order.
3. Query `gold.fact_sales`, `gold.dim_customers`, and `gold.dim_products` for reporting.

## 🗺️ Source-to-target map

| New CSV | Source area | Warehouse use |
|---|---|---|
| `crm_customer_master.csv` | CRM | customer identity |
| `crm_product_catalog.csv` | CRM | product history |
| `crm_sales_transactions.csv` | CRM | sales events |
| `erp_customer_profile.csv` | ERP | DOB and gender enrichment |
| `erp_customer_location.csv` | ERP | country enrichment |
| `erp_product_category.csv` | ERP | product category enrichment |

> All values were transformed, while record volumes and required customer/product relationships remain valid for the project.
