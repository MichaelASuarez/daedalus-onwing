-- Module 3 Exercises: Databases, Schemas & Tables
-- Environment: Yellowbrick Cloud Test Environment
-- Sample data: samples.retail 

-- ============================================================
-- PART 1: Explore the Environment
-- ============================================================

-- 1.2: List all databases on the system
SELECT name AS database_name
, encoding
FROM sys.database
ORDER BY name;

-- 1.3: List schemas in your current database
SELECT schema_name
, schema_owner
FROM information_schema.schemata
ORDER BY schema_name;

-- 1.4: Preview the fact_sales table
SELECT *
FROM samples.retail.fact_sales
LIMIT 5;

-- 1.4: Count rows in fact_sales
SELECT COUNT(*) AS row_count
FROM samples.retail.fact_sales;

-- 1.4: Preview dim_store
SELECT store_key, store_name, city, state
FROM samples.retail.dim_store
ORDER BY store_key
LIMIT 10;

-- 1.5: Confirm your current connection context
SELECT current_database() AS my_database
, current_schema() AS default_schema
, current_user AS logged_in_as;


-- ============================================================
-- PART 2: Create Your Personal Schema
-- ============================================================

-- 2.1: Create your personal schema (replace username)
CREATE DATABASE db_[username] with encoding=utf8;

-- NOTE: Switch to your new database before running the next steps. 
-- In YB Manager, you can select the database from the dropdown in the query editor.
CREATE SCHEMA exercises;

-- 2.1b: Share with instructor
GRANT ALL ON DATABASE db_[username] TO msuarez;
ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO msuarez;
GRANT ALL ON SCHEMA exercises TO msuarez;

-- 2.1: Verify the schema was created
SELECT schema_name, schema_owner
FROM information_schema.schemata
WHERE schema_name = 'exercises';

-- 2.2: Set search_path for this session
SET search_path = exercises, public;

-- 2.2: Verify search_path took effect
SHOW search_path;

-- 2.2: (Optional) Make search_path permanent for your user
ALTER USER your_username
SET search_path = exercises, public;

-- 2.3: Confirm your schema is now the default
SELECT current_database() AS my_database
, current_schema() AS default_schema
, current_user AS logged_in_as;


-- ============================================================
-- PART 3: Design and Create a Table
-- ============================================================

-- 3.2: Create the revenue_by_store_month summary table
CREATE TABLE exercises.revenue_by_store_month
(
    store_key         INTEGER      NOT NULL,
    revenue_month     DATE         NOT NULL,
    total_revenue     NUMERIC(18,2) NOT NULL,
    transaction_count INTEGER      NOT NULL,
    avg_unit_price    NUMERIC(12,2),
    loaded_at         TIMESTAMP
)
DISTRIBUTE ON (store_key)
SORT ON (revenue_month);

-- 3.3: Check columns and data types
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'exercises'
AND table_name = 'revenue_by_store_month'
ORDER BY ordinal_position;

-- 3.3: Check distribution and sort key
SELECT name, distribution, distribution_key, sort_key
FROM sys.table
WHERE name = 'revenue_by_store_month';


-- ============================================================
-- PART 4: Populate Your Table
-- ============================================================

-- 4.1: Preview source data
SELECT store_key
, transaction_timestamp
, total
, unit_price
FROM samples.retail.fact_sales
LIMIT 5;

-- 4.1: Check row count of source
SELECT COUNT(*) AS total_rows
FROM samples.retail.fact_sales;

-- 4.2: Insert aggregated data from fact_sales into your summary table
INSERT INTO exercises.revenue_by_store_month
    (store_key, revenue_month, total_revenue,
     transaction_count, avg_unit_price, loaded_at)
SELECT
    store_key,
    DATE_TRUNC('month', transaction_timestamp)::DATE,
    SUM(total),
    COUNT(*),
    ROUND(AVG(unit_price)::NUMERIC, 2),
    CURRENT_TIMESTAMP
FROM samples.retail.fact_sales
GROUP BY store_key
, DATE_TRUNC('month', transaction_timestamp)::DATE;

-- 4.3: Count rows loaded
SELECT COUNT(*) AS row_count
FROM exercises.revenue_by_store_month;

-- 4.3: Preview results
SELECT *
FROM exercises.revenue_by_store_month
ORDER BY store_key, revenue_month
LIMIT 10;

-- 4.3: Which month had the highest total revenue across all stores?
SELECT TO_CHAR(revenue_month, 'YYYY-MM') AS revenue_month
     , SUM(total_revenue)                AS monthly_revenue
FROM exercises.revenue_by_store_month
GROUP BY revenue_month
ORDER BY monthly_revenue DESC
LIMIT 5;


-- ============================================================
-- PART 5: Temporary Tables
-- ============================================================

-- 5.1: Create a temp table of the top 10 stores by revenue
-- NOTE: In YB Manager, create the temp table and the query must be run together in one execution
CREATE TEMP TABLE top_stores AS
SELECT
    store_key,
    SUM(total_revenue) AS total_revenue,
    SUM(transaction_count) AS total_transactions
FROM exercises.revenue_by_store_month
GROUP BY store_key
ORDER BY total_revenue DESC
LIMIT 10;

-- 5.2: Query the temp table
SELECT *
FROM top_stores
ORDER BY total_revenue DESC;

-- 5.2: Join temp table back to monthly summary for a breakdown
SELECT r.store_key
, r.revenue_month
, r.total_revenue
FROM exercises.revenue_by_store_month AS r
JOIN top_stores AS t
  ON r.store_key = t.store_key
ORDER BY r.store_key, r.revenue_month;

-- 5.2: Enrich with store names from the dimension table
SELECT s.store_name
, s.city
, t.total_revenue
, t.total_transactions
FROM top_stores AS t
JOIN samples.retail.dim_store AS s
  ON t.store_key = s.store_key
ORDER BY t.total_revenue DESC;


-- ============================================================
-- STRETCH: Inspect Table Metadata
-- ============================================================

-- S.1: Check distribution and sort key
SELECT name AS table_name
, distribution
, distribution_key
, sort_key
FROM sys.table
WHERE name = 'revenue_by_store_month';

-- S.2: Attempt to insert a NULL into a NOT NULL column (should fail)
INSERT INTO exercises.revenue_by_store_month
    (store_key, revenue_month, total_revenue, transaction_count)
VALUES
    (NULL, '2024-01-01', 50000.00, 100);
