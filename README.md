# 📈 Retail Business Performance & Profitability Analysis

End-to-end SQL + Power BI analysis of ~512K retail transactions from a UK-based online gift wholesaler, covering December 2009 – December 2010.

**Tools:** MySQL (data cleaning, transformation, analysis) · Power BI (data modeling, dashboarding)

---

## 📌 Project Overview

This project analyzes real-world e-commerce transaction data to answer core retail performance questions: revenue trends, customer value, product performance, and operational losses from cancellations. The raw dataset was messy and required substantial cleaning before analysis — every cleaning decision below is intentional and documented, not just deleted-and-moved-on.

**Dataset:** [Online Retail II (UCI Machine Learning Repository)](https://archive.ics.uci.edu/dataset/502/online+retail+ii)

**Final clean dataset:** 511,972 transaction line items, 4,285 unique customers

---

## 🎯 Business Questions

1. What is the monthly revenue trend, and when does seasonal demand peak?
2. Who are the top customers, and what share of revenue do they drive (Pareto analysis)?
3. How can customers be segmented by value and engagement (RFM)?
4. What is the customer repeat-purchase rate?
5. Which products generate the most revenue?
6. Which products are most frequently cancelled/returned, and what is the revenue impact?
7. What is the overall order cancellation rate?
8. How does revenue vary by country/region?

---

## 🧹 Data Cleaning Decisions

Raw data is never analysis-ready. Here's what was found and how it was handled — these decisions are exactly what a hiring manager would expect a Data Analyst to be able to explain.

| Issue Found | Rows Affected | Decision & Reasoning |
|---|---:|---|
| Duplicate rows (from import process) | 6,865 | Removed, keeping first occurrence — confirmed via exact-match grouping across all fields |
| Dates stored as Excel serial numbers in raw export | ~90% of rows | Converted using Excel epoch formula (`1899-12-30` + day offset) directly in SQL |
| Cancelled invoices (`Invoice` starts with "C") | 9,558 | **Kept, flagged** (`is_cancelled`) rather than deleted — needed to calculate cancellation rate and lost-revenue impact |
| Non-cancelled rows with negative quantity (manual stock adjustments) | 581 | Excluded from revenue — not genuine sales |
| Blank/zero `CustomerID` (guest checkouts) | ~103,000 | **Kept, flagged** (`is_guest`) — included in total revenue, excluded from customer-level analysis (RFM, repeat-rate) since they can't be attributed to a person |
| Non-product `StockCode` values (postage, bank fees, manual entries, test data — e.g. `POST`, `D`, `M`, `BANK CHARGES`, `TEST001`) | 525 | Excluded entirely — these are administrative line items, not product sales |
| Zero-price rows (free samples/promo items) | 929 | Excluded from revenue calculations |

**Why flag instead of delete?**

Cancelled orders and guest checkouts are still *real, meaningful events* — deleting them would understate order volume and make cancellation-rate analysis impossible. Flagging preserves the full picture while letting each query decide what to include.

---

## 🔑 Key Findings

### Revenue & Seasonality

- Total revenue: **£9.56M** across **25,012 orders**
- Average Order Value: **£387.28**
- Revenue peaked in **November 2010 at £1.43M**, approximately **64% higher** than the August baseline.
- December 2010 revenue appears lower because the source data only includes transactions through **9 December 2010**.

### Customer Value (Pareto Analysis)

- The **top 20% of customers generate 73.38%** of total revenue.
- RFM segmentation divided customers into five actionable groups:

| Segment | Customers | Revenue | Insight |
|---|---:|---:|---|
| Champions | 472 (11%) | £4.42M (57%) | Highest-value customers |
| Loyal Customers | 983 (23%) | £1.92M | Frequent repeat buyers |
| Regular | 1,163 (27%) | £1.29M | Stable middle-value customers |
| At Risk | 1,454 (34%) | £0.65M | Largest segment by count; ideal win-back target |
| Lost | 213 (5%) | £0.36M | Inactive customers |

- **66.54% repeat purchase rate**, indicating strong customer loyalty.

### Products & Operations

- **Regency Cakestand 3 Tier** generated the highest revenue (**£169.9K**).
- The same product also produced the highest cancelled revenue (**£7K**), suggesting potential quality or customer expectation issues.
- **White Hanging Heart T-Light Holder** was the highest-volume product (**58,691 units sold**).
- Overall cancellation rate: **16.63%** of all orders.
- Total cancelled revenue: **£247.4K**.

### Geography

- The **United Kingdom contributed approximately 94%** of total revenue.
- **Netherlands** and **Denmark** recorded the highest average order values, suggesting large wholesale purchases despite relatively few orders.

---

## 🛠️ Technical Approach

### SQL (MySQL)

- Data cleaning and preprocessing
- Type conversion
- Duplicate removal
- Revenue calculations
- Aggregation and grouping
- Window Functions (`PERCENT_RANK()`, `NTILE()`)
- Common Table Expressions (CTEs)
- JOIN operations
- SQL Views
- Country-to-region mapping

### Power BI

- Direct MySQL connection
- Star schema data model
- DAX measures
- Interactive dashboard
- Date, Country, and Segment slicers

---

## 📊 Dashboard Pages

### 1️⃣ Executive Overview

- Revenue KPIs
- Monthly Revenue Trend
- Revenue by Country


<img width="1297" height="713" alt="executive_overview" src="https://github.com/user-attachments/assets/034a2e1b-ab17-46b9-8819-b15f25cef755" />

### 2️⃣ Customer Analysis

- RFM Segmentation
- Pareto Analysis
- Repeat Purchase Rate
- Top Customers


 <img width="1285" height="710" alt="customer_analysis" src="https://github.com/user-attachments/assets/e52f78c3-d1d5-4507-be83-8c2cfa05b85a" />
 
### 3️⃣ Products & Returns

- Product Revenue
- Top Products
- Cancellation Rate
- Lost Revenue Analysis


<img width="1279" height="713" alt="products_return_analysis" src="https://github.com/user-attachments/assets/7927575d-c449-4e2f-a994-b38bdd3efe7e" />

---

## 📂 Repository Structure

```text
Retail_Business_Performance_Analysis/
│
├── README.md
├── sql/
│   ├── 01_table_setup_and_cleaning.sql
│   ├── 02_business_analysis_queries.sql
│   └── 03_rfm_segmentation_view.sql
│
├── powerbi/
│   └── retail_analysis.pbix
│
└── screenshots/
    ├── 1_executive_overview.png
    ├── 2_customer_analysis.png
    └── 3_products_return_analysis.png
```

---

## 🚀 Future Improvements

- Expand the dataset for year-over-year comparisons.
- Build customer cohort retention analysis.
- Investigate causes of high product cancellation rates.
- Develop sales forecasting models.
- Automate Power BI refresh using cloud databases.

---

## 💡 Skills Demonstrated

- SQL
- MySQL
- Data Cleaning
- Data Transformation
- Window Functions
- CTEs
- RFM Analysis
- Pareto Analysis
- Customer Analytics
- Retail Analytics
- Power BI
- DAX
- Data Visualization
- Dashboard Development
- Business Intelligence
- KPI Reporting
