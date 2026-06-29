-- ============================================================
-- 02_business_analysis_queries.sql
-- Retail Business Performance & Profitability Analysis
-- Purpose: Core business-question queries run against
--          online_retail_clean
-- ============================================================

USE retail_analysis;

-- ------------------------------------------------------------
-- Q1. Monthly Revenue Trend
-- Reveals seasonality - revenue peaks Nov 2010 ahead of the
-- holiday season, dips in Dec 2010 because that month is only
-- partially represented in the source data.
-- ------------------------------------------------------------
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS Month,
    ROUND(SUM(Quantity * Price), 2)   AS Revenue
FROM online_retail_clean
WHERE is_cancelled = 0
GROUP BY Month
ORDER BY Month;


-- ------------------------------------------------------------
-- Q2. Top 10 Customers by Revenue
-- ------------------------------------------------------------
SELECT
    CustomerID,
    ROUND(SUM(Quantity * Price), 2) AS Total_Revenue,
    COUNT(DISTINCT Invoice)         AS Total_Orders
FROM online_retail_clean
WHERE is_cancelled = 0 AND is_guest = 0
GROUP BY CustomerID
ORDER BY Total_Revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q3. Pareto Analysis - revenue share of top 20% of customers
-- Uses the PERCENT_RANK() window function to rank customers by
-- revenue, then sums revenue contributed by the top quintile.
-- Result: top 20% of customers drive 73.38% of total revenue.
-- ------------------------------------------------------------
WITH customer_revenue AS (
    SELECT CustomerID, SUM(Quantity * Price) AS revenue
    FROM online_retail_clean
    WHERE is_cancelled = 0 AND is_guest = 0
    GROUP BY CustomerID
),
ranked AS (
    SELECT *, PERCENT_RANK() OVER (ORDER BY revenue DESC) AS pct_rank
    FROM customer_revenue
)
SELECT
    SUM(CASE WHEN pct_rank <= 0.2 THEN revenue ELSE 0 END) AS top_20pct_revenue,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(CASE WHEN pct_rank <= 0.2 THEN revenue ELSE 0 END) / SUM(revenue) * 100, 2) AS top_20_pct_share
FROM ranked;


-- ------------------------------------------------------------
-- Q4. Raw RFM values for top customers by spend (exploratory
-- step before building the full segmentation in Q5)
-- ------------------------------------------------------------
SELECT
    CustomerID,
    DATEDIFF((SELECT MAX(InvoiceDate) FROM online_retail_clean), MAX(InvoiceDate)) AS Recency_Days,
    COUNT(DISTINCT Invoice) AS Frequency,
    ROUND(SUM(Quantity * Price), 2) AS Monetary
FROM online_retail_clean
WHERE is_cancelled = 0 AND is_guest = 0
GROUP BY CustomerID
ORDER BY Monetary DESC
LIMIT 15;


-- ------------------------------------------------------------
-- Q5. RFM Segmentation
-- Recency, Frequency, Monetary scoring using NTILE(4) quartiles,
-- then mapped to human-readable segments. Also saved as a VIEW
-- (see 03_rfm_segmentation_view.sql) so Power BI stays in sync.
-- ------------------------------------------------------------
WITH rfm AS (
    SELECT
        CustomerID,
        DATEDIFF((SELECT MAX(InvoiceDate) FROM online_retail_clean), MAX(InvoiceDate)) AS Recency,
        COUNT(DISTINCT Invoice) AS Frequency,
        ROUND(SUM(Quantity * Price), 2) AS Monetary
    FROM online_retail_clean
    WHERE is_cancelled = 0 AND is_guest = 0
    GROUP BY CustomerID
),
scored AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY Recency ASC)    AS R_Score,
        NTILE(4) OVER (ORDER BY Frequency DESC) AS F_Score,
        NTILE(4) OVER (ORDER BY Monetary DESC)  AS M_Score
    FROM rfm
),
segmented AS (
    SELECT *,
        CASE
            WHEN R_Score = 1 AND F_Score = 1 AND M_Score = 1 THEN 'Champions'
            WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Loyal Customers'
            WHEN R_Score >= 3 AND F_Score >= 3 THEN 'At Risk'
            WHEN R_Score = 4 THEN 'Lost'
            ELSE 'Regular'
        END AS Segment
    FROM scored
)
SELECT Segment, COUNT(*) AS Customer_Count, ROUND(SUM(Monetary), 2) AS Total_Revenue
FROM segmented
GROUP BY Segment
ORDER BY Total_Revenue DESC;


-- ------------------------------------------------------------
-- Q6. Top 10 Cancelled/Returned Products by Lost Revenue
-- Runs against the raw `online_retail` table (not the clean
-- table) so cancelled-invoice line items are visible; the same
-- non-product StockCode filter is reapplied here.
-- ------------------------------------------------------------
SELECT
    Description,
    COUNT(*) AS Cancelled_Count,
    ROUND(SUM(ABS(Quantity) * Price), 2) AS Lost_Revenue
FROM online_retail
WHERE Invoice LIKE 'C%'
  AND (StockCode REGEXP '^[0-9]' OR StockCode LIKE 'DCGS%')
GROUP BY Description
ORDER BY Lost_Revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q7. Revenue by Country
-- ------------------------------------------------------------
SELECT
    Country,
    ROUND(SUM(Quantity * Price), 2) AS Revenue,
    COUNT(DISTINCT Invoice) AS Orders
FROM online_retail_clean
WHERE is_cancelled = 0
GROUP BY Country
ORDER BY Revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q8. Top 10 Best-Selling Products by Revenue
-- ------------------------------------------------------------
SELECT
    StockCode, Description,
    SUM(Quantity) AS Total_Units_Sold,
    ROUND(SUM(Quantity * Price), 2) AS Total_Revenue
FROM online_retail_clean
WHERE is_cancelled = 0
GROUP BY StockCode, Description
ORDER BY Total_Revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q9. Repeat Purchase Rate
-- ------------------------------------------------------------
WITH customer_orders AS (
    SELECT CustomerID, COUNT(DISTINCT Invoice) AS Order_Count
    FROM online_retail_clean
    WHERE is_cancelled = 0 AND is_guest = 0
    GROUP BY CustomerID
)
SELECT
    COUNT(*) AS Total_Customers,
    SUM(CASE WHEN Order_Count > 1 THEN 1 ELSE 0 END) AS Repeat_Customers,
    ROUND(SUM(CASE WHEN Order_Count > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Repeat_Rate_Pct
FROM customer_orders;


-- ------------------------------------------------------------
-- Q10. Revenue by Region (demonstrates JOIN against a lookup table)
-- ------------------------------------------------------------
CREATE TABLE country_region (
    Country VARCHAR(50),
    Region  VARCHAR(50)
);

INSERT INTO country_region (Country, Region) VALUES
('United Kingdom', 'UK & Ireland'),
('EIRE', 'UK & Ireland'),
('Germany', 'Western Europe'),
('France', 'Western Europe'),
('Netherlands', 'Western Europe'),
('Switzerland', 'Western Europe'),
('Spain', 'Southern Europe'),
('Italy', 'Southern Europe'),
('Portugal', 'Southern Europe'),
('Denmark', 'Northern Europe'),
('Sweden', 'Northern Europe'),
('Norway', 'Northern Europe'),
('Finland', 'Northern Europe'),
('Australia', 'Oceania'),
('Japan', 'Asia Pacific'),
('Singapore', 'Asia Pacific');

SELECT
    COALESCE(cr.Region, 'Other') AS Region,
    ROUND(SUM(o.Quantity * o.Price), 2) AS Revenue
FROM online_retail_clean o
LEFT JOIN country_region cr ON o.Country = cr.Country
WHERE o.is_cancelled = 0
GROUP BY Region
ORDER BY Revenue DESC;


-- ------------------------------------------------------------
-- Q11. Overall Cancellation Rate
-- ------------------------------------------------------------
SELECT
    COUNT(DISTINCT CASE WHEN is_cancelled = 1 THEN Invoice END) AS Cancelled_Orders,
    COUNT(DISTINCT Invoice) AS Total_Orders,
    ROUND(COUNT(DISTINCT CASE WHEN is_cancelled = 1 THEN Invoice END)
        / COUNT(DISTINCT Invoice) * 100, 2) AS Cancellation_Rate_Pct
FROM online_retail_clean;
