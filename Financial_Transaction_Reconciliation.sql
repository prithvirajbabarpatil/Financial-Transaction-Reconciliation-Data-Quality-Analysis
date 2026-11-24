Create Database financial_reconciliation;
use financial_reconciliation;

RENAME TABLE internal_transactions_clean_12m TO internal_transactions_clean;

USE financial_reconciliation;
SHOW TABLES;

-- PHASE 1 : Database and table verification
SELECT COUNT(*)
FROM internal_transactions_clean;

SELECT COUNT(*)
FROM bank_transactions_clean;

USE financial_reconciliation;
DESCRIBE internal_transactions_clean;
DESCRIBE bank_transactions_clean;

-- PHASE 2 - Data Validation and cleaning checks
ALTER TABLE internal_transactions_clean MODIFY Transaction_Date Date, MODIFY Amount_INR Decimal(12,2);
ALTER TABLE bank_transactions_clean MODIFY Transaction_Date Date, MODIFY Amount_INR Decimal(12,2);

DESCRIBE internal_transactions_clean;
describe bank_transactions_clean;

SELECT * FROM internal_transactions_clean LIMIT 10;
SELECT * FROM bank_transactions_clean LIMIT 10;

 -- CHECK DUPLICATE TRANSACTIONS
 SELECT Transaction_ID, COUNT(*) AS Duplicate_Count
FROM internal_transactions_clean
GROUP BY Transaction_ID
HAVING COUNT(*) > 1;

SELECT Transaction_ID, COUNT(*) AS Duplicate_Count
FROM bank_transactions_clean
GROUP BY Transaction_ID
HAVING COUNT(*) > 1;

-- CHECK MISSSING VALUES 
SELECT
    SUM(Customer_ID IS NULL OR Customer_ID = '') AS Missing_Customer,
    SUM(Merchant_Category IS NULL OR Merchant_Category = '') AS Missing_Merchant,
    SUM(Transaction_Date IS NULL) AS Missing_Date,
    SUM(Amount_INR IS NULL) AS Missing_Amount
FROM internal_transactions_clean;

-- FOR BANK RECORDS
SELECT
    SUM(Reference_Number IS NULL OR Reference_Number = '') AS Missing_Reference,
    SUM(Transaction_Date IS NULL) AS Missing_Date,
    SUM(Amount_INR IS NULL) AS Missing_Amount
FROM bank_transactions_clean;

-- CHECK STANDARDIZED PAYMENT METHODS
SELECT Payment_Method, COUNT(*) AS Total_Transactions
FROM internal_transactions_clean
GROUP BY Payment_Method;

SELECT Payment_Method, COUNT(*) AS Total_Transactions
FROM bank_transactions_clean
GROUP BY Payment_Method;

-- CHECK TRANSACTION DATES
SELECT
    MIN(Transaction_Date) AS First_Transaction,
    MAX(Transaction_Date) AS Last_Transaction,
    COUNT(*) AS Total_Records
FROM internal_transactions_clean;

SELECT
    MIN(Transaction_Date) AS First_Transaction,
    MAX(Transaction_Date) AS Last_Transaction,
    COUNT(*) AS Total_Records
FROM bank_transactions_clean;

-- CHECK TRNSACTION AMOUNTS
SELECT
    MIN(Amount_INR) AS Minimum_Amount,
    MAX(Amount_INR) AS Maximum_Amount,
    AVG(Amount_INR) AS Average_Amount,
    SUM(Amount_INR) AS Total_Transaction_Value
FROM internal_transactions_clean;

SELECT
    MIN(Amount_INR) AS Minimum_Amount,
    MAX(Amount_INR) AS Maximum_Amount,
    AVG(Amount_INR) AS Average_Amount,
    SUM(Amount_INR) AS Total_Transaction_Value
FROM bank_transactions_clean;

-- PHASE 3 - Financial Transaction Reconciliation
-- FIND MATCHED TRANSACTION
SELECT
    i.Transaction_ID,
    i.Amount_INR AS Internal_Amount,
    b.Amount_INR AS Bank_Amount
FROM internal_transactions_clean i
INNER JOIN bank_transactions_clean b
    ON i.Transaction_ID = b.Transaction_ID
WHERE i.Amount_INR = b.Amount_INR;

-- FIND MISSING BANK TRANSACTIONS
SELECT
    i.Transaction_ID,
    i.Amount_INR,
    i.Transaction_Date
FROM internal_transactions_clean i
LEFT JOIN bank_transactions_clean b
    ON i.Transaction_ID = b.Transaction_ID
WHERE b.Transaction_ID IS NULL;

-- FIND AMOUNT MISMATCHES
SELECT
    i.Transaction_ID,
    i.Amount_INR AS Internal_Amount,
    b.Amount_INR AS Bank_Amount,
    ROUND(b.Amount_INR - i.Amount_INR, 2) AS Amount_Difference
FROM internal_transactions_clean i
INNER JOIN bank_transactions_clean b
    ON i.Transaction_ID = b.Transaction_ID
WHERE i.Amount_INR <> b.Amount_INR;

-- CREATE A COMPLETE RECONCILIATION VIEW
CREATE OR REPLACE VIEW transaction_reconciliation AS
SELECT
    i.Transaction_ID,
    i.Transaction_Date,
    i.Customer_ID,
    i.Payment_Method,
    i.Amount_INR AS Internal_Amount,
    b.Amount_INR AS Bank_Amount,
    b.Bank_Transaction_ID,
    CASE
        WHEN b.Transaction_ID IS NULL
            THEN 'Missing in Bank'
        WHEN i.Amount_INR <> b.Amount_INR
            THEN 'Amount Mismatch'
        ELSE 'Matched'
    END AS Reconciliation_Status,
    CASE
        WHEN b.Transaction_ID IS NULL THEN NULL
        ELSE ROUND(b.Amount_INR - i.Amount_INR, 2)
    END AS Amount_Difference
FROM internal_transactions_clean i
LEFT JOIN bank_transactions_clean b
    ON i.Transaction_ID = b.Transaction_ID;
    
    -- CHECK THE RESULT
    SELECT * FROM transaction_reconciliation;
    
-- Reconciliation Summary
SELECT
    Reconciliation_Status,
    COUNT(*) AS Total_Transactions
FROM transaction_reconciliation
GROUP BY Reconciliation_Status;

-- PHASE 4 - Business analysis using SQL
-- MONTHLY TRANSACTION ANALYSIS
SELECT
    DATE_FORMAT(Transaction_Date, '%Y-%m') AS Month,
    COUNT(*) AS Total_Transactions,
    SUM(Amount_INR) AS Total_Transaction_Value,
    AVG(Amount_INR) AS Average_Transaction_Value
FROM internal_transactions_clean
GROUP BY DATE_FORMAT(Transaction_Date, '%Y-%m')
ORDER BY Month;

-- PAYMENT METHOD ANALYSIS
SELECT
    Payment_Method,
    COUNT(*) AS Total_Transactions,
    SUM(Amount_INR) AS Total_Amount,
    AVG(Amount_INR) AS Average_Amount
FROM internal_transactions_clean
GROUP BY Payment_Method
ORDER BY Total_Amount DESC;

-- TRANSACTION STATUS ANALYSIS
SELECT
    Transaction_Status,
    COUNT(*) AS Total_Transactions,
    SUM(Amount_INR) AS Total_Amount
FROM internal_transactions_clean
GROUP BY Transaction_Status;

-- CALCULATE SUCESS AND FAILURE RATES
SELECT
    COUNT(*) AS Total_Transactions,
    SUM(Transaction_Status = 'Success') AS Successful,
    SUM(Transaction_Status = 'Failed') AS Failed,
    SUM(Transaction_Status = 'Pending') AS Pending,
    ROUND(
	SUM(Transaction_Status = 'Success') * 100.0
	/ COUNT(*), 2) AS Success_Rate,
    ROUND(
	SUM(Transaction_Status = 'Failed') * 100.0
	/ COUNT(*), 2) AS Failure_Rate
	FROM internal_transactions_clean;
    
    -- MERCHANT CATEGORY ANALYSIS
    SELECT
    Merchant_Category,
    COUNT(*) AS Total_Transactions,
    SUM(Amount_INR) AS Total_Amount
FROM internal_transactions_clean
GROUP BY Merchant_Category
ORDER BY Total_Amount DESC;

-- HIGHEST VALUE TRANSACTIONS
SELECT
    Transaction_ID,
    Transaction_Date,
    Payment_Method,
    Merchant_Category,
    Amount_INR
FROM internal_transactions_clean
ORDER BY Amount_INR DESC
LIMIT 10;

-- PHASE 5 - Data quality analysis
-- CHECK MISSING OR UNKNOWN VALUES
SELECT
    SUM(Customer_ID = 'Unknown') AS Unknown_Customers,
    SUM(Merchant_Category = 'Unknown') AS Unknown_Merchants
FROM internal_transactions_clean;

-- FOR BANK RECORDS
SELECT
    SUM(Reference_Number = 'Unknown') AS Unknown_References
FROM bank_transactions_clean;

-- RECONCILIATION RATE
SELECT
    COUNT(*) AS Total_Transactions,
    SUM(Reconciliation_Status = 'Matched') AS Matched,
    SUM(Reconciliation_Status <> 'Matched') AS Unmatched,
    ROUND(
	SUM(Reconciliation_Status = 'Matched') * 100.0
	/ COUNT(*), 2) AS Reconciliation_Rate
FROM transaction_reconciliation;

-- DATA QUALITY ISSUE SUMMARY
SELECT
    Reconciliation_Status,
    COUNT(*) AS Issue_Count
FROM transaction_reconciliation
GROUP BY Reconciliation_Status;

-- PHASE 6 - Prepare SQL views for Power BI 
-- VIEW 1: MONTHLY FINANCIAL SUMMARY
CREATE OR REPLACE VIEW vw_monthly_summary AS
SELECT
    DATE_FORMAT(Transaction_Date, '%Y-%m') AS Month,
    COUNT(*) AS Total_Transactions,
    SUM(Amount_INR) AS Total_Amount,
    SUM(Transaction_Status = 'Success') AS Successful,
    SUM(Transaction_Status = 'Failed') AS Failed,
    SUM(Transaction_Status = 'Pending') AS Pending
FROM internal_transactions_clean
GROUP BY DATE_FORMAT(Transaction_Date, '%Y-%m');

-- PAYMENT METHOD SUMMARY
-- VIEW 2 - CREATE OR REPLACE VIEW vw_payment_summary AS
SELECT
    Payment_Method,
    COUNT(*) AS Total_Transactions,
    SUM(Amount_INR) AS Total_Amount
FROM internal_transactions_clean
GROUP BY Payment_Method;

-- VIEW 3 - RECONCILIATION SUMMARY
CREATE OR REPLACE VIEW vw_reconciliation_summary AS
SELECT
    Reconciliation_Status,
    COUNT(*) AS Total_Transactions
FROM transaction_reconciliation
GROUP BY Reconciliation_Status;

-- VIEW 4 - DETAILED RECONCILIATION 
CREATE OR REPLACE VIEW vw_reconciliation_details AS
SELECT *
FROM transaction_reconciliation;

-- VERIFY ALL FOUR VIEWS
SHOW FULL TABLES
WHERE Table_type = "VIEW"; 
    