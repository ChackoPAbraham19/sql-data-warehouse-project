# sql-data-warehouse-project

A SQL Server data warehouse that consolidates CRM and ERP sales data into a star schema for analytics, built on the Medallion architecture (Bronze → Silver → Gold).

## Architecture

| Layer | Object type | Load | Purpose |
|---|---|---|---|
| **Bronze** | Tables | Truncate + `BULK INSERT` from CSV (`bronze.load_bronze`) | Raw copy of the source files, no transformation |
| **Silver** | Tables | Truncate + insert from Bronze (`silver.load_silver`) | Cleaned, standardized, deduplicated data |
| **Gold** | Tables | Truncate + insert from Silver (`gold.load_gold`) | Business-ready star schema (`dim_customers`, `dim_products`, `fact_sales`) plus pre-aggregated `agg_sales_monthly` |

### Sources

- **CRM**: `cust_info.csv`, `prd_info.csv`, `sales_details.csv`
- **ERP**: `CUST_AZ12.csv` (birthdate, gender), `LOC_A101.csv` (country), `PX_CAT_G1V2.csv` (product categories)

## Repository layout

```
datasets/            source CSVs (source_crm/, source_erp/)
scripts/
  init_database.sql  creates DataWarehouse db + bronze/silver/gold schemas
  bronze/            DDL + load procedure
  silver/            DDL + cleansing/load procedure
  gold/              star-schema tables + load procedure
benchmark/           baseline (view-based Gold) vs materialized Gold query benchmark
tests/               data quality checks (each query should return no rows)
docs/Data_Catalog.md column-level docs for the Gold layer
```

## Running it

1. Run `scripts/init_database.sql` (drops and recreates `DataWarehouse`).
2. Run `scripts/bronze/ddl_bronze.sql` and `scripts/bronze/proc_load_bronze.sql`.
3. Update the CSV paths in `proc_load_bronze.sql` to your local `datasets/` folder, then `EXEC bronze.load_bronze;`
4. Run `scripts/silver/ddl_silver.sql` and `scripts/silver/proc_load_silver.sql`, then `EXEC silver.load_silver;`
5. Run `scripts/gold/ddl_gold.sql` and `scripts/gold/proc_load_gold.sql`, then `EXEC gold.load_gold;`
6. Run the queries in `tests/` to validate the Silver and Gold layers.

## Benchmark

`benchmark/` measures what materializing Gold buys. It runs the same reporting queries against the original view-based Gold layer (recreated in schema `bench`) and against the Gold tables, checks that both return identical results, and reports median timings. Run `benchmark/setup_benchmark.sql`, then:

```sql
EXEC bench.check_results;
EXEC bench.run_benchmark @iterations = 30;
```

Results are recorded in [benchmark/RESULTS.md](benchmark/RESULTS.md).

## License

MIT, see [LICENSE](LICENSE).
