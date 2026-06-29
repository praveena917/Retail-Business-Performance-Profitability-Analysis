-- ============================================================
-- 03_rfm_segmentation_view.sql
-- Retail Business Performance & Profitability Analysis
-- Purpose: Persistent VIEW exposing per-customer RFM scores
--          and segment labels. Imported directly into Power BI
--          as a dimension table so the dashboard always reflects
--          the current segmentation logic.
-- ============================================================

USE retail_analysis;

CREATE VIEW customer_rfm_segments AS
WITH rfm AS (
    SELECT
        CustomerID,
        DATEDIFF((SELECT MAX(InvoiceDate) FROM online_retail_clean), MAX(InvoiceDate)) AS Recency,
        COUNT(DISTINCT Invoice) AS Frequency,
        SUM(Quantity * Price)   AS Monetary
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
)
SELECT *,
    CASE
        WHEN R_Score = 1 AND F_Score = 1 AND M_Score = 1 THEN 'Champions'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Loyal Customers'
        WHEN R_Score >= 3 AND F_Score >= 3 THEN 'At Risk'
        WHEN R_Score = 4 THEN 'Lost'
        ELSE 'Regular'
    END AS Segment
FROM scored;

SELECT * FROM customer_rfm_segments;
