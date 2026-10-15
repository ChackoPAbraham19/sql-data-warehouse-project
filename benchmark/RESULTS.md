# Gold Layer Benchmark Results

Compares the same reporting questions against:

- **Baseline**: the original view-based Gold layer (`bench.*` views). Every query re-runs the Silver joins, and the surrogate keys (`ROW_NUMBER`) are recomputed on every read.
- **Gold**: materialized, indexed tables (`gold.dim_*`, `gold.fact_sales`) plus a pre-aggregated `gold.agg_sales_monthly` (month × category × subcategory × country).

> Fill this in from your own runs. Only report numbers you measured.

## Environment

| | |
|---|---|
| SQL Server version (`SELECT @@VERSION`) | |
| Machine (CPU / RAM / disk) | |
| Row counts: fact_sales / dim_customers / dim_products / agg_sales_monthly | |
| Date run | |

## How to reproduce

```sql
EXEC bronze.load_bronze;
EXEC silver.load_silver;
EXEC gold.load_gold;          -- note the "Gold load total time" it prints
EXEC bench.check_results;     -- every query must PASS
EXEC bench.run_benchmark @iterations = 30;                    -- warm cache
EXEC bench.run_benchmark @iterations = 10, @cold_cache = 1;   -- optional, dev instance only
```

Then run `benchmark/io_comparison.sql` to get the logical reads.

## Correctness check (`bench.check_results`)

| Query | Result | Rows |
|---|---|---|
| Q1 Monthly revenue trend | | |
| Q2 Revenue by country | | |
| Q3 Revenue by category and subcategory | | |
| Q4 Top 10 customers by revenue | | |

## Timing, warm cache (`bench.run_benchmark`, median of N runs)

| Query | Baseline median (ms) | Gold median (ms) | Reduction |
|---|---|---|---|
| Q1 Monthly revenue trend | | | |
| Q2 Revenue by country | | | |
| Q3 Revenue by category and subcategory | | | |
| Q4 Top 10 customers by revenue | | | |
| **All queries (sum of medians)** | | | |

## Logical reads (`io_comparison.sql`)

| Query | Baseline logical reads (all tables) | Gold logical reads |
|---|---|---|
| Q1 | | |
| Q2 | | |
| Q3 | | |
| Q4 | | |

## Trade-off

| | |
|---|---|
| `gold.load_gold` duration (ms) | |

Gold is faster to query because the join and aggregation work moves into the load step. That cost is paid once per load instead of on every query.

## Why it's faster

- **Q1–Q3** read the pre-aggregated rows in `gold.agg_sales_monthly` (row count is in the Environment table) instead of joining and grouping every sales line across all 6 Silver tables.
- **Q4** is at customer level, so it can't use the aggregate. It still benefits because the joins and surrogate keys are already stored, and `IX_fact_sales_customer_key` covers the `customer_key` / `sales_amount` lookup.
