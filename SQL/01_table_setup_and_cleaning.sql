-- ============================================================
-- 01_table_setup_and_cleaning.sql
-- Retail Business Performance & Profitability Analysis
-- Purpose: Create raw table, import data, clean dates,
--          deduplicate, and build the analysis-ready table
-- ============================================================

CREATE DATABASE retail_analysis;
USE retail_analysis;

-- ------------------------------------------------------------
-- 1. Raw table structure
-- ------------------------------------------------------------
CREATE TABLE online_retail (
    Invoice     VARCHAR(20),
    StockCode   VARCHAR(20),
    Description VARCHAR(255),
    Quantity    INT,
    InvoiceDate DATETIME,
    Price       DECIMAL(10,2),
    CustomerID  VARCHAR(20),
    Country     VARCHAR(50)
);

-- InvoiceDate later had to be relaxed to VARCHAR because the
-- source CSV export mixed text dates with Excel serial numbers,
-- which DATETIME would not accept on import.
ALTER TABLE online_retail MODIFY InvoiceDate VARCHAR(30);
ALTER TABLE online_retail ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY;

-- Data imported here via MySQL Workbench Table Data Import Wizard
-- (source: Online Retail II dataset, UCI Machine Learning Repository)

SELECT COUNT(*) FROM online_retail;


-- ------------------------------------------------------------
-- 2. Deduplicate
--    Multiple import passes (chunked imports while troubleshooting
--    file size / encoding issues) introduced exact-duplicate rows.
-- ------------------------------------------------------------
SELECT COUNT(*) FROM (
    SELECT Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country, COUNT(*) AS cnt
    FROM online_retail
    GROUP BY Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country
    HAVING cnt > 1
) AS duplicates;

SELECT Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country, COUNT(*) AS cnt
FROM online_retail
GROUP BY Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country
HAVING cnt > 1
ORDER BY cnt DESC
LIMIT 10;

-- Rebuild the table keeping only unique rows (GROUP BY is far
-- faster here than a self-join DELETE on 500K+ rows, which
-- repeatedly hit lock-wait timeouts).
CREATE TABLE online_dedup AS
SELECT Invoice, StockCode, Description, Quantity, InvoiceDate, Price, CustomerID, Country
FROM online_retail
GROUP BY Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country, Description, Price;

SELECT COUNT(*) FROM online_dedup;

-- Confirm no duplicates remain
SELECT COUNT(*) FROM (
    SELECT Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country, Description, Price, COUNT(*) AS cnt
    FROM online_dedup
    GROUP BY Invoice, StockCode, InvoiceDate, Quantity, CustomerID, Country, Description, Price
    HAVING cnt > 1
) AS duplicates;

ALTER TABLE online_dedup ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST;

DROP TABLE online_retail;
RENAME TABLE online_dedup TO online_retail;

SELECT COUNT(*) FROM online_retail;  -- 518,596 after dedup


-- ------------------------------------------------------------
-- 3. Fix InvoiceDate
--    Two source formats found in the raw export:
--      a) Excel serial numbers, e.g. '40511.40486'
--      b) Proper text dates, e.g. '01-12-2009 07:45'
-- ------------------------------------------------------------
SELECT InvoiceDate FROM online_retail
WHERE InvoiceDate REGEXP '^[0-9]+\\.[0-9]+$';

ALTER TABLE online_retail ADD COLUMN Invoice_date DATETIME;

-- a) Convert Excel serial-number rows (epoch = 1899-12-30)
UPDATE online_retail
SET Invoice_date = DATE_ADD('1899-12-30',
                    INTERVAL FLOOR(CAST(InvoiceDate AS DECIMAL(20,10))) DAY)
WHERE InvoiceDate REGEXP '^[0-9]+\\.[0-9]+$';

-- b) Convert standard day-month-year text rows
UPDATE online_retail
SET Invoice_date = STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')
WHERE InvoiceDate NOT REGEXP '^[0-9]+\\.[0-9]+$';

SELECT Invoice_date FROM online_retail;
SELECT COUNT(*) FROM online_retail WHERE Invoice_date IS NULL;  -- expect 0

-- Swap in the clean column
ALTER TABLE online_retail DROP COLUMN InvoiceDate;
ALTER TABLE online_retail CHANGE COLUMN Invoice_date InvoiceDate DATETIME;

DESCRIBE online_retail;
SELECT COUNT(*) FROM online_retail WHERE InvoiceDate IS NULL;  -- expect 0


-- ------------------------------------------------------------
-- 4. Explore data quality issues before deciding on cleaning rules
-- ------------------------------------------------------------
SELECT COUNT(*) FROM online_retail WHERE Invoice LIKE 'C%';                       -- cancelled invoices
SELECT COUNT(*) FROM online_retail WHERE Quantity < 0;                            -- negative quantity
SELECT COUNT(*) FROM online_retail WHERE CustomerID IS NULL OR CustomerID = '';   -- blank customer id
SELECT COUNT(*) FROM online_retail WHERE Price <= 0;                              -- zero/negative price
SELECT COUNT(*) FROM online_retail WHERE Quantity < 0 AND Invoice NOT LIKE 'C%';  -- negative qty, not a formal cancellation

-- Identify non-product StockCodes (postage, fees, manual entries, test data)
SELECT DISTINCT StockCode FROM online_retail
WHERE StockCode NOT REGEXP '^[0-9]+[A-Za-z]?$';

SELECT StockCode, COUNT(*) AS cnt
FROM online_retail
WHERE StockCode NOT REGEXP '^[0-9]' AND StockCode NOT LIKE 'DCGS%'
GROUP BY StockCode
ORDER BY cnt DESC;


-- ------------------------------------------------------------
-- 5. Build the analysis-ready clean table
--    Cancelled orders and guest checkouts are KEPT and flagged,
--    not deleted, so cancellation rate and total revenue stay
--    accurate. Everything else excluded here is genuinely not
--    a real product sale (see README for full reasoning).
-- ------------------------------------------------------------
CREATE TABLE online_retail_clean AS
SELECT *,
    CASE WHEN Invoice LIKE 'C%' THEN 1 ELSE 0 END AS is_cancelled,
    CASE WHEN CustomerID IS NULL OR CustomerID = '' THEN 1 ELSE 0 END AS is_guest
FROM online_retail
WHERE (StockCode REGEXP '^[0-9]' OR StockCode LIKE 'DCGS%')   -- keep real products only
  AND Price > 0
  AND NOT (Quantity < 0 AND Invoice NOT LIKE 'C%');

SELECT COUNT(*) FROM online_retail_clean;  -- 511,972 rows, final analysis-ready dataset
SELECT SUM(is_cancelled) AS Cancelled_count, SUM(is_guest) AS guest_count FROM online_retail_clean;

-- Follow-up fix: '0' was used in the source data as a placeholder
-- for "no customer" instead of a true blank/NULL, so the guest
-- flag needed a second pass to catch those rows too.
SELECT COUNT(*) FROM online_retail_clean WHERE CustomerID = '0';
UPDATE online_retail_clean SET is_guest = 1 WHERE CustomerID = '0';
