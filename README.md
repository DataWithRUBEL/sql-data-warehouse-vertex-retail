# Vertex Retail Data Warehouse — SQL Server

## ✅ Deliverables

- 📁 **datasets/**: six transformed CSV sources, preserving the original row counts.
- 🥉 **bronze.sql**: database and raw landing tables.
- 🥈 **silver.sql**: cleaning, standardization, and type conversion.
- 🥇 **gold.sql**: star schema and reporting views.
- 🧪 **quality_and_practice.sql**: reconciliation checks and practical analytics.


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
