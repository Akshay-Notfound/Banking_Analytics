use banking_analytics_project2;

SELECT count(*) FROM banking_analytics_project2.banking_data;

-- ================================================================================
-- BANKING LOAN ANALYTICS -- SQL QUERIES
-- Table: banking_data
-- Part 1: KPI queries from Loan_Analytics.pptx (Slides 5, 6, 8)
-- Part 2: Extra real-world analyst scenario queries
-- ================================================================================


-- ================================================================================
-- PART 1: LOAN DASHBOARD KPIs
-- ================================================================================

-- 1. Total Loan Amount Funded
-- Definition: total monetary value of all loans disbursed to clients.
SELECT SUM(funded_amount) AS total_loan_amount_funded
FROM banking_data;


-- 2. Total Loans
-- Definition: total number of loans issued (active + closed).
SELECT COUNT(*) AS total_loans
FROM banking_data;


-- 3. Total Collection
-- Definition: total amount collected from borrowers (principal + interest + fees).
SELECT SUM(total_pymnt) AS total_collection
FROM banking_data;


-- 4. Total Interest
-- Definition: total revenue generated from interest on loans.
SELECT SUM(total_rrec_int) AS total_interest
FROM banking_data;


-- 5. Branch-Wise Performance (Interest, Fees, Total Revenue)
-- Definition: revenue breakdown by branch -- interest income, fees, combined revenue.
SELECT
    branch_name,
    SUM(total_rrec_int)  AS interest_revenue,
    SUM(total_fees)      AS fee_revenue,
    SUM(total_pymnt)     AS total_revenue
FROM banking_data
GROUP BY branch_name
ORDER BY total_revenue DESC;


-- 6. State-Wise Loan
-- Definition: distribution of loans across different states.
SELECT
    state_name,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
GROUP BY state_name
ORDER BY total_loan_amount DESC;


-- 7. Religion-Wise Loan
-- Definition: loan distribution categorized by clients' religious demographics.
SELECT
    religion,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
GROUP BY religion
ORDER BY total_loan_amount DESC;


-- 8. Product Group-Wise Loan
-- Definition: loan categorization by product type.
SELECT
    product_code,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
GROUP BY product_code
ORDER BY total_loan_amount DESC;


-- 9. Disbursement Trend
-- Definition: historical trend of loan disbursements over time (monthly).
SELECT
    DATE_FORMAT(disbursement_date, '%Y-%m') AS disbursement_month,
    COUNT(*)                                 AS loans_disbursed,
    SUM(funded_amount)                       AS amount_disbursed
FROM banking_data
WHERE disbursement_date IS NOT NULL
GROUP BY DATE_FORMAT(disbursement_date, '%Y-%m')
ORDER BY disbursement_month;


-- 10. Grade-Wise Loan
-- Definition: classification of loans by borrower credit grade -- portfolio risk.
SELECT
    grrade AS grade,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
WHERE grrade <> ''
GROUP BY grrade
ORDER BY grrade;


-- 11. Default Loan Count
-- Definition: total number of loans that have defaulted.
SELECT COUNT(*) AS default_loan_count
FROM banking_data
WHERE is_default_loan = 'Y';


-- 12. Delinquent Client Count
-- Definition: number of distinct clients who have missed payments / are overdue.
SELECT COUNT(DISTINCT client_id) AS delinquent_client_count
FROM banking_data
WHERE is_delinquent_loan = 'Y';


-- 13. Delinquent Loan Rate
-- Definition: % of loans in delinquency vs. total portfolio.
SELECT
    ROUND(
        100.0 * SUM(CASE WHEN is_delinquent_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS delinquent_loan_rate_pct
FROM banking_data;


-- 14. Default Loan Rate
-- Definition: % of defaulted loans relative to total portfolio.
SELECT
    ROUND(
        100.0 * SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS default_loan_rate_pct
FROM banking_data;


-- 15. Loan Status-Wise Loan
-- Definition: distribution of loans by current status.
SELECT
    loan_status,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
GROUP BY loan_status
ORDER BY total_loans DESC;


-- 16. Age Group-Wise Loan
-- Definition: loan allocation segmented by borrower age group.
SELECT
    age AS age_group,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
GROUP BY age
ORDER BY age_group;


-- 17. Loan Maturity
-- Definition: timeline until loans are fully repaid, based on term.
SELECT
    term,
    COUNT(*)            AS total_loans,
    SUM(loan_amount)     AS total_loan_amount
FROM banking_data
GROUP BY term
ORDER BY term;


-- 18. No Verified Loans
-- Definition: number of loans issued without proper verification.
SELECT COUNT(*) AS not_verified_loan_count
FROM banking_data
WHERE verification_status = 'Not Verified';



-- ================================================================================
-- PART 2: REAL-WORLD ANALYST SCENARIO QUERIES
-- The kind of extra digging a data analyst does beyond the standard KPI list --
-- looking for risk concentration, performance outliers, and portfolio health.
-- ================================================================================

-- SCENARIO 1: Recovery Rate by Grade
-- Business question: "Which credit grades are we actually collecting on well,
-- vs. which ones look risky on paper AND collect poorly?"
-- Recovery Rate = principal actually recovered / principal originally funded.
SELECT
    grrade AS grade,
    COUNT(*)                                            AS total_loans,
    SUM(funded_amount)                                   AS total_funded,
    SUM(total_rec_prncp)                                 AS total_principal_recovered,
    ROUND(100.0 * SUM(total_rec_prncp) / NULLIF(SUM(funded_amount), 0), 2) AS recovery_rate_pct
FROM banking_data
WHERE grrade <> ''
GROUP BY grrade
ORDER BY recovery_rate_pct ASC;


-- SCENARIO 2: Loan Officer Performance Leaderboard
-- Business question: "Which loan officers manage the most volume, and do any
-- of them have a default rate high enough to warrant a review?"
SELECT
    credif_officer_name,
    COUNT(*)                                            AS loans_managed,
    SUM(loan_amount)                                     AS total_loan_amount,
    SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END)      AS default_count,
    ROUND(100.0 * SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_pct
FROM banking_data
GROUP BY credif_officer_name
HAVING COUNT(*) >= 20              -- ignore officers with too few loans to be meaningful
ORDER BY default_rate_pct DESC
LIMIT 20;


-- SCENARIO 3: Loan Concentration Risk (Top Clients)
-- Business question: "How exposed are we to our biggest borrowers? If our top
-- 10 clients defaulted tomorrow, how much of the portfolio would we lose?"
SELECT
    client_id,
    client_name,
    COUNT(*)            AS number_of_loans,
    SUM(loan_amount)     AS total_borrowed
FROM banking_data
GROUP BY client_id, client_name
ORDER BY total_borrowed DESC
LIMIT 10;


-- SCENARIO 4: High-Risk Segment -- Low Grade + Delinquent + Unverified
-- Business question: "What does our worst-case risk stack look like -- loans
-- that are simultaneously low credit grade, delinquent, AND never verified?"
SELECT
    account_id,
    client_name,
    grrade,
    loan_amount,
    verification_status,
    is_delinquent_loan,
    is_default_loan
FROM banking_data
WHERE grrade IN ('F', 'G')
  AND is_delinquent_loan = 'Y'
  AND verification_status = 'Not Verified'
ORDER BY loan_amount DESC;


-- SCENARIO 5: Write-Off Impact Analysis
-- Business question: "How much money have we actually lost to write-offs, and
-- which branches/states are driving those losses?"
SELECT
    branch_name,
    state_name,
    COUNT(*)            AS written_off_loans,
    SUM(loan_amount)     AS total_written_off_amount
FROM banking_data
WHERE loan_status = 'Write Off'
GROUP BY branch_name, state_name
ORDER BY total_written_off_amount DESC;


-- SCENARIO 6: Interest Rate vs. Default Rate Correlation Check
-- Business question: "Are we correctly pricing risk? Higher interest rate
-- brackets should generally show higher default rates -- if they don't,
-- our underwriting/pricing model may need review."
SELECT
    CASE
        WHEN int_rate < 0.08 THEN 'Under 8%'
        WHEN int_rate < 0.12 THEN '8% - 12%'
        WHEN int_rate < 0.16 THEN '12% - 16%'
        WHEN int_rate < 0.20 THEN '16% - 20%'
        ELSE '20% and above'
    END AS interest_rate_bracket,
    COUNT(*)                                                    AS total_loans,
    ROUND(100.0 * SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_pct
FROM banking_data
GROUP BY interest_rate_bracket
ORDER BY MIN(int_rate);


-- SCENARIO 7: Repeat Client Analysis
-- Business question: "How many clients have taken more than one loan with us?
-- Repeat borrowers with clean repayment history are our lowest-risk growth
-- segment -- worth knowing how big that pool is."
SELECT
    client_id,
    client_name,
    COUNT(*)                                                     AS loan_count,
    SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END)       AS defaults_among_them
FROM banking_data
GROUP BY client_id, client_name
HAVING COUNT(*) > 1
ORDER BY loan_count DESC;


-- SCENARIO 8: Branch Health Scorecard (Revenue vs. Risk in one view)
-- Business question: "Give me one table ranking branches on both how much
-- money they bring in AND how risky their book is -- so we can spot branches
-- that look profitable but are quietly building up bad debt."
SELECT
    branch_name,
    COUNT(*)                                                     AS total_loans,
    SUM(loan_amount)                                              AS total_loan_amount,
    SUM(total_pymnt)                                              AS total_revenue,
    ROUND(100.0 * SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN is_delinquent_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) AS delinquent_rate_pct
FROM banking_data
GROUP BY branch_name
ORDER BY total_revenue DESC;


-- SCENARIO 9: Loans Nearing Maturity (Portfolio Runoff Forecast)
-- Business question: "Which loans are scheduled to mature in the next 90 days?
-- This tells collections/renewals teams what's coming up so they can plan
-- outreach for renewal or closure."
-- NOTE: this dataset's disbursement dates run 2016-01-11 to 2020-12-02, so we
-- use a fixed reference date INSIDE that range instead of CURDATE() (today's
-- real date), otherwise "next 90 days from today" matches nothing.
SET @as_of_date = '2022-01-01';   -- change this to whatever reference date fits your analysis

SELECT
    account_id,
    client_name,
    disbursement_date,
    term,
    DATE_ADD(
        disbursement_date,
        INTERVAL CAST(SUBSTRING_INDEX(term, ' ', 1) AS UNSIGNED) MONTH
    ) AS estimated_maturity_date
FROM banking_data
WHERE loan_status = 'Active Loan'
  AND disbursement_date IS NOT NULL
HAVING estimated_maturity_date BETWEEN @as_of_date AND DATE_ADD(@as_of_date, INTERVAL 90 DAY)
ORDER BY estimated_maturity_date;


-- SCENARIO 10: Gender vs. Home Ownership Loan Behavior
-- Business question: "Does home ownership status correlate with loan size or
-- risk differently across genders? Useful for tailoring product offers."
SELECT
    gender_id,
    home_ownership,
    COUNT(*)                                                    AS total_loans,
    ROUND(AVG(loan_amount), 2)                                   AS avg_loan_amount,
    ROUND(100.0 * SUM(CASE WHEN is_default_loan = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) AS default_rate_pct
FROM banking_data
GROUP BY gender_id, home_ownership
ORDER BY gender_id, home_ownership;