use banking_analytics_project2;


SELECT count(*) FROM banking_analytics_project2.debit_credit_transactions;




-- ================================================================================
-- BANK DEBIT & CREDIT ANALYTICS -- SQL QUERIES
-- Table: debit_credit_transactions
-- Part 1: KPI queries from Loan_Analytics
-- Part 2: Extra real-world analyst scenario queries
-- ================================================================================


-- ================================================================================
-- PART 1: DEBIT & CREDIT DASHBOARD KPIs
-- ================================================================================

-- 1. Total Credit Amount
-- Definition: sum of Amount where Transaction Type = Credit.
SELECT SUM(amount) AS total_credit_amount
FROM debit_credit_transactions
WHERE transaction_type = 'Credit';


-- 2. Total Debit Amount
-- Definition: sum of Amount where Transaction Type = Debit.
SELECT SUM(amount) AS total_debit_amount
FROM debit_credit_transactions
WHERE transaction_type = 'Debit';


-- 3. Credit to Debit Ratio
-- Definition: Total Credit Amount / Total Debit Amount.
SELECT
    ROUND(
        SUM(CASE WHEN transaction_type = 'Credit' THEN amount ELSE 0 END)
        /
        NULLIF(SUM(CASE WHEN transaction_type = 'Debit' THEN amount ELSE 0 END), 0),
        4
    ) AS credit_to_debit_ratio
FROM debit_credit_transactions;


-- 4. Net Transaction Amount
-- Definition: Total Credit Amount - Total Debit Amount.
SELECT
    SUM(CASE WHEN transaction_type = 'Credit' THEN amount ELSE 0 END)
    -
    SUM(CASE WHEN transaction_type = 'Debit' THEN amount ELSE 0 END)
    AS net_transaction_amount
FROM debit_credit_transactions;


-- 5. Account Activity Ratio
-- Definition: number of transactions / account balance, per account.
-- (Uses each account's latest balance as the reference balance.)
SELECT
    t.account_number,
    COUNT(*) AS transaction_count,
    latest.balance AS latest_balance,
    ROUND(COUNT(*) / NULLIF(latest.balance, 0), 6) AS account_activity_ratio
FROM debit_credit_transactions t
JOIN (
    SELECT account_number, balance,
           ROW_NUMBER() OVER (PARTITION BY account_number ORDER BY transaction_date DESC) AS rn
    FROM debit_credit_transactions
) latest
    ON latest.account_number = t.account_number AND latest.rn = 1
GROUP BY t.account_number, latest.balance
ORDER BY account_activity_ratio DESC;


-- 6. Transactions per Day / Week / Month
-- Definition: transaction volume trend over time.

-- (a) Per day
SELECT transaction_date AS txn_day, COUNT(*) AS transaction_count
FROM debit_credit_transactions
GROUP BY transaction_date
ORDER BY txn_day;

-- (b) Per week (ISO year-week)
SELECT YEARWEEK(transaction_date, 3) AS txn_week, COUNT(*) AS transaction_count
FROM debit_credit_transactions
GROUP BY YEARWEEK(transaction_date, 3)
ORDER BY txn_week;

-- (c) Per month
SELECT DATE_FORMAT(transaction_date, '%Y-%m') AS txn_month, COUNT(*) AS transaction_count
FROM debit_credit_transactions
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY txn_month;


-- 7. Total Transaction Amount by Branch
-- Definition: sum of Amount grouped by Branch.
SELECT
    branch,
    SUM(amount) AS total_transaction_amount
FROM debit_credit_transactions
GROUP BY branch
ORDER BY total_transaction_amount DESC;


-- 8. Transaction Volume by Bank
-- Definition: sum of Amount grouped by Bank Name.
SELECT
    bank_name,
    SUM(amount) AS total_transaction_amount,
    COUNT(*)    AS transaction_count
FROM debit_credit_transactions
GROUP BY bank_name
ORDER BY total_transaction_amount DESC;


-- 9. Transaction Method Distribution
-- Definition: count and percentage of transactions grouped by Transaction Method.
SELECT
    transaction_method,
    COUNT(*) AS transaction_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM debit_credit_transactions), 2) AS pct_of_total
FROM debit_credit_transactions
GROUP BY transaction_method
ORDER BY transaction_count DESC;


-- 10. Branch Transaction Growth
-- Definition: % change in monthly transaction amount per branch, month over month.
WITH monthly_branch AS (
    SELECT
        branch,
        DATE_FORMAT(transaction_date, '%Y-%m') AS txn_month,
        SUM(amount) AS monthly_amount
    FROM debit_credit_transactions
    GROUP BY branch, DATE_FORMAT(transaction_date, '%Y-%m')
)
SELECT
    branch,
    txn_month,
    monthly_amount,
    LAG(monthly_amount) OVER (PARTITION BY branch ORDER BY txn_month) AS prev_month_amount,
    ROUND(
        100.0 * (monthly_amount - LAG(monthly_amount) OVER (PARTITION BY branch ORDER BY txn_month))
        / NULLIF(LAG(monthly_amount) OVER (PARTITION BY branch ORDER BY txn_month), 0),
        2
    ) AS pct_growth
FROM monthly_branch
ORDER BY branch, txn_month;


-- 11. High-Risk Transaction Flag
-- Definition: flag transactions exceeding a threshold amount.
-- NOTE: this dataset's amounts only range from ~100 to ~5000, so a placeholder
-- like 100,000 would never match anything. Using the ~95th percentile (4750)
-- as a data-driven "top ~5% largest transactions" threshold instead.
-- Replace with a specific threshold if your project brief gives one.
SELECT *
FROM debit_credit_transactions
WHERE amount > 4750
ORDER BY amount DESC;


-- 12. Suspicious Transaction Frequency
-- Definition: count of flagged high-risk transactions over a period (monthly).
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m') AS txn_month,
    COUNT(*) AS high_risk_transaction_count
FROM debit_credit_transactions
WHERE amount > 4750
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY txn_month;



-- ================================================================================
-- PART 2: REAL-WORLD ANALYST SCENARIO QUERIES
-- The kind of digging a transactions analyst does day-to-day: spotting VIPs,
-- flight-risk customers, unusual activity, and market share shifts.
-- ================================================================================

-- SCENARIO 1: Top 20 Customers by Transaction Volume (VIP Identification)
-- Business question: "Who are our highest-value customers by total money moved?
-- These are candidates for a relationship-manager / premium-service program."
SELECT
    customer_id,
    customer_name,
    COUNT(*)            AS transaction_count,
    SUM(amount)          AS total_transaction_volume
FROM debit_credit_transactions
GROUP BY customer_id, customer_name
ORDER BY total_transaction_volume DESC
LIMIT 20;


-- SCENARIO 2: Customer Balance Segmentation
-- Business question: "How do transaction behaviors differ across balance
-- tiers? Do high-balance customers transact differently than low-balance
-- ones? Useful for tailoring products/offers by wealth segment."
SELECT
    CASE
        WHEN balance < 3000 THEN 'Low Balance (<3000)'
        WHEN balance < 7000 THEN 'Medium Balance (3000-7000)'
        ELSE 'High Balance (7000+)'
    END AS balance_tier,
    COUNT(*)                    AS customer_count,
    ROUND(AVG(amount), 2)        AS avg_transaction_amount,
    ROUND(AVG(balance), 2)       AS avg_balance,
    SUM(CASE WHEN transaction_type = 'Credit' THEN 1 ELSE 0 END) AS credit_count,
    SUM(CASE WHEN transaction_type = 'Debit' THEN 1 ELSE 0 END)  AS debit_count
FROM debit_credit_transactions
GROUP BY balance_tier
ORDER BY avg_balance;


-- SCENARIO 3: Large Transaction Relative to Own Balance (Risk Flag)
-- Business question: "Which transactions are unusually large relative to
-- that customer's own account balance? A transaction using 80%+ of an
-- account's balance in one go is a meaningful risk/behavior signal, even
-- without transaction history to compare against."
SELECT
    customer_id,
    customer_name,
    account_number,
    amount,
    balance,
    ROUND(amount / balance, 2) AS amount_to_balance_ratio
FROM debit_credit_transactions
WHERE balance > 0
  AND (amount / balance) > 0.8
ORDER BY amount_to_balance_ratio DESC;


-- SCENARIO 4: Month-over-Month Overall Transaction Growth
-- Business question: "Is total transaction volume across the whole bank
-- growing or shrinking month to month?"
WITH monthly_totals AS (
    SELECT
        DATE_FORMAT(transaction_date, '%Y-%m') AS txn_month,
        SUM(amount) AS total_amount,
        COUNT(*)    AS total_transactions
    FROM debit_credit_transactions
    GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
)
SELECT
    txn_month,
    total_amount,
    total_transactions,
    ROUND(
        100.0 * (total_amount - LAG(total_amount) OVER (ORDER BY txn_month))
        / NULLIF(LAG(total_amount) OVER (ORDER BY txn_month), 0),
        2
    ) AS pct_growth_vs_prev_month
FROM monthly_totals
ORDER BY txn_month;


-- SCENARIO 5: Average Transaction Size by Method (Behavior Insight)
-- Business question: "Do customers use different payment methods for
-- different transaction sizes? E.g., are Bank Transfers used for larger
-- amounts than Debit Card swipes?"
SELECT
    transaction_method,
    COUNT(*)                     AS transaction_count,
    ROUND(AVG(amount), 2)         AS avg_transaction_amount,
    MIN(amount)                   AS min_amount,
    MAX(amount)                   AS max_amount
FROM debit_credit_transactions
GROUP BY transaction_method
ORDER BY avg_transaction_amount DESC;


-- SCENARIO 6: Weekday vs. Weekend Activity Pattern
-- Business question: "Is transaction activity meaningfully different on
-- weekends vs weekdays? Useful for staffing and system-load planning."
SELECT
    CASE
        WHEN DAYOFWEEK(transaction_date) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    COUNT(*)            AS transaction_count,
    SUM(amount)          AS total_amount,
    ROUND(AVG(amount), 2) AS avg_amount
FROM debit_credit_transactions
GROUP BY day_type;


-- SCENARIO 7: Bank Market Share by Transaction Volume
-- Business question: "What % share of total transaction value does each
-- bank represent? Useful for competitive benchmarking if this data spans
-- multiple partner banks."
SELECT
    bank_name,
    SUM(amount) AS total_amount,
    ROUND(100.0 * SUM(amount) / (SELECT SUM(amount) FROM debit_credit_transactions), 2) AS market_share_pct
FROM debit_credit_transactions
GROUP BY bank_name
ORDER BY market_share_pct DESC;


-- SCENARIO 8: Data Quality Check -- Debit Amount Exceeds Recorded Balance
-- Business question: "Are there any Debit transactions where the amount
-- withdrawn is larger than the account's recorded balance? In a real
-- banking system this shouldn't be possible without an overdraft facility
-- -- this flags likely data entry errors or a balance field that wasn't
-- updated correctly before export."
SELECT
    customer_id,
    customer_name,
    account_number,
    transaction_type,
    amount,
    balance,
    (amount - balance) AS amount_over_balance
FROM debit_credit_transactions
WHERE transaction_type = 'Debit'
  AND amount > balance
ORDER BY amount_over_balance DESC;


-- SCENARIO 9: Low-Balance / At-Risk Accounts
-- Business question: "Which accounts are currently sitting at a very low
-- balance? Could indicate financial distress or accounts likely to go
-- dormant/overdrawn."
SELECT
    account_number,
    customer_name,
    balance AS latest_balance,
    transaction_date AS as_of_date
FROM (
    SELECT
        account_number, customer_name, balance, transaction_date,
        ROW_NUMBER() OVER (PARTITION BY account_number ORDER BY transaction_date DESC) AS rn
    FROM debit_credit_transactions
) latest
WHERE rn = 1
ORDER BY latest_balance ASC
LIMIT 50;


-- SCENARIO 10: Branch Ranking -- Volume vs. Average Ticket Size
-- Business question: "Which branches process a lot of small transactions
-- vs. fewer, larger ones? Helps decide where to deploy staff vs. self-service
-- kiosks/ATMs."
SELECT
    branch,
    COUNT(*)               AS transaction_count,
    SUM(amount)             AS total_amount,
    ROUND(AVG(amount), 2)   AS avg_transaction_amount
FROM debit_credit_transactions
GROUP BY branch
ORDER BY avg_transaction_amount DESC;