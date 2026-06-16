-- Module 6 Exercises: Working with JSON in Yellowbrick
-- Environment: Yellowbrick Cloud Test Environment
-- Sample data: samples.retail.staging (1,000,000 rows of raw JSON transactions)
-- NOTE: All JSON queries must run against a UTF-8 database.
--       Connect to the 'samples' database, or run from your db_<username>
--       which has access to samples.retail via cross-database notation.


-- ============================================================
-- PART 1: Explore the Staging Table
-- ============================================================

-- 1.1: How many transactions are in the staging table?
SELECT COUNT(*) AS transaction_count
FROM samples.retail.staging;

-- 1.2: What does a raw JSON row look like?
--      (Each row is one complete retail transaction as a single JSONB value)
SELECT data
FROM samples.retail.staging
LIMIT 1;

-- 1.2 MODIFY: Limit to 3 rows to compare transactions side by side
SELECT data
FROM samples.retail.staging
LIMIT 3;


-- ============================================================
-- PART 2: Your First JSON Extractions
-- ============================================================

-- 2.1: Extract the transaction ID from each row
--      Syntax: (column:$.field)::TYPE
SELECT (data:$.transactionId)::VARCHAR AS txn_id
FROM samples.retail.staging
LIMIT 5;

-- 2.1 MODIFY: Add the timestamp field
SELECT
    (data:$.transactionId)::VARCHAR   AS txn_id,
    (data:$.timestamp)::VARCHAR       AS txn_timestamp
FROM samples.retail.staging
LIMIT 5;

-- 2.1 YOUR TURN: Extract transactionId and the payment status
--   Hint: payment status is at data:$.payment.status
--   Expected: txn_id and status columns, all rows should show 'completed'
SELECT
    (data:$.transactionId)::VARCHAR     AS txn_id,
    (data:$.payment.status)::VARCHAR    AS pay_status
FROM samples.retail.staging
LIMIT 5;


-- 2.2: Navigate nested objects — extract customer fields
SELECT
    (data:$.customer.firstName)::VARCHAR      AS first_name,
    (data:$.customer.lastName)::VARCHAR       AS last_name,
    (data:$.customer.membershipTier)::VARCHAR AS tier
FROM samples.retail.staging
LIMIT 10;

-- 2.2 MODIFY: Add the store name and city
SELECT
    (data:$.customer.firstName)::VARCHAR      AS first_name,
    (data:$.customer.membershipTier)::VARCHAR AS tier,
    (data:$.store.storeName)::VARCHAR         AS store_name,
    (data:$.store.address.city)::VARCHAR      AS city
FROM samples.retail.staging
LIMIT 10;

-- 2.2 YOUR TURN: Write a query that shows customer email, store state,
--   and the store phone number for the first 8 transactions
--   Hints: data:$.customer.email | data:$.store.address.state | data:$.store.phone
SELECT
    (data:$.customer.email)::VARCHAR         AS email,
    (data:$.store.address.state)::VARCHAR    AS store_state,
    (data:$.store.phone)::VARCHAR            AS store_phone
FROM samples.retail.staging
LIMIT 8;


-- 2.3: Use proper SQL types — cast extracted values to numbers, booleans
SELECT
    (data:$.transactionId)::VARCHAR              AS txn_id,
    (data:$.summary.grandTotal)::DECIMAL(12,2)   AS grand_total,
    (data:$.summary.totalDiscount)::DECIMAL(12,2) AS total_discount,
    (data:$.receipt.emailed)::BOOLEAN            AS emailed
FROM samples.retail.staging
LIMIT 10;

-- 2.3 MODIFY: Add totalTax and shippingCost
SELECT
    (data:$.transactionId)::VARCHAR                AS txn_id,
    (data:$.summary.grandTotal)::DECIMAL(12,2)     AS grand_total,
    (data:$.summary.totalTax)::DECIMAL(12,2)       AS total_tax,
    (data:$.summary.shippingCost)::DECIMAL(12,2)   AS shipping_cost,
    (data:$.receipt.printed)::BOOLEAN              AS receipt_printed
FROM samples.retail.staging
LIMIT 10;

-- 2.3 YOUR TURN: Extract transactionId, grandTotal, and the number of items
--   in the transaction summary.
--   Hint: data:$.summary.subtotal (DECIMAL) and data:$.cashier.register (VARCHAR)
SELECT
    (data:$.transactionId)::VARCHAR              AS txn_id,
    (data:$.summary.subtotal)::DECIMAL(12,2)     AS subtotal,
    (data:$.cashier.register)::VARCHAR           AS register
FROM samples.retail.staging
LIMIT 10;


-- ============================================================
-- PART 3: Filtering JSON Data
-- ============================================================

-- 3.1: Filter by membership tier
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.customer.firstName)::VARCHAR       AS customer,
    (data:$.customer.membershipTier)::VARCHAR  AS tier,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.customer.membershipTier)::VARCHAR = 'Platinum'
LIMIT 10;

-- 3.1 MODIFY: Change the tier to 'Gold' — how many rows do you get?
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.customer.firstName)::VARCHAR       AS customer,
    (data:$.customer.membershipTier)::VARCHAR  AS tier,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.customer.membershipTier)::VARCHAR = 'Gold'
LIMIT 10;

-- 3.1 YOUR TURN: Find all transactions from customers in the 'Bronze' tier
--   where the grand total is more than 15,000.
--   Return: txn_id, customer first name, and grand_total. Limit to 10.
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.customer.firstName)::VARCHAR       AS customer,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.customer.membershipTier)::VARCHAR = 'Bronze'
  AND (data:$.summary.grandTotal)::DECIMAL(12,2) > 15000
LIMIT 10;


-- 3.2: Filter by payment method
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.payment.method)::VARCHAR           AS pay_method,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.payment.method)::VARCHAR = 'mobile_payment'
LIMIT 10;

-- 3.2 MODIFY: Find credit_card transactions over $10,000
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.payment.method)::VARCHAR           AS pay_method,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.payment.method)::VARCHAR = 'credit_card'
  AND (data:$.summary.grandTotal)::DECIMAL(12,2) > 10000
LIMIT 10;

-- 3.2 YOUR TURN: Find all transactions where the receipt was emailed (true)
--   AND the grand total is greater than $5,000.
--   Return: txn_id, customer first name, grand_total, emailed. Limit to 10.
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.customer.firstName)::VARCHAR       AS customer,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total,
    (data:$.receipt.emailed)::BOOLEAN          AS emailed
FROM samples.retail.staging
WHERE (data:$.receipt.emailed)::BOOLEAN = TRUE
  AND (data:$.summary.grandTotal)::DECIMAL(12,2) > 5000
LIMIT 10;


-- 3.3: Combine filters — Platinum customers paying by mobile_payment
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.customer.firstName)::VARCHAR       AS customer,
    (data:$.customer.membershipTier)::VARCHAR  AS tier,
    (data:$.payment.method)::VARCHAR           AS pay_method,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.customer.membershipTier)::VARCHAR = 'Platinum'
  AND (data:$.payment.method)::VARCHAR = 'mobile_payment'
LIMIT 10;

-- 3.3 MODIFY: Use IN to find Gold OR Platinum customers
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.customer.membershipTier)::VARCHAR  AS tier,
    (data:$.payment.method)::VARCHAR           AS pay_method,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.customer.membershipTier)::VARCHAR IN ('Gold', 'Platinum')
  AND (data:$.summary.grandTotal)::DECIMAL(12,2) > 8000
LIMIT 10;

-- 3.3 YOUR TURN: Find all transactions from the state of 'NY'
--   where the payment method is 'debit_card'.
--   Return: txn_id, city, state, pay_method, grand_total. Limit 10.
SELECT
    (data:$.transactionId)::VARCHAR            AS txn_id,
    (data:$.store.address.city)::VARCHAR       AS city,
    (data:$.store.address.state)::VARCHAR      AS state,
    (data:$.payment.method)::VARCHAR           AS pay_method,
    (data:$.summary.grandTotal)::DECIMAL(12,2) AS grand_total
FROM samples.retail.staging
WHERE (data:$.store.address.state)::VARCHAR = 'NY'
  AND (data:$.payment.method)::VARCHAR = 'debit_card'
LIMIT 10;


-- ============================================================
-- PART 4: NULL ON ERROR — Handling Optional Fields
-- ============================================================

-- 4.1: This WILL FAIL — cardType doesn't exist on mobile_payment rows
--      Run this to see the error, then fix it in 4.2
SELECT
    (data:$.transactionId)::VARCHAR             AS txn_id,
    (data:$.payment.method)::VARCHAR            AS pay_method,
    (data:$.payment.details.cardType)::VARCHAR  AS card_type
FROM samples.retail.staging
WHERE (data:$.payment.method)::VARCHAR = 'mobile_payment'
LIMIT 5;
-- Expected: ERROR — cannot cast NULL or missing JSON value to VARCHAR

-- 4.2: Fix it — add NULL ON ERROR after the path expression
SELECT
    (data:$.transactionId)::VARCHAR                           AS txn_id,
    (data:$.payment.method)::VARCHAR                          AS pay_method,
    (data:$.payment.details.cardType   NULL ON ERROR)::VARCHAR AS card_type,
    (data:$.payment.details.provider   NULL ON ERROR)::VARCHAR AS provider,
    (data:$.payment.details.lastFourDigits NULL ON ERROR)::VARCHAR AS last_four
FROM samples.retail.staging
LIMIT 15;

-- 4.2 MODIFY: Filter to only mobile_payment rows to clearly see NULL values
SELECT
    (data:$.transactionId)::VARCHAR                           AS txn_id,
    (data:$.payment.method)::VARCHAR                          AS pay_method,
    (data:$.payment.details.cardType   NULL ON ERROR)::VARCHAR AS card_type,
    (data:$.payment.details.provider   NULL ON ERROR)::VARCHAR AS provider
FROM samples.retail.staging
WHERE (data:$.payment.method)::VARCHAR = 'mobile_payment'
LIMIT 10;

-- 4.2 YOUR TURN: Write a query that shows all four payment methods side by side,
--   using NULL ON ERROR for cardType, provider, lastFourDigits, and transactionId
--   (mobile payment ID). Group your SELECT to make the differences clear.
--   Return at least: txn_id, pay_method, card_type, provider. No LIMIT.
SELECT
    (data:$.transactionId)::VARCHAR                               AS txn_id,
    (data:$.payment.method)::VARCHAR                              AS pay_method,
    (data:$.payment.details.cardType      NULL ON ERROR)::VARCHAR AS card_type,
    (data:$.payment.details.provider      NULL ON ERROR)::VARCHAR AS provider,
    (data:$.payment.details.lastFourDigits NULL ON ERROR)::VARCHAR AS last_four,
    (data:$.payment.details.transactionId NULL ON ERROR)::VARCHAR AS mobile_txn_id
FROM samples.retail.staging
ORDER BY pay_method
LIMIT 20;


-- ============================================================
-- PART 5: LATERAL FLATTEN — Expanding the Items Array
-- ============================================================

-- 5.1: Basic LATERAL FLATTEN — one output row per line item
--      FROM table AS alias, LATERAL FLATTEN(alias.col:$.array) AS flat_alias
SELECT
    (st.data:$.transactionId)::VARCHAR        AS txn_id,
    ((item.item):$.value.lineItemId)::INTEGER AS line_num,
    ((item.item):$.value.name)::VARCHAR       AS product_name,
    ((item.item):$.value.quantity)::INTEGER   AS qty
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
LIMIT 15;

-- 5.1 MODIFY: Add the product category
SELECT
    (st.data:$.transactionId)::VARCHAR          AS txn_id,
    ((item.item):$.value.lineItemId)::INTEGER   AS line_num,
    ((item.item):$.value.name)::VARCHAR         AS product_name,
    ((item.item):$.value.category)::VARCHAR     AS category,
    ((item.item):$.value.quantity)::INTEGER     AS qty
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
LIMIT 15;

-- 5.1 YOUR TURN: Write a flatten query showing txn_id, product_name,
--   unit_price (DECIMAL(10,2)), and line_total (DECIMAL(12,2)).
--   Limit to 15 rows.
SELECT
    (st.data:$.transactionId)::VARCHAR            AS txn_id,
    ((item.item):$.value.name)::VARCHAR           AS product_name,
    ((item.item):$.value.unitPrice)::DECIMAL(10,2) AS unit_price,
    ((item.item):$.value.total)::DECIMAL(12,2)    AS line_total
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
LIMIT 15;


-- 5.2: Full item detail — transaction context + item details
SELECT
    (st.data:$.transactionId)::VARCHAR              AS txn_id,
    (st.data:$.customer.membershipTier)::VARCHAR    AS tier,
    (st.data:$.payment.method)::VARCHAR             AS pay_method,
    ((item.item):$.value.lineItemId)::INTEGER       AS line_num,
    ((item.item):$.value.name)::VARCHAR             AS product_name,
    ((item.item):$.value.category)::VARCHAR         AS category,
    ((item.item):$.value.brand)::VARCHAR            AS brand,
    ((item.item):$.value.quantity)::INTEGER         AS qty,
    ((item.item):$.value.unitPrice)::DECIMAL(10,2)  AS unit_price,
    ((item.item):$.value.total)::DECIMAL(12,2)      AS line_total
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
LIMIT 20;

-- 5.2 MODIFY: Add the discount amount (use NULL ON ERROR — not every item has a discount)
SELECT
    (st.data:$.transactionId)::VARCHAR                               AS txn_id,
    ((item.item):$.value.name)::VARCHAR                              AS product_name,
    ((item.item):$.value.category)::VARCHAR                          AS category,
    ((item.item):$.value.quantity)::INTEGER                          AS qty,
    ((item.item):$.value.unitPrice)::DECIMAL(10,2)                   AS unit_price,
    ((item.item):$.value.discount.type   NULL ON ERROR)::VARCHAR     AS disc_type,
    ((item.item):$.value.discount.amount NULL ON ERROR)::DECIMAL(10,2) AS disc_amount,
    ((item.item):$.value.total)::DECIMAL(12,2)                       AS line_total
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
LIMIT 20;

-- 5.2 YOUR TURN: Write a flatten query showing the store city, customer tier,
--   product name, brand, and tax amount for each line item.
--   Use: data:$.store.address.city | data:$.customer.membershipTier
--        (item.item):$.value.name | (item.item):$.value.brand | (item.item):$.value.tax.amount
SELECT
    (st.data:$.store.address.city)::VARCHAR          AS city,
    (st.data:$.customer.membershipTier)::VARCHAR     AS tier,
    ((item.item):$.value.name)::VARCHAR              AS product_name,
    ((item.item):$.value.brand)::VARCHAR             AS brand,
    ((item.item):$.value.tax.amount)::DECIMAL(10,2)  AS tax_amount
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
LIMIT 20;


-- 5.3: FLATTEN + FILTER — only discounted items from Gold or Platinum customers
SELECT
    (st.data:$.customer.firstName)::VARCHAR                           AS customer,
    (st.data:$.customer.membershipTier)::VARCHAR                      AS tier,
    ((item.item):$.value.name)::VARCHAR                               AS product_name,
    ((item.item):$.value.category)::VARCHAR                           AS category,
    ((item.item):$.value.discount.type   NULL ON ERROR)::VARCHAR      AS disc_type,
    ((item.item):$.value.discount.amount NULL ON ERROR)::DECIMAL(10,2) AS disc_amount,
    ((item.item):$.value.total)::DECIMAL(12,2)                        AS line_total
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
WHERE (st.data:$.customer.membershipTier)::VARCHAR IN ('Gold', 'Platinum')
  AND ((item.item):$.value.discount.amount NULL ON ERROR)::DECIMAL(10,2) > 0
LIMIT 20;

-- 5.3 MODIFY: Change the filter to show only items in the 'Electronics' category
--   with a discount, regardless of customer tier
SELECT
    (st.data:$.transactionId)::VARCHAR                                AS txn_id,
    (st.data:$.customer.membershipTier)::VARCHAR                      AS tier,
    ((item.item):$.value.name)::VARCHAR                               AS product_name,
    ((item.item):$.value.discount.type   NULL ON ERROR)::VARCHAR      AS disc_type,
    ((item.item):$.value.discount.amount NULL ON ERROR)::DECIMAL(10,2) AS disc_amount,
    ((item.item):$.value.total)::DECIMAL(12,2)                        AS line_total
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
WHERE ((item.item):$.value.category)::VARCHAR = 'Electronics'
  AND ((item.item):$.value.discount.amount NULL ON ERROR)::DECIMAL(10,2) > 0
LIMIT 20;

-- 5.3 YOUR TURN: Find all Furniture or Clothing items bought using mobile_payment.
--   Return: txn_id, customer tier, product name, category, and line_total.
--   Limit to 15 rows.
SELECT
    (st.data:$.transactionId)::VARCHAR            AS txn_id,
    (st.data:$.customer.membershipTier)::VARCHAR  AS tier,
    ((item.item):$.value.name)::VARCHAR           AS product_name,
    ((item.item):$.value.category)::VARCHAR       AS category,
    ((item.item):$.value.total)::DECIMAL(12,2)    AS line_total
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
WHERE (st.data:$.payment.method)::VARCHAR = 'mobile_payment'
  AND ((item.item):$.value.category)::VARCHAR IN ('Furniture', 'Clothing')
LIMIT 15;


-- ============================================================
-- PART 6: Aggregating JSON Data
-- ============================================================

-- 6.1: Count transactions and total revenue by payment method
SELECT
    (data:$.payment.method)::VARCHAR                AS pay_method,
    COUNT(*)                                         AS txn_count,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2) AS total_revenue
FROM samples.retail.staging
GROUP BY 1
ORDER BY total_revenue DESC;

-- 6.1 MODIFY: Add the average transaction value
SELECT
    (data:$.payment.method)::VARCHAR                                  AS pay_method,
    COUNT(*)                                                           AS txn_count,
    ROUND(AVG((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS avg_total,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging
GROUP BY 1
ORDER BY total_revenue DESC;

-- 6.1 YOUR TURN: Count transactions and total revenue by the state where the store is located.
--   Show only states where total revenue exceeds $10,000,000. Order by revenue descending.
SELECT
    (data:$.store.address.state)::VARCHAR                             AS store_state,
    COUNT(*)                                                           AS txn_count,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging
GROUP BY 1
HAVING SUM((data:$.summary.grandTotal)::DECIMAL(12,2)) > 10000000
ORDER BY total_revenue DESC;


-- 6.2: Revenue by membership tier — how valuable are each tier's customers?
SELECT
    (data:$.customer.membershipTier)::VARCHAR                         AS tier,
    COUNT(*)                                                           AS txn_count,
    ROUND(AVG((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS avg_order_value,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging
GROUP BY 1
ORDER BY total_revenue DESC;

-- 6.2 MODIFY: Add total discount and see the discount rate for each tier
SELECT
    (data:$.customer.membershipTier)::VARCHAR                          AS tier,
    COUNT(*)                                                            AS txn_count,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)          AS total_revenue,
    ROUND(SUM((data:$.summary.totalDiscount)::DECIMAL(12,2)), 2)       AS total_discounts,
    ROUND(
        100.0 * SUM((data:$.summary.totalDiscount)::DECIMAL(12,2))
              / NULLIF(SUM((data:$.summary.subtotal)::DECIMAL(12,2)), 0)
    , 2)                                                                AS discount_rate_pct
FROM samples.retail.staging
GROUP BY 1
ORDER BY total_revenue DESC;

-- 6.2 YOUR TURN: Find the top 5 states by total revenue from Gold-tier customers only.
--   Return: state, txn_count, total_revenue. Order by total_revenue descending.
SELECT
    (data:$.store.address.state)::VARCHAR                             AS store_state,
    COUNT(*)                                                           AS txn_count,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging
WHERE (data:$.customer.membershipTier)::VARCHAR = 'Gold'
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 5;


-- 6.3: Category revenue using LATERAL FLATTEN + GROUP BY
SELECT
    ((item.item):$.value.category)::VARCHAR                           AS category,
    COUNT(*)                                                           AS items_sold,
    SUM(((item.item):$.value.quantity)::INTEGER)                      AS total_units,
    ROUND(SUM(((item.item):$.value.total)::DECIMAL(12,2)), 2)         AS category_revenue
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
GROUP BY 1
ORDER BY category_revenue DESC;

-- 6.3 MODIFY: Limit to Platinum-tier customers only and add the avg line price
SELECT
    ((item.item):$.value.category)::VARCHAR                             AS category,
    COUNT(*)                                                             AS items_sold,
    ROUND(AVG(((item.item):$.value.unitPrice)::DECIMAL(10,2)), 2)       AS avg_unit_price,
    ROUND(SUM(((item.item):$.value.total)::DECIMAL(12,2)), 2)           AS category_revenue
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
WHERE (st.data:$.customer.membershipTier)::VARCHAR = 'Platinum'
GROUP BY 1
ORDER BY category_revenue DESC;

-- 6.3 YOUR TURN: Using LATERAL FLATTEN, find the top 5 brands by total revenue
--   across all transactions and all tiers.
--   Return: brand, items_sold, total_revenue. Order by total_revenue descending.
SELECT
    ((item.item):$.value.brand)::VARCHAR                              AS brand,
    COUNT(*)                                                           AS items_sold,
    ROUND(SUM(((item.item):$.value.total)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 5;


-- ============================================================
-- STRETCH: Open-Ended Business Questions
-- ============================================================

-- S.1: Which day of the week generates the most revenue?
--      Hint: Use EXTRACT(DOW FROM (data:$.timestamp)::TIMESTAMP)
--      DOW: 0=Sunday, 1=Monday, ... 6=Saturday
SELECT
    EXTRACT(DOW FROM TO_TIMESTAMP(
        REPLACE(REPLACE((data:$.timestamp)::VARCHAR, 'T', ' '), 'Z', ''),
        'YYYY-MM-DD HH24:MI:SS.US'
    ))::INTEGER                                                       AS day_of_week,
    COUNT(*)                                                           AS txn_count,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging
GROUP BY 1
ORDER BY total_revenue DESC;

-- S.2: What percentage of transactions have at least one discounted item?
--      Use FLATTEN and check if discount.amount > 0
SELECT
    COUNT(DISTINCT (st.data:$.transactionId)::VARCHAR)                 AS txns_with_discounts,
    (SELECT COUNT(*) FROM samples.retail.staging)                      AS total_txns,
    ROUND(
        100.0 * COUNT(DISTINCT (st.data:$.transactionId)::VARCHAR)
              / (SELECT COUNT(*) FROM samples.retail.staging)
    , 2)                                                                AS pct_with_discounts
FROM samples.retail.staging AS st,
     LATERAL FLATTEN(st.data:$.items) AS item
WHERE ((item.item):$.value.discount.amount NULL ON ERROR)::DECIMAL(10,2) > 0;

-- S.3: For mobile_payment transactions, who is the provider (Apple Pay, Google Pay, etc.)?
--      Which provider has the highest average order value?
SELECT
    (data:$.payment.details.provider NULL ON ERROR)::VARCHAR          AS provider,
    COUNT(*)                                                           AS txn_count,
    ROUND(AVG((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS avg_order_value,
    ROUND(SUM((data:$.summary.grandTotal)::DECIMAL(12,2)), 2)         AS total_revenue
FROM samples.retail.staging
WHERE (data:$.payment.method)::VARCHAR = 'mobile_payment'
GROUP BY 1
ORDER BY avg_order_value DESC;

-- S.4: Write your own business question and answer it using JSON SQL.
--      Ideas:
--      - Which store city has the highest average transaction value?
--      - What is the average number of items per transaction by membership tier?
--      - Which membership tier has the highest discount rate?
