-- ============================================================
-- Module 5b Exercises: Efficient SQL — Performance Investigation
-- Environment: Yellowbrick Cloud Test Environment (version 7.4.3, 4 nodes)
-- Sample data:  samples.retail  (read-only, shared) — fact_sales is 351,556,736 rows
-- Build all helper tables in YOUR OWN database (db_<username>).
--
-- The loop for every exercise:
--   1. Tag the query with an inline /* comment */
--   2. Run it
--   3. EXPLAIN / EXPLAIN (ANALYZE) to see WHY
--   4. SELECT * FROM show_query_stats('<tag>') to read the metrics
--   5. Apply the fix, re-run, compare
--
-- Every CREATE below is preceded by DROP ... IF EXISTS so the script is re-runnable.
-- Numbers in comments were measured on this cluster (351M-row fact, 4 nodes).
-- ============================================================


-- ============================================================
-- SETUP
-- ============================================================

-- S.1  Confirm context and the sample data
SELECT current_database() AS my_db, current_user AS me;
SELECT count(*) FROM samples.retail.fact_sales;          -- 351,556,736

-- S.2  Query-stats helper — build ONCE in your own database.
--      Tag queries with an inline comment, e.g. /* ex1_bad */, because in
--      YB Manager every Run is a new session; the comment travels into the
--      query text in sys.log_query, so the lookup is session-independent.
--
--      MULTI-USER NOTE: this is a shared cluster, and sys.log_query can expose
--      other users' queries to privileged accounts. The procedure filters on
--      username = current_user so you only ever see YOUR OWN runs, even if
--      another student tags a query with the same /* exN_* */ comment. For extra
--      safety you can personalize tags, e.g. /* ex1_bad_<username> */.

DROP TABLE IF EXISTS qstat_rs;
CREATE TABLE qstat_rs (
  tag       VARCHAR(64),
  query_id  BIGINT,
  run_ms    NUMERIC(12,0),    -- pure execution time
  total_ms  NUMERIC(12,0),    -- incl. compile + queue
  read_mb   NUMERIC(12,1),    -- bytes read from storage
  net_mb    NUMERIC(12,1),    -- bytes redistributed across workers
  spill_mb  NUMERIC(12,1),    -- bytes spilled to disk
  rows_out  BIGINT
);

CREATE OR REPLACE PROCEDURE show_query_stats(p_tag VARCHAR)
  RETURNS SETOF qstat_rs
  LANGUAGE plpgsql AS $$
DECLARE r qstat_rs%ROWTYPE;
BEGIN
  FOR r IN
    SELECT SUBSTRING(query_text FROM '/[*] *([a-zA-Z0-9_]+) *[*]/'),
           query_id,
           ROUND(run_ms,0), ROUND(total_ms,0),
           ROUND(io_read_bytes           / 1024.0^2, 1),
           ROUND(io_network_bytes        / 1024.0^2, 1),
           ROUND(io_spill_space_bytes_max/ 1024.0^2, 1),
           rows_returned
    FROM   sys.log_query
    WHERE  username = current_user            -- only YOUR runs (multi-user safe)
      AND  query_text LIKE '%' || p_tag || '%'
      AND  query_text NOT LIKE '%sys.log_query%'
      AND  type IN ('select','ctas','insert','update','delete')
    ORDER  BY submit_time DESC
    LIMIT  20
  LOOP RETURN NEXT r; END LOOP;
END; $$;

-- Usage:
/* ex1_bad  */ SELECT count(*) FROM samples.retail.fact_sales WHERE date_key::VARCHAR LIKE '2025%';
/* ex1_good */ SELECT count(*) FROM samples.retail.fact_sales WHERE date_key BETWEEN 20250101 AND 20251231;
SELECT * FROM show_query_stats('ex1');

-- Note on this cluster (4 nodes): redistribution is real work. The EXPLAIN footer's
-- "Distributed" figure (e.g. 245.94MiB in Exercise 13) shows data crossing workers;
-- the "Network" field frequently still reads 0.00B on this build, so judge redistribution
-- by the DISTRIBUTE ON HASH node and the Distributed bytes, not net_mb alone. Yellowbrick
-- also pre-aggregates locally (GROUP BY PARTIAL) before shuffling.


-- ============================================================
-- 1. FILTERING — keep the column bare
-- ============================================================

-- Optional helper: a copy SORTED on date_key so range filters skip blocks.
DROP TABLE IF EXISTS my_fact_dt;
CREATE TABLE my_fact_dt AS
  SELECT * FROM samples.retail.fact_sales
  DISTRIBUTE ON (sales_key)
  SORT ON (date_key);

-- Offending: expression on the scanned column (cannot prune; estimate collapses)
/* ex1_bad  */ SELECT count(*) FROM samples.retail.fact_sales
               WHERE date_key::VARCHAR LIKE '2025%';
/* ex1_bad2 */ SELECT count(*) FROM samples.retail.fact_sales
               WHERE LOWER(discount_type) = 'percentage';

-- Find it: EXPLAIN ANALYZE ex1_bad -> rewritten to LEFT(date_key::VARCHAR,4)='2025',
--          no scan_constraints, rows_planned 1,757,784 vs rows_actual 221,559,040.
--          Read 1.63 GiB, ~1.5 s.
EXPLAIN ANALYZE SELECT count(*) FROM samples.retail.fact_sales WHERE date_key::VARCHAR LIKE '2025%';

-- Fix: bare column vs constant / constant-side range
/* ex1_good  */ SELECT count(*) FROM samples.retail.fact_sales
                WHERE date_key BETWEEN 20250101 AND 20251231;
/* ex1_good2 */ SELECT count(*) FROM samples.retail.fact_sales
                WHERE discount_type = 'percentage';

-- Verify: scan_constraints: min_max(date_key) present; rows_planned 221,503,644
--         (within 0.03% of the 221,559,040 actual). Read 1.77 GiB, ~0.85 s -- faster.
EXPLAIN ANALYZE SELECT count(*) FROM samples.retail.fact_sales WHERE date_key BETWEEN 20250101 AND 20251231;
-- On my_fact_dt the same range now skips blocks -> read and run_ms fall further.
EXPLAIN ANALYZE SELECT count(*) FROM my_fact_dt WHERE date_key BETWEEN 20250101 AND 20251231;


-- ============================================================
-- 2. JOINS — collocation, broadcast, join elimination
-- ============================================================

-- Part A: small dimension is broadcast (DISTRIBUTE REPLICATE); ~3.4 s, 1.19 GiB read.
/* ex2a */ EXPLAIN
SELECT c.membership_tier, count(*)
FROM   samples.retail.fact_sales f
JOIN   samples.retail.dim_customer c ON f.customer_key = c.customer_key
GROUP  BY c.membership_tier;

-- Swap the SELECT list for count(*) only -> the join is ELIMINATED via the FK
-- (and since the keys are clean, the count is identical -- the optimization is correct).
EXPLAIN SELECT count(*)
FROM   samples.retail.fact_sales f
JOIN   samples.retail.dim_customer c ON f.customer_key = c.customer_key;

-- Part B: redistribution you can design away
DROP TABLE IF EXISTS my_txn, my_sales_bad, my_sales_good;
CREATE TABLE my_txn AS
  SELECT transaction_id, SUM(total) AS txn_total
  FROM samples.retail.fact_sales GROUP BY transaction_id      -- ~1.0M rows
  DISTRIBUTE ON (transaction_id);
CREATE TABLE my_sales_bad  AS SELECT * FROM samples.retail.fact_sales DISTRIBUTE ON (sales_key);
CREATE TABLE my_sales_good AS SELECT * FROM samples.retail.fact_sales DISTRIBUTE ON (transaction_id);
ANALYZE my_txn; ANALYZE my_sales_bad; ANALYZE my_sales_good;   -- fresh stats!

/* ex2_bad  */ SELECT count(*) FROM my_sales_bad  s JOIN my_txn t ON s.transaction_id = t.transaction_id;
/* ex2_good */ SELECT count(*) FROM my_sales_good s JOIN my_txn t ON s.transaction_id = t.transaction_id;

-- NOTE: even at 351M rows the planner broadcasts the ~1.0M my_txn (DISTRIBUTE REPLICATE)
--       and scans the fact in place behind a bloom filter, so both variants land in the
--       same ballpark (~10 s, ~3.45 GiB). A 1M-row build side fits the broadcast threshold.
--       The redistribution you can clearly design away is the GROUP BY in Exercise 5.
--       Always ANALYZE after a CTAS.


-- ============================================================
-- 3. JOINS — implicit casts & expressions in ON
-- ============================================================

DROP TABLE IF EXISTS my_feed;
CREATE TABLE my_feed (
  customer_key BIGINT,            -- INT8 vs dim_customer.customer_key INT4
  amount NUMERIC(12,2)
) DISTRIBUTE ON (customer_key);
INSERT INTO my_feed
  SELECT customer_key, SUM(total) FROM samples.retail.fact_sales GROUP BY customer_key;

-- Offending: type mismatch, and a function on both sides of a text key
/* ex3_bad  */ SELECT count(*) FROM my_feed f
               JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key;
/* ex3_bad2 */ SELECT count(*)
               FROM samples.retail.dim_customer a
               JOIN samples.retail.dim_customer b ON UPPER(a.customer_id) = UPPER(b.customer_id);

-- Find it: plan shows  ON (c.customer_key::INT8 = f.customer_key::INT8)  and
--          calculate: f.customer_key::INT8  on the fact scan (per-row cast on 351M rows).
EXPLAIN SELECT count(*) FROM my_feed f
        JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key;
EXPLAIN ANALYZE SELECT count(*)
        FROM samples.retail.dim_customer a
        JOIN samples.retail.dim_customer b ON UPPER(a.customer_id) = UPPER(b.customer_id);

-- Fix: match the types, or materialize the expression as a stored column.
-- ALTER TABLE my_feed ... customer_key INTEGER;  -- then re-join the bare column.


-- ============================================================
-- 4. JOINS — order; CTE + OFFSET 0
-- ============================================================

/* ex4_bad */ SELECT count(*)
FROM samples.retail.fact_sales f
JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key
JOIN samples.retail.dim_product  p ON f.product_key  = p.product_key
JOIN samples.retail.dim_date     d ON f.date_key     = d.date_key
WHERE d.year = 2026;

/* ex4_good */
WITH fd AS (
  SELECT f.* FROM samples.retail.fact_sales f
  JOIN samples.retail.dim_date d ON f.date_key = d.date_key
  WHERE d.year = 2026
  OFFSET 0                              -- force this to materialize first
)
SELECT count(*)
FROM fd
JOIN samples.retail.dim_customer c ON fd.customer_key = c.customer_key
JOIN samples.retail.dim_product  p ON fd.product_key  = p.product_key;

-- Find it / Verify: with <=8 tables and good stats the planner already pushes the date
-- join first (136 date rows broadcast, fact bloom-filtered to ~130.0M; Read 2.56 GiB, ~1.5 s).
-- The CTE + OFFSET 0 lever bites at >8 tables or with bad estimates.


-- ============================================================
-- 5. AGGREGATION — GROUP BY on the distribution column
-- ============================================================

DROP TABLE IF EXISTS my_fact_bystore;
CREATE TABLE my_fact_bystore AS
  SELECT * FROM samples.retail.fact_sales DISTRIBUTE ON (store_key);

/* ex5_bad  */ SELECT count(*) FROM (SELECT customer_key FROM my_fact_bystore GROUP BY 1) q;
/* ex5_good */ SELECT count(*) FROM (SELECT store_key    FROM my_fact_bystore GROUP BY 1) q;

-- Find it: ex5_bad has DISTRIBUTE ON HASH(customer_key); ex5_good aggregates locally.
-- You can see the bad case directly on the base fact (hashed on sales_key):
EXPLAIN ANALYZE SELECT count(*) FROM (SELECT customer_key FROM samples.retail.fact_sales GROUP BY customer_key) q;


-- ============================================================
-- 6. AGGREGATION — COUNT(DISTINCT) on a columnar engine
-- ============================================================

-- Part A: a single distinct is already rewritten internally by YB 7.4.  ~6.0 s, 2.02 GiB.
/* ex6_one */ SELECT store_key, COUNT(DISTINCT transaction_id) AS dc
              FROM samples.retail.fact_sales GROUP BY store_key;
-- Plan: GROUP BY (store_key, transaction_id) -> GROUP BY (store_key).

-- Part B: three distincts -> three SCAN nodes, but each scan is COLUMNAR and reads only
--         store_key + its one key column. The three singles read store_key + one key each:
--           customer_key   1.49 GiB / ~2.1 s
--           product_key    1.16 GiB / ~1.0 s
--           transaction_id 2.02 GiB / ~6.0 s
--         Combined three-distinct = 4.67 GiB / ~12.2 s == the SUM. No wide-row penalty exists.
/* ex6_three */
SELECT store_key,
       COUNT(DISTINCT customer_key),
       COUNT(DISTINCT product_key),
       COUNT(DISTINCT transaction_id)
FROM samples.retail.fact_sales GROUP BY store_key;

-- Part C: the row-store "fix" that does NOT help on Yellowbrick.
--   Materializing the 4 base columns first looks like it avoids re-reading a wide table,
--   but columnar projection already reads only the needed columns. This rewrite ADDS a full
--   351M-row write to build "base" and then re-reads the same columns 3x -> strictly MORE I/O.
--   It is SLOWER, not faster. (Confirmed: the three distincts above already read just 4.67 GiB.)
/* ex6_fix_rowstore */   -- demonstrates the trap; expect it to be slower than ex6_three
DROP TABLE IF EXISTS base;
CREATE TEMP TABLE base AS
  SELECT store_key, customer_key, product_key, transaction_id
  FROM samples.retail.fact_sales
  DISTRIBUTE ON (store_key);
SELECT store_key,
       COUNT(DISTINCT customer_key),
       COUNT(DISTINCT product_key),
       COUNT(DISTINCT transaction_id)
FROM base GROUP BY store_key;

-- When materializing the source DOES pay off: when the distincts read from an expensive
-- non-materialized CTE or nested view (recomputed per distinct), or a spilling/memory-tight
-- plan -- then compute it once into a TEMP table (that is Exercise 7). For exact distinct
-- counts on a base table, the three-scan plan is already near-optimal; the only real lever is
-- to compute FEWER distincts (or use an approximate count where the engine supports it).


-- ============================================================
-- 7. MATERIALIZATION — CTAS/TEMP for stats and the right key
-- ============================================================

/* ex7_bad */
SELECT c.membership_tier, AVG(a.spend)
FROM samples.retail.dim_customer c
JOIN ( SELECT customer_key, SUM(total) AS spend
       FROM samples.retail.fact_sales GROUP BY customer_key ) a
  ON c.customer_key = a.customer_key
GROUP BY c.membership_tier;
-- Read 2.06 GiB, ~2.9 s.

/* ex7_good */
DROP TABLE IF EXISTS cust_spend;
CREATE TEMP TABLE cust_spend AS
  SELECT customer_key, SUM(total) AS spend
  FROM samples.retail.fact_sales GROUP BY customer_key
  DISTRIBUTE ON (customer_key);          -- right key + statistics now exist
ANALYZE cust_spend;
SELECT c.membership_tier, AVG(s.spend)
FROM samples.retail.dim_customer c
JOIN cust_spend s ON c.customer_key = s.customer_key
GROUP BY c.membership_tier;


-- ============================================================
-- 8. DML — set-based vs singleton; recreate vs large delete
-- ============================================================

DROP TABLE IF EXISTS my_sales, my_changes;
CREATE TABLE my_sales AS SELECT * FROM samples.retail.fact_sales DISTRIBUTE ON (sales_key);
CREATE TABLE my_changes AS
  SELECT sales_key, total*1.05 AS new_total
  FROM samples.retail.fact_sales WHERE discount_amount > 0 LIMIT 100000;

-- Offending (do not actually loop this): one-at-a-time, and a large in-place delete
-- UPDATE my_sales SET total = :v WHERE sales_key = :one_key;
-- DELETE FROM my_sales WHERE date_key < 20251001;

-- Fix: set-based update
/* ex8_setbased */
UPDATE my_sales t SET total = c.new_total
FROM   my_changes c WHERE t.sales_key = c.sales_key;

-- Fix: recreate instead of a large delete
/* ex8_recreate */
DROP TABLE IF EXISTS my_sales_new;
CREATE TABLE my_sales_new AS
  SELECT * FROM my_sales WHERE date_key >= 20251001
  DISTRIBUTE ON (sales_key) SORT ON (date_key);
-- then: DROP TABLE my_sales;  ALTER TABLE my_sales_new RENAME TO my_sales;

-- Verify: watch delete_info_bytes grow under the in-place delete
SELECT name, delete_info_bytes FROM sys.table WHERE name = 'my_sales';


-- ============================================================
-- 9. STORED PROCEDURES — push the predicate into the backend
-- ============================================================

DROP TABLE IF EXISTS store_rev_rs;
CREATE TABLE store_rev_rs (store_key INT, revenue NUMERIC(18,2));

CREATE OR REPLACE PROCEDURE store_rev() RETURNS SETOF store_rev_rs
LANGUAGE plpgsql AS $$
DECLARE r store_rev_rs%ROWTYPE;
BEGIN
  FOR r IN SELECT store_key, SUM(total)
           FROM samples.retail.fact_sales GROUP BY store_key
  LOOP RETURN NEXT r; END LOOP;
END; $$;

-- Offending: filter the output (whole set materializes on the manager first)
/* ex9_bad */ SELECT * FROM store_rev() WHERE store_key = 42;

-- Fix: argument pushed into the backend query
CREATE OR REPLACE PROCEDURE store_rev(a_store INT) RETURNS SETOF store_rev_rs
LANGUAGE plpgsql AS $$
DECLARE r store_rev_rs%ROWTYPE;
BEGIN
  FOR r IN SELECT store_key, SUM(total)
           FROM samples.retail.fact_sales
           WHERE store_key = a_store
           GROUP BY store_key
  LOOP RETURN NEXT r; END LOOP;
END; $$;
/* ex9_good */ SELECT * FROM store_rev(42);


-- ============================================================
-- 10. DATA TYPES — functions on hot columns; JSON cost
-- ============================================================

/* ex10_bad  */ SELECT count(*) FROM samples.retail.fact_sales
                WHERE UPPER(discount_type) = 'PERCENTAGE';     -- 73,802,944 rows; 1.34 GiB, ~2.9 s
/* ex10_good */ SELECT count(*) FROM samples.retail.fact_sales
                WHERE discount_type = 'percentage';
EXPLAIN SELECT count(*) FROM samples.retail.fact_sales WHERE UPPER(discount_type) = 'PERCENTAGE';

-- JSON: samples.retail.staging holds one semi-structured "data" column (the raw feed).
-- Per-row extraction is expensive at scale; extract fields into typed columns at load
-- (store as JSONB if queried repeatedly), then filter/aggregate the materialized column.
SELECT * FROM samples.retail.staging LIMIT 1;


-- ============================================================
-- 11. VIEWS — flatten a nested view
-- ============================================================

DROP VIEW IF EXISTS v_sales_top;
DROP VIEW IF EXISTS v_sales_enriched;
CREATE VIEW v_sales_enriched AS
  SELECT f.*, c.membership_tier, p.category, d.year
  FROM samples.retail.fact_sales f
  JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key
  JOIN samples.retail.dim_product  p ON f.product_key  = p.product_key
  JOIN samples.retail.dim_date     d ON f.date_key     = d.date_key;
CREATE VIEW v_sales_top AS SELECT * FROM v_sales_enriched WHERE year = 2026;

/* ex11_view */ SELECT category, count(*) FROM v_sales_top GROUP BY category;

-- Find it: compare EXPLAIN (ANALYZE) of the view query vs the equivalent inlined SQL.
-- Does the year = 2026 filter push down to the dim_date scan, or run late?
EXPLAIN ANALYZE SELECT category, count(*) FROM v_sales_top GROUP BY category;



-- ============================================================
-- 13. PLANNER HINTING — raising join_collapse_limit
-- ============================================================
-- A star join written across all 7 dimensions. Because the query references only the
-- dimension KEY columns (which also live on the fact), the planner ELIMINATES the
-- dim_employee / dim_payment_method / dim_time joins via the foreign keys; the four
-- remaining dims are broadcast. Heaviest query in the module: Read 3.94 GiB,
-- Distributed 245.94 MiB, ~22.7 s, ~4.6M group rows. To force a join to stay, reference
-- a NON-key attribute of that dimension.

/* ex13 */ EXPLAIN (ANALYZE) SETTING (join_collapse_limit = 12)
SELECT d.year, p.category, s.state, e.employee_key, pm.payment_method_key,
       t.time_key, c.membership_tier, count(*)
FROM samples.retail.fact_sales f
JOIN samples.retail.dim_date d            ON f.date_key = d.date_key
JOIN samples.retail.dim_product p         ON f.product_key = p.product_key
JOIN samples.retail.dim_customer c        ON f.customer_key = c.customer_key
JOIN samples.retail.dim_store s           ON f.store_key = s.store_key
JOIN samples.retail.dim_employee e        ON f.employee_key = e.employee_key
JOIN samples.retail.dim_payment_method pm ON f.payment_method_key = pm.payment_method_key
JOIN samples.retail.dim_time t            ON f.time_key = t.time_key
GROUP BY d.year, p.category, s.state, e.employee_key, pm.payment_method_key,
         t.time_key, c.membership_tier;
-- The footer echoes join_collapse_limit 12. Compare order/intermediates vs default (8).


-- ============================================================
-- 14. METHOD — read an EXPLAIN (ANALYZE) end to end
-- ============================================================

/* ex14 */ EXPLAIN (ANALYZE)
SELECT count(*) FROM my_fact_skew f
JOIN samples.retail.dim_customer c ON f.customer_key = c.customer_key;
-- Name the metric that's off (rows_planned vs rows_actual, DISTRIBUTE, read_efficiency,
-- skew), identify the node, propose one fix, re-measure. One change, one measurement.


-- ============================================================
-- CLEANUP — run at the end
-- ============================================================
DROP TABLE IF EXISTS my_fact_dt, my_txn, my_sales_bad, my_sales_good, my_feed,
                     my_fact_bystore, my_sales, my_changes, my_sales_new, my_fact_skew,
                     store_rev_rs;
DROP VIEW  IF EXISTS v_sales_top, v_sales_enriched;
DROP PROCEDURE IF EXISTS store_rev();
DROP PROCEDURE IF EXISTS store_rev(INT);
-- Keep qstat_rs + show_query_stats() if you want the stats helper for later modules.
