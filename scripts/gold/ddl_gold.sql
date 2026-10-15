/*
===============================================================================
Purpose     : Creates the Gold layer as physical, indexed tables (star schema
              plus a pre-aggregated monthly sales table).

Notes       :
- Populated by gold.load_gold (proc_load_gold.sql)
- Earlier versions of Gold were views; any leftover views are dropped here
===============================================================================
*/

USE DataWarehouse;
GO

-- Drop objects from the view-based version of Gold
IF OBJECT_ID('gold.fact_sales','V')    IS NOT NULL DROP VIEW gold.fact_sales;
IF OBJECT_ID('gold.dim_customers','V') IS NOT NULL DROP VIEW gold.dim_customers;
IF OBJECT_ID('gold.dim_products','V')  IS NOT NULL DROP VIEW gold.dim_products;
IF OBJECT_ID('gold.dim_product','V')   IS NOT NULL DROP VIEW gold.dim_product;
GO

IF OBJECT_ID('gold.agg_sales_monthly','U') IS NOT NULL DROP TABLE gold.agg_sales_monthly;
IF OBJECT_ID('gold.fact_sales','U')        IS NOT NULL DROP TABLE gold.fact_sales;
IF OBJECT_ID('gold.dim_customers','U')     IS NOT NULL DROP TABLE gold.dim_customers;
IF OBJECT_ID('gold.dim_products','U')      IS NOT NULL DROP TABLE gold.dim_products;
GO


CREATE TABLE gold.dim_customers (
    customer_key    INT          NOT NULL PRIMARY KEY,
    customer_id     INT,
    customer_number NVARCHAR(50),
    first_name      NVARCHAR(50),
    last_name       NVARCHAR(50),
    country         NVARCHAR(50),
    marital_status  NVARCHAR(50),
    gender          NVARCHAR(50),
    birthdate       DATE,
    create_date     DATE
);
GO

CREATE INDEX IX_dim_customers_customer_id ON gold.dim_customers (customer_id);
GO


CREATE TABLE gold.dim_products (
    product_key          INT          NOT NULL PRIMARY KEY,
    product_id           INT,
    product_number       NVARCHAR(50),
    product_name         NVARCHAR(50),
    category_id          NVARCHAR(50),
    category             NVARCHAR(50),
    subcategory          NVARCHAR(50),
    maintenance_required NVARCHAR(50),
    cost                 INT,
    product_line         NVARCHAR(50),
    start_date           DATE
);
GO

CREATE INDEX IX_dim_products_product_number ON gold.dim_products (product_number);
GO


CREATE TABLE gold.fact_sales (
    order_number  NVARCHAR(50),
    product_key   INT,
    customer_key  INT,
    order_date    DATE,
    shipping_date DATE,
    due_date      DATE,
    sales_amount  INT,
    quantity      INT,
    price         INT
);
GO

CREATE CLUSTERED INDEX CIX_fact_sales_order_date ON gold.fact_sales (order_date);
CREATE INDEX IX_fact_sales_customer_key ON gold.fact_sales (customer_key) INCLUDE (sales_amount);
CREATE INDEX IX_fact_sales_product_key  ON gold.fact_sales (product_key)  INCLUDE (sales_amount);
GO


-- One row per month x category x subcategory x country
CREATE TABLE gold.agg_sales_monthly (
    order_month  DATE,
    category     NVARCHAR(50),
    subcategory  NVARCHAR(50),
    country      NVARCHAR(50),
    sales_amount INT,
    quantity     INT,
    order_lines  INT
);
GO

CREATE CLUSTERED INDEX CIX_agg_sales_monthly
    ON gold.agg_sales_monthly (order_month, category, subcategory, country);
GO
