-- Module 8 Exercises: Reusable Business Logic
-- Environment: Yellowbrick Cloud Test Environment
-- Sample data: samples.retail  |  Your database: db_<username>
-- Replace 'your_username' with your actual Yellowbrick username throughout.
-- All objects are created in public schema of your assigned database.


-- ============================================================
-- SETUP: Run once at the start of each session
-- ============================================================

-- Set your search path
SET search_path = public;

-- Confirm your connection context
SELECT current_database() AS my_database
,      current_user        AS logged_in_as
,      current_schema()    AS default_schema;


-- ============================================================
-- PART 1: Views
-- ============================================================

-- ----- 1.1: Create vw_sales_detail -------------------------

-- Run it: Create the view (5-table join)
CREATE OR REPLACE VIEW public.vw_sales_detail AS
SELECT
    f.transaction_id,
    d.full_date          AS sale_date,
    d.month_name, d.year, d.quarter, d.is_weekend,
    s.store_name, s.city, s.state,
    c.first_name || ' ' || c.last_name  AS customer_name,
    c.membership_tier,
    p.name               AS product_name,
    p.category, p.brand,
    f.quantity, f.unit_price, f.discount_amount, f.total,
    f.payment_status
FROM samples.retail.fact_sales f
JOIN samples.retail.dim_date     d ON f.date_key     = d.date_key
JOIN samples.retail.dim_store    s ON f.store_key    = s.store_key
JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key
JOIN samples.retail.dim_product  p ON f.product_key  = p.product_key;

-- Run it: Query the view like a table (no joins needed!)
SELECT category
,      ROUND(SUM(total), 2) AS revenue
FROM   public.vw_sales_detail
WHERE  year = 2026
GROUP  BY category
ORDER  BY revenue DESC;
-- Expected: 20 rows. Furniture leads with ~$165M.

-- Modify it: Filter to Electronics stores in 2026, show store_name and revenue
SELECT store_name
,      ROUND(SUM(total), 2) AS revenue
FROM   public.vw_sales_detail
WHERE  year = 2026
  AND  category = 'Electronics'
GROUP  BY store_name
ORDER  BY revenue DESC
LIMIT  5;
-- Expected: Top 5 Electronics stores. Super Retail Store #14 leads.

-- Your turn: Using vw_sales_detail, write a query that shows
-- total revenue and transaction count for Gold and Platinum members only,
-- grouped by membership_tier. (Hint: use COUNT(DISTINCT transaction_id))


-- ----- 1.2: Create vw_customer_spend -----------------------

-- Run it: Create a view that pre-aggregates customer metrics
CREATE OR REPLACE VIEW public.vw_customer_spend AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS customer_name,
    c.membership_tier,
    COUNT(DISTINCT f.transaction_id)    AS transaction_count,
    ROUND(SUM(f.total), 2)              AS total_spend,
    ROUND(AVG(f.total), 2)              AS avg_basket_size
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_customer c ON f.customer_key = c.customer_key
GROUP BY 1, 2, 3;

-- Run it: Top 5 Gold customers by spend
SELECT customer_name, membership_tier, total_spend, transaction_count
FROM   public.vw_customer_spend
WHERE  membership_tier = 'Gold'
ORDER  BY total_spend DESC
LIMIT  5;
-- Expected: Jessica Brown leads Gold with ~$230K across 20 visits.

-- Modify it: Change 'Gold' to 'Platinum' -- who are the top Platinum spenders?
SELECT customer_name, membership_tier, total_spend, transaction_count
FROM   public.vw_customer_spend
WHERE  membership_tier = 'Platinum'
ORDER  BY total_spend DESC
LIMIT  5;

-- Your turn: Using vw_customer_spend, find customers who have visited
-- more than 15 times (transaction_count > 15).
-- Show customer_name, membership_tier, transaction_count, and avg_basket_size.
-- Order by transaction_count descending. Limit to 10.


-- ============================================================
-- PART 2: Stored Procedures -- VOID
-- ============================================================

-- ----- 2.1: Create and CALL a VOID procedure ---------------

-- Run it: Create the procedure
CREATE OR REPLACE PROCEDURE public.show_category_summary(p_category VARCHAR(50))
    RETURNS VOID
    LANGUAGE plpgsql
AS $$
DECLARE
    v_items   BIGINT;
    v_units   BIGINT;
    v_revenue NUMERIC(15,2);
BEGIN
    SELECT COUNT(*)
    ,      SUM(f.quantity)
    ,      ROUND(SUM(f.total), 2)
    INTO   v_items, v_units, v_revenue
    FROM   samples.retail.fact_sales f
    JOIN   samples.retail.dim_product p ON f.product_key = p.product_key
    WHERE  p.category = p_category;

    RAISE INFO 'Category:   %', p_category;
    RAISE INFO 'Line Items: %', v_items;
    RAISE INFO 'Units Sold: %', v_units;
    RAISE INFO 'Revenue:    $%', v_revenue;
END;
$$;

-- Run it: Call the procedure
CALL public.show_category_summary('Electronics');
-- Expected RAISE INFO output:
-- Category:   Electronics
-- Line Items: 274606
-- Units Sold: 824000
-- Revenue:    $442008997.69

-- Modify it: Change the category to 'Furniture'
CALL public.show_category_summary('Furniture');
-- Expected: Higher revenue (~$447M) -- Furniture is the top category.

-- Modify it: Try 'Books' -- which category has more revenue, Books or Clothing?
CALL public.show_category_summary('Books');
CALL public.show_category_summary('Clothing');


-- ----- 2.2: Write your own VOID procedure ------------------

-- Your turn:
-- Create a procedure called show_store_summary(p_city VARCHAR(50))
-- that reports: number of stores, number of transactions, total revenue
-- for all stores in a given city.
-- Use RAISE INFO to print the results.
-- Test it by calling: CALL public.show_store_summary('Oakland');
--
-- Expected output for Oakland:
-- City:         Oakland
-- Stores:       1
-- Transactions: 9947
-- Revenue:      $16139316.93
--
-- Solution (try yourself first!):

CREATE OR REPLACE PROCEDURE public.show_store_summary(p_city VARCHAR(50))
    RETURNS VOID
    LANGUAGE plpgsql
AS $$
DECLARE
    v_stores  BIGINT;
    v_txns    BIGINT;
    v_revenue NUMERIC(15,2);
BEGIN
    SELECT COUNT(DISTINCT s.store_key)
    ,      COUNT(DISTINCT f.transaction_id)
    ,      ROUND(SUM(f.total), 2)
    INTO   v_stores, v_txns, v_revenue
    FROM   samples.retail.fact_sales f
    JOIN   samples.retail.dim_store s ON f.store_key = s.store_key
    WHERE  s.city = p_city;

    RAISE INFO 'City:         %', p_city;
    RAISE INFO 'Stores:       %', v_stores;
    RAISE INFO 'Transactions: %', v_txns;
    RAISE INFO 'Revenue:      $%', v_revenue;
END;
$$;

CALL public.show_store_summary('Oakland');


-- ============================================================
-- PART 3: Stored Procedures -- SETOF
-- ============================================================

-- ----- 3.1: Create and SELECT from a SETOF procedure -------

-- Run it: Step 1 -- create the result-type table
CREATE TABLE IF NOT EXISTS public.top_customer_result (
    customer_name   VARCHAR(100),
    membership_tier VARCHAR(20),
    total_spend     NUMERIC(15,2),
    visits          BIGINT
) DISTRIBUTE ON (customer_name);

-- Run it: Step 2 -- create the procedure
CREATE OR REPLACE PROCEDURE public.get_top_customers(p_limit INT)
    RETURNS SETOF public.top_customer_result
    LANGUAGE plpgsql
AS $$
DECLARE
    v_row public.top_customer_result%ROWTYPE;
    v_sql VARCHAR(1000) = '
        SELECT
            c.first_name || '' '' || c.last_name AS customer_name,
            c.membership_tier,
            ROUND(SUM(f.total), 2)               AS total_spend,
            COUNT(DISTINCT f.transaction_id)     AS visits
        FROM samples.retail.fact_sales f
        JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key
        GROUP BY 1, 2
        ORDER BY total_spend DESC
        LIMIT $1';
BEGIN
    FOR v_row IN EXECUTE(v_sql) USING p_limit
    LOOP
        RETURN NEXT v_row;
    END LOOP;
END;
$$;

-- Run it: Call with SELECT * FROM (not CALL!)
SELECT * FROM public.get_top_customers(5::INT);
-- Expected: Top 5 customers across all tiers, led by Bronze members
-- with very high visit counts (1100+ visits) and spend (~$10M each).

-- Modify it: Show the top 10 customers
SELECT * FROM public.get_top_customers(10::INT);

-- Modify it: Use a WHERE clause to filter AFTER calling the proc
-- Note: this filter runs on the manager (frontend) -- not ideal for large results
SELECT * FROM public.get_top_customers(100::INT)
WHERE membership_tier = 'Platinum'
ORDER BY total_spend DESC
LIMIT 5;


-- ----- 3.2: Overloaded version with tier filter ------------

-- Run it: Add an overloaded version that accepts a tier parameter
CREATE OR REPLACE PROCEDURE public.get_top_customers(p_limit INT, p_tier VARCHAR(20))
    RETURNS SETOF public.top_customer_result
    LANGUAGE plpgsql
AS $$
DECLARE
    v_row public.top_customer_result%ROWTYPE;
    v_sql VARCHAR(1000) = '
        SELECT
            c.first_name || '' '' || c.last_name AS customer_name,
            c.membership_tier,
            ROUND(SUM(f.total), 2)               AS total_spend,
            COUNT(DISTINCT f.transaction_id)     AS visits
        FROM samples.retail.fact_sales f
        JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key
        WHERE c.membership_tier = $2
        GROUP BY 1, 2
        ORDER BY total_spend DESC
        LIMIT $1';
BEGIN
    FOR v_row IN EXECUTE(v_sql) USING p_limit, p_tier
    LOOP
        RETURN NEXT v_row;
    END LOOP;
END;
$$;

-- Run it: Call the overloaded version (filter done in the query -- faster!)
SELECT * FROM public.get_top_customers(5::INT, 'Platinum');
-- Expected: Top 5 Platinum customers, spend ~$1.6M-$2.0M range

-- Modify it: Try 'Gold' tier instead
SELECT * FROM public.get_top_customers(5::INT, 'Gold');


-- ----- 3.3: Your turn -- write get_top_products ------------

-- Your turn:
-- Create a result-type table called public.top_product_result with columns:
--   product_name VARCHAR(200), category VARCHAR(50),
--   units_sold BIGINT, revenue NUMERIC(15,2)
--
-- Then create a procedure get_top_products(p_limit INT) that returns
-- the top N products by revenue, joined from fact_sales + dim_product.
--
-- Test it: SELECT * FROM public.get_top_products(5::INT);
-- Expected first row: a Toys & Games item with ~481K revenue
--
-- Solution (try yourself first!):

DROP TABLE IF EXISTS public.top_product_result;
CREATE TABLE public.top_product_result (
    product_name   VARCHAR(200),
    category       VARCHAR(50),
    units_sold     BIGINT,
    revenue        NUMERIC(15,2)
) DISTRIBUTE ON (product_name);

CREATE OR REPLACE PROCEDURE public.get_top_products(p_limit INT)
    RETURNS SETOF public.top_product_result
    LANGUAGE plpgsql
AS $$
DECLARE
    v_row public.top_product_result%ROWTYPE;
    v_sql VARCHAR(1000) = '
        SELECT
            p.name                 AS product_name,
            p.category,
            SUM(f.quantity)        AS units_sold,
            ROUND(SUM(f.total), 2) AS revenue
        FROM samples.retail.fact_sales f
        JOIN samples.retail.dim_product p ON f.product_key = p.product_key
        GROUP BY 1, 2
        ORDER BY revenue DESC
        LIMIT $1';
BEGIN
    FOR v_row IN EXECUTE(v_sql) USING p_limit
    LOOP
        RETURN NEXT v_row;
    END LOOP;
END;
$$;

SELECT * FROM public.get_top_products(5::INT);


-- ============================================================
-- PART 4: SAS to Yellowbrick SQL
-- ============================================================

-- ----- 4.1: PROC MEANS equivalent --------------------------

-- SAS code this replaces:
--   proc means data=sales sum mean max min;
--     class category;
--     var total;
--   run;

-- Run it: GROUP BY aggregation
SELECT
    p.category,
    COUNT(*)                    AS line_items,
    ROUND(SUM(f.total),   2)    AS total_revenue,
    ROUND(AVG(f.total),   2)    AS avg_sale,
    ROUND(MAX(f.total),   2)    AS max_sale,
    ROUND(MIN(f.total),   2)    AS min_sale
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_product p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;
-- Expected: 20 rows. Furniture leads ~$447M. All max_sale values ~$5,400.

-- Modify it: Add a HAVING clause to show only categories with
-- total revenue over $440M
SELECT
    p.category,
    ROUND(SUM(f.total), 2) AS total_revenue,
    ROUND(AVG(f.total), 2) AS avg_sale
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_product p ON f.product_key = p.product_key
GROUP BY p.category
HAVING ROUND(SUM(f.total), 2) > 440000000
ORDER BY total_revenue DESC;
-- Expected: 3 categories (Furniture, Clothing, Electronics)

-- Your turn: Write a PROC MEANS equivalent that reports
-- total revenue AND transaction count per STORE (join to dim_store).
-- Which store has the highest total revenue?


-- ----- 4.2: PROC FREQ equivalent ---------------------------

-- SAS code this replaces:
--   proc freq data=customers;
--     tables membership_tier;
--   run;

-- Run it: Frequency table with percentage
SELECT
    c.membership_tier,
    COUNT(DISTINCT f.transaction_id)                                 AS frequency,
    ROUND(100.0 * COUNT(DISTINCT f.transaction_id) /
          SUM(COUNT(DISTINCT f.transaction_id)) OVER (), 1)          AS pct
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_customer c ON f.customer_key = c.customer_key
GROUP BY 1
ORDER BY frequency DESC;
-- Expected: Bronze=49.7%, Silver=30.2%, Gold=15.1%, Platinum=5.0%

-- Modify it: Change to show frequency by CATEGORY instead of tier
SELECT
    p.category,
    COUNT(DISTINCT f.transaction_id)                                 AS frequency,
    ROUND(100.0 * COUNT(DISTINCT f.transaction_id) /
          SUM(COUNT(DISTINCT f.transaction_id)) OVER (), 1)          AS pct
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_product p ON f.product_key = p.product_key
GROUP BY 1
ORDER BY frequency DESC;

-- Your turn: Show a cross-tab style query: for each membership_tier,
-- show how many Weekday vs Weekend transactions they made.
-- Hint: use d.is_weekend from dim_date and CASE WHEN or conditional aggregation.


-- ----- 4.3: Set-based UPDATE (the anti-pattern fix) --------

-- Setup: create a staging table to work with
DROP TABLE IF EXISTS public.sales_staging;
CREATE TABLE public.sales_staging AS
SELECT
    f.transaction_id,
    f.total,
    'pending'::VARCHAR(20) AS review_status
FROM  samples.retail.fact_sales f
WHERE f.total > 4000
LIMIT 100;

-- Check initial state
SELECT review_status, COUNT(*) AS cnt
FROM   public.sales_staging
GROUP  BY review_status;
-- Expected: 100 rows, all 'pending'

-- Run it: The RIGHT way -- one set-based UPDATE for all rows at once
-- (instead of a cursor loop that fires 100 separate statements)
UPDATE public.sales_staging
SET    review_status = 'high_value'
WHERE  total > 4500;

-- Verify the result
SELECT review_status, COUNT(*) AS cnt
FROM   public.sales_staging
GROUP  BY review_status;
-- Expected: ~51 rows 'high_value', ~49 rows still 'pending'

-- Modify it: Reset all rows back to 'pending' with another set-based UPDATE
UPDATE public.sales_staging
SET    review_status = 'pending';

-- Modify it: Now flag rows by TWO conditions in a single CASE statement
UPDATE public.sales_staging
SET    review_status = CASE
           WHEN total > 4500 THEN 'high_value'
           WHEN total BETWEEN 4000 AND 4500 THEN 'medium_value'
           ELSE 'pending'
       END;

SELECT review_status, COUNT(*) AS cnt
FROM   public.sales_staging
GROUP  BY review_status;

-- Your turn: Write a single set-based UPDATE (no loops!) that
-- sets review_status = 'completed' for all rows where total > 4200.
-- Then verify with a SELECT COUNT(*).


-- ============================================================
-- PART 5: Python (Stretch)
-- ============================================================

-- These exercises use Python in a Jupyter notebook.
-- The SQL queries below are what you will pass to pd.read_sql().

-- 5.1: Connection test -- run this to verify your YB connection string works
SELECT current_database(), current_user, version();

-- 5.2: Pull category revenue into a DataFrame
-- Use this SQL in pd.read_sql() in your notebook:
SELECT
    p.category,
    ROUND(SUM(f.total), 2)           AS revenue,
    COUNT(DISTINCT f.transaction_id) AS transactions
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_product p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY revenue DESC;

-- 5.3: Monthly revenue for 2026 -- for a line chart
SELECT
    d.month_number,
    d.month_name,
    ROUND(SUM(f.total), 2) AS revenue
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_date d ON f.date_key = d.date_key
WHERE d.year = 2026
GROUP BY 1, 2
ORDER BY 1;

-- 5.4: Weekend vs Weekday revenue (for a grouped bar chart)
SELECT
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(DISTINCT f.transaction_id)   AS transactions,
    ROUND(SUM(f.total), 2)             AS revenue,
    ROUND(AVG(f.total), 2)             AS avg_sale
FROM  samples.retail.fact_sales f
JOIN  samples.retail.dim_date d ON f.date_key = d.date_key
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- CLEANUP (optional -- run at end of session)
-- ============================================================

DROP VIEW  IF EXISTS public.vw_sales_detail;
DROP VIEW  IF EXISTS public.vw_customer_spend;
DROP TABLE IF EXISTS public.sales_staging;
-- Note: leave top_customer_result, top_product_result, and procedures
-- in place if you want to re-run Part 3 exercises next session.
