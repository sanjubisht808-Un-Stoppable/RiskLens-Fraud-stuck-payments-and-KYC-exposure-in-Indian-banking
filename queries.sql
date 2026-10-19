-- RiskLens: Indian Banking Transactions Analysis
-- Database: bank_project | Table: transactions (550,000 rows)
-- Before running: create the transactions table from the Python-generated CREATE TABLE statement.

-- ======================================================================
-- A1. Create the database and select it.
-- Expected: No error. (Error 1007 only means the database already exists, which is harmless.)
-- ======================================================================
CREATE DATABASE IF NOT EXISTS bank_project;
USE bank_project;

-- ======================================================================
-- A2. Load the cleaned CSV into the transactions table.
-- Expected: 550000 row(s) affected.
-- ======================================================================
SHOW VARIABLES LIKE 'secure_file_priv';

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions_clean.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- ======================================================================
-- A3. Did all 550,000 rows arrive?
-- Expected: 550000
-- ======================================================================
SELECT COUNT(*) AS total_rows FROM transactions;

-- ======================================================================
-- A4. Do the five headline numbers match the Python results?
-- Expected: 550000 | 0.89 | 58.2 | 135.7 | 203.1
-- ======================================================================
SELECT COUNT(*)                                   AS total_rows,
       ROUND(AVG(is_fraud) * 100, 2)              AS fraud_rate_pct,
       ROUND(SUM(fraud_amount) / 1e7, 1)          AS fraud_crore,
       ROUND(SUM(CASE WHEN is_not_success = 1 THEN transaction_amount END) / 1e7, 1)   AS not_success_crore,
       ROUND(SUM(CASE WHEN kyc_not_verified = 1 THEN transaction_amount END) / 1e7, 1) AS kyc_crore
FROM transactions;

-- ======================================================================
-- B1. Where should the fraud team look: by number of cases or by rupees?
-- Expected: RTGS 611 cases, 38.56 cr; Cheque 256, 10.60; NEFT 581, 6.92; UPI 1,211 cases but only 0.16 cr.
-- ======================================================================
SELECT transaction_type,
       COUNT(*)                            AS txns,
       SUM(is_fraud)                       AS fraud_cnt,
       ROUND(AVG(is_fraud) * 100, 2)       AS fraud_rate_pct,
       ROUND(SUM(fraud_amount) / 1e7, 2)   AS fraud_crore
FROM transactions
GROUP BY transaction_type
ORDER BY fraud_crore DESC;

-- ======================================================================
-- B2. Is there an amount threshold where the fraud rate jumps?
-- Expected: Up to 5L: 543,975 txns, 0.80%, 9.19 cr. Above 5L: 6,025 txns, 8.22%, 49.01 cr (about 84% of fraud value).
-- ======================================================================
SELECT CASE WHEN transaction_amount > 500000 THEN 'Above 5L' ELSE 'Up to 5L' END AS segment,
       COUNT(*)                            AS txns,
       ROUND(AVG(is_fraud) * 100, 2)       AS fraud_rate_pct,
       ROUND(SUM(fraud_amount) / 1e7, 2)   AS fraud_crore
FROM transactions
GROUP BY segment;

-- ======================================================================
-- B3. If reviewers can check only the top 1%, 5% or 10% of transactions (largest first), how much fraud do they catch?
-- Expected: 1%: 80.6 / 9.3. 5%: 93.1 / 14.1. 10%: 96.4 / 18.6 (value % / cases %). Ties in amount can shift a value by about 0.1.
-- ======================================================================
WITH ranked AS (
    SELECT is_fraud, fraud_amount,
           ROW_NUMBER() OVER (ORDER BY transaction_amount DESC) AS rn
    FROM transactions
),
cum AS (
    SELECT rn,
           SUM(fraud_amount) OVER (ORDER BY rn ROWS UNBOUNDED PRECEDING) AS cum_amt,
           SUM(is_fraud)     OVER (ORDER BY rn ROWS UNBOUNDED PRECEDING) AS cum_cnt
    FROM ranked
),
tot AS (
    SELECT SUM(fraud_amount) AS t_amt, SUM(is_fraud) AS t_cnt, COUNT(*) AS n
    FROM transactions
)
SELECT p.pct                                     AS top_pct_reviewed,
       ROUND(c.cum_amt / t.t_amt * 100, 1)       AS fraud_value_caught_pct,
       ROUND(c.cum_cnt / t.t_cnt * 100, 1)       AS fraud_cases_caught_pct
FROM (SELECT 1 AS pct UNION ALL SELECT 5 UNION ALL SELECT 10) p
CROSS JOIN tot t
JOIN cum c ON c.rn = CEIL(t.n * p.pct / 100);

-- ======================================================================
-- C1. How much money is stuck, and in which payment types?
-- Expected: Failure rate about 8% for every type. Stuck value: RTGS 71.67, Cheque 25.73, NEFT 22.41, Net_Banking 6.55, IMPS 4.35 (crore).
-- ======================================================================
SELECT transaction_type,
       ROUND(AVG(is_not_success) * 100, 2) AS fail_rate_pct,
       ROUND(SUM(CASE WHEN is_not_success = 1 THEN transaction_amount ELSE 0 END) / 1e7, 2) AS stuck_crore
FROM transactions
GROUP BY transaction_type
ORDER BY stuck_crore DESC;

-- ======================================================================
-- C2. How is the stuck value split by status?
-- Expected: Failed 69.69, Pending 33.45, Reversed 32.58 (crore).
-- ======================================================================
SELECT transaction_status,
       ROUND(SUM(transaction_amount) / 1e7, 2) AS crore
FROM transactions
WHERE transaction_status <> 'Success'
GROUP BY transaction_status;

-- ======================================================================
-- D1. How many high-value transactions (Rs 10 lakh or more) moved while KYC was not verified?
-- Expected: 218 transactions, 38.5 crore.
-- ======================================================================
SELECT COUNT(*) AS txns, ROUND(SUM(transaction_amount) / 1e7, 1) AS crore
FROM transactions
WHERE kyc_not_verified = 1 AND transaction_amount >= 1000000;

-- ======================================================================
-- D2. Which are the top 3 states for KYC exposure within each payment type?
-- Expected: For ATM_Withdrawal: Maharashtra 0.31, Karnataka 0.24, then Tamil Nadu and Delhi tied at 0.20. RANK() gives ties the same rank, so four rows appear.
-- ======================================================================
WITH exposure AS (
    SELECT transaction_type, state,
           ROUND(SUM(transaction_amount) / 1e7, 2) AS crore
    FROM transactions
    WHERE kyc_not_verified = 1
    GROUP BY transaction_type, state
)
SELECT * FROM (
    SELECT transaction_type, state, crore,
           RANK() OVER (PARTITION BY transaction_type ORDER BY crore DESC) AS rnk
    FROM exposure
) x
WHERE rnk <= 3
ORDER BY transaction_type, rnk;

-- ======================================================================
-- E1. Speed up dashboard queries with indexes.
-- Expected: Six new indexes plus the primary key.
-- ======================================================================
CREATE INDEX idx_txn_type  ON transactions (transaction_type);
CREATE INDEX idx_state     ON transactions (state);
CREATE INDEX idx_date      ON transactions (transaction_date);
CREATE INDEX idx_status    ON transactions (transaction_status);
CREATE INDEX idx_kyc       ON transactions (kyc_status);
CREATE INDEX idx_fraud     ON transactions (is_fraud);

SHOW INDEX FROM transactions;

-- ======================================================================
-- E2. Create saved summary views for each business problem.
-- Expected: Five views created (check with E4).
-- ======================================================================
CREATE OR REPLACE VIEW vw_fraud_by_type AS
SELECT transaction_type,
       COUNT(*)                            AS txns,
       SUM(is_fraud)                       AS fraud_cnt,
       ROUND(AVG(is_fraud) * 100, 2)       AS fraud_rate_pct,
       ROUND(SUM(fraud_amount) / 1e7, 2)   AS fraud_crore
FROM transactions
GROUP BY transaction_type;

CREATE OR REPLACE VIEW vw_fraud_by_segment AS
SELECT CASE WHEN transaction_amount > 500000 THEN 'Above 5L' ELSE 'Up to 5L' END AS segment,
       COUNT(*)                            AS txns,
       ROUND(AVG(is_fraud) * 100, 2)       AS fraud_rate_pct,
       ROUND(SUM(fraud_amount) / 1e7, 2)   AS fraud_crore
FROM transactions
GROUP BY segment;

CREATE OR REPLACE VIEW vw_stuck_money AS
SELECT transaction_type,
       transaction_status,
       COUNT(*)                                 AS txns,
       ROUND(SUM(transaction_amount) / 1e7, 2)  AS crore
FROM transactions
WHERE transaction_status <> 'Success'
GROUP BY transaction_type, transaction_status;

CREATE OR REPLACE VIEW vw_kyc_exposure AS
SELECT state,
       transaction_type,
       kyc_status,
       COUNT(*)                                 AS txns,
       ROUND(SUM(transaction_amount) / 1e7, 2)  AS crore
FROM transactions
WHERE kyc_not_verified = 1
GROUP BY state, transaction_type, kyc_status;

CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT year, month,
       COUNT(*)                                 AS txns,
       ROUND(SUM(transaction_amount) / 1e7, 2)  AS value_crore,
       ROUND(AVG(is_fraud) * 100, 2)            AS fraud_rate_pct,
       ROUND(AVG(is_not_success) * 100, 2)      AS fail_rate_pct
FROM transactions
GROUP BY year, month;

-- ======================================================================
-- E3. Save the capacity curve (1% to 20%) as a real table.
-- Expected: 20 rows. Takes up to a minute.
-- ======================================================================
CREATE TABLE capacity_curve AS
WITH RECURSIVE pcts AS (
    SELECT 1 AS pct
    UNION ALL
    SELECT pct + 1 FROM pcts WHERE pct < 20
),
ranked AS (
    SELECT is_fraud, fraud_amount,
           ROW_NUMBER() OVER (ORDER BY transaction_amount DESC) AS rn
    FROM transactions
),
cum AS (
    SELECT rn,
           SUM(fraud_amount) OVER (ORDER BY rn ROWS UNBOUNDED PRECEDING) AS cum_amt,
           SUM(is_fraud)     OVER (ORDER BY rn ROWS UNBOUNDED PRECEDING) AS cum_cnt
    FROM ranked
),
tot AS (
    SELECT SUM(fraud_amount) AS t_amt, SUM(is_fraud) AS t_cnt, COUNT(*) AS n
    FROM transactions
)
SELECT p.pct                                AS top_pct_reviewed,
       ROUND(c.cum_amt / t.t_amt * 100, 1)  AS fraud_value_caught_pct,
       ROUND(c.cum_cnt / t.t_cnt * 100, 1)  AS fraud_cases_caught_pct
FROM pcts p
CROSS JOIN tot t
JOIN cum c ON c.rn = CEIL(t.n * p.pct / 100);

-- ======================================================================
-- E4. Confirm the views and the capacity table exist.
-- Expected: Five views; capacity_curve count is 20; vw_fraud_by_segment shows 543,975 and 6,025 transactions.
-- ======================================================================
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SELECT COUNT(*) FROM capacity_curve;
SELECT * FROM vw_fraud_by_segment;
