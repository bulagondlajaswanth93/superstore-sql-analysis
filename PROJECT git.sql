/* =====================================================================
   PROJECT : Superstore Sales & Profit Analysis (SQL)
   Author  : Jaswanth Bulagondla
   Tool    : MySQL 8.0 (Workbench)
   Dataset : SampleSuperstore.csv  (9,994 rows, 13 columns, US retail)
   Skills  : DDL/DML, Data Cleaning, Aggregations, CASE, Subqueries,
             CTEs, Window Functions (RANK, NTILE, SUM OVER), Views
   ===================================================================== */

CREATE DATABASE PROJECT;
USE PROJECT;

/* =====================================================================
   SECTION 1 : CREATE RAW TABLE & LOAD DATA
   ===================================================================== */

DROP TABLE IF EXISTS superstore_raw;

CREATE TABLE superstore_raw (
    ship_mode     VARCHAR(20),
    segment       VARCHAR(20),
    country       VARCHAR(30),
    city          VARCHAR(50),
    state         VARCHAR(30),
    postal_code   VARCHAR(10),
    region        VARCHAR(10),
    category      VARCHAR(20),
    sub_category  VARCHAR(20),
    sales         DECIMAL(10,2),
    quantity      INT,
    discount      DECIMAL(3,2),
    profit        DECIMAL(12,4)
);

-- Load the CSV (change the path to where you saved the file).
-- Easier alternative: right-click the table in Workbench -> "Table Data Import Wizard".
-- LOAD DATA LOCAL INFILE 'C:/path/SampleSuperstore.csv'
-- INTO TABLE superstore_raw
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

SELECT COUNT(*) AS total_rows FROM superstore_raw;          -- expect 9994
SELECT * FROM superstore_raw LIMIT 10;


/* =====================================================================
   SECTION 2 : DATA QUALITY CHECKS
   ===================================================================== */

-- 2.1 NULL / blank check on every column
SELECT
    SUM(ship_mode    IS NULL OR ship_mode    = '') AS null_ship_mode,
    SUM(segment      IS NULL OR segment      = '') AS null_segment,
    SUM(city         IS NULL OR city         = '') AS null_city,
    SUM(state        IS NULL OR state        = '') AS null_state,
    SUM(region       IS NULL OR region       = '') AS null_region,
    SUM(category     IS NULL OR category     = '') AS null_category,
    SUM(sub_category IS NULL OR sub_category = '') AS null_sub_category,
    SUM(sales        IS NULL)                      AS null_sales,
    SUM(quantity     IS NULL)                      AS null_quantity,
    SUM(discount     IS NULL)                      AS null_discount,
    SUM(profit       IS NULL)                      AS null_profit
FROM superstore_raw;

-- 2.2 Exact duplicate rows
SELECT COUNT(*) AS duplicate_rows_to_remove
FROM (
    SELECT ROW_NUMBER() OVER (
               PARTITION BY ship_mode, segment, country, city, state, postal_code,
                            region, category, sub_category, sales, quantity, discount, profit
           ) AS rn
    FROM superstore_raw
) d
WHERE rn > 1;                                                -- expect 17

-- 2.3 Invalid values (should all be 0)
SELECT
    SUM(sales    <= 0)                 AS non_positive_sales,
    SUM(quantity <= 0)                 AS non_positive_quantity,
    SUM(discount < 0 OR discount > 1)  AS invalid_discount
FROM superstore_raw;

-- 2.4 Distinct values of the categorical columns (spelling / consistency check)
SELECT DISTINCT ship_mode FROM superstore_raw;
SELECT DISTINCT segment   FROM superstore_raw;
SELECT DISTINCT region    FROM superstore_raw;
SELECT DISTINCT category, sub_category FROM superstore_raw ORDER BY category, sub_category;


/* =====================================================================
   SECTION 3 : DATA CLEANING  (build the clean analysis table)
   - removes exact duplicate rows
   - trims text columns
   - adds profit_margin_pct and discount_band helper columns
   ===================================================================== */

DROP TABLE IF EXISTS superstore;

CREATE TABLE superstore AS
SELECT
    ROW_NUMBER() OVER (ORDER BY state, city, sub_category, sales) AS row_id,
    ship_mode, segment, country, city, state, postal_code,
    region, category, sub_category,
    sales, quantity, discount, profit,
    ROUND(profit / sales * 100, 2) AS profit_margin_pct,
    CASE
        WHEN discount = 0               THEN '0% (No discount)'
        WHEN discount <= 0.20           THEN '1-20%'
        WHEN discount <= 0.40           THEN '21-40%'
        ELSE                                 '40%+'
    END AS discount_band
FROM (
    SELECT TRIM(ship_mode) ship_mode, TRIM(segment) segment, TRIM(country) country,
           TRIM(city) city, TRIM(state) state, TRIM(postal_code) postal_code,
           TRIM(region) region, TRIM(category) category, TRIM(sub_category) sub_category,
           sales, quantity, discount, profit,
           ROW_NUMBER() OVER (
               PARTITION BY ship_mode, segment, country, city, state, postal_code,
                            region, category, sub_category, sales, quantity, discount, profit
           ) AS rn
    FROM superstore_raw
) t
WHERE rn = 1;

SELECT COUNT(*) AS clean_rows FROM superstore;               -- expect 9977


/* =====================================================================
   SECTION 4 : OVERALL KPIs
   ===================================================================== */

-- 4.1 Headline KPIs
SELECT
    COUNT(*)                                   AS total_transactions,
    ROUND(SUM(sales), 2)                       AS total_sales,
    ROUND(SUM(profit), 2)                      AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)   AS profit_margin_pct,
    SUM(quantity)                              AS total_units_sold,
    ROUND(AVG(sales), 2)                       AS avg_sales_per_transaction,
    ROUND(AVG(discount) * 100, 2)              AS avg_discount_pct
FROM superstore;

-- 4.2 Reusable KPI view
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS profit_margin_pct
FROM superstore;


/* =====================================================================
   SECTION 5 : SALES & PROFIT BY BUSINESS DIMENSION
   ===================================================================== */

-- 5.1 By Region
SELECT region,
       ROUND(SUM(sales),2)                      AS total_sales,
       ROUND(SUM(profit),2)                     AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2)      AS margin_pct,
       ROUND(SUM(sales)*100/SUM(SUM(sales)) OVER (),2) AS pct_of_total_sales
FROM superstore
GROUP BY region
ORDER BY total_sales DESC;

-- 5.2 By Category
SELECT category,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margin_pct
FROM superstore
GROUP BY category
ORDER BY total_profit DESC;

-- 5.3 By Customer Segment
SELECT segment,
       COUNT(*)             AS transactions,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margin_pct,
       ROUND(AVG(sales),2)  AS avg_order_value
FROM superstore
GROUP BY segment
ORDER BY total_sales DESC;

-- 5.4 By Ship Mode
SELECT ship_mode,
       COUNT(*)             AS transactions,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margin_pct
FROM superstore
GROUP BY ship_mode
ORDER BY total_sales DESC;

-- 5.5 Region x Category matrix (conditional aggregation)
SELECT region,
       ROUND(SUM(CASE WHEN category='Furniture'       THEN profit END),2) AS furniture_profit,
       ROUND(SUM(CASE WHEN category='Office Supplies' THEN profit END),2) AS office_supplies_profit,
       ROUND(SUM(CASE WHEN category='Technology'      THEN profit END),2) AS technology_profit
FROM superstore
GROUP BY region
ORDER BY region;


/* =====================================================================
   SECTION 6 : PRODUCT ANALYSIS
   ===================================================================== */

-- 6.1 Sub-category performance, ranked by profit
SELECT category, sub_category,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margin_pct,
       RANK() OVER (ORDER BY SUM(profit) DESC) AS profit_rank
FROM superstore
GROUP BY category, sub_category
ORDER BY profit_rank;

-- 6.2 Loss-making sub-categories (subquery on aggregate)
SELECT sub_category, total_sales, total_profit
FROM (
    SELECT sub_category,
           ROUND(SUM(sales),2)  AS total_sales,
           ROUND(SUM(profit),2) AS total_profit
    FROM superstore
    GROUP BY sub_category
) s
WHERE total_profit < 0
ORDER BY total_profit;

-- 6.3 Top 3 sub-categories by profit inside each category (RANK + PARTITION BY)
WITH sub_perf AS (
    SELECT category, sub_category, ROUND(SUM(profit),2) AS total_profit
    FROM superstore
    GROUP BY category, sub_category
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY category ORDER BY total_profit DESC) AS rnk
    FROM sub_perf
)
SELECT category, sub_category, total_profit, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY category, rnk;

-- 6.4 Pareto: sub-categories making up the cumulative share of sales
WITH sub_sales AS (
    SELECT sub_category, SUM(sales) AS s
    FROM superstore
    GROUP BY sub_category
)
SELECT sub_category,
       ROUND(s,2) AS total_sales,
       ROUND(s * 100 / SUM(s) OVER (), 2) AS pct_of_sales,
       ROUND(SUM(s) OVER (ORDER BY s DESC) * 100 / SUM(s) OVER (), 2) AS cumulative_pct
FROM sub_sales
ORDER BY s DESC;


/* =====================================================================
   SECTION 7 : GEOGRAPHIC ANALYSIS
   ===================================================================== */

-- 7.1 Top 10 states by sales
SELECT state,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margin_pct
FROM superstore
GROUP BY state
ORDER BY total_sales DESC
LIMIT 10;

-- 7.2 Bottom 10 states by profit (loss-making states)
SELECT state,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit
FROM superstore
GROUP BY state
ORDER BY total_profit ASC
LIMIT 10;

-- 7.3 Top 10 cities by profit
SELECT city, state,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit
FROM superstore
GROUP BY city, state
ORDER BY total_profit DESC
LIMIT 10;

-- 7.4 States that beat their own region's average margin (CTE + JOIN)
WITH state_m AS (
    SELECT region, state, SUM(profit)/SUM(sales)*100 AS state_margin
    FROM superstore GROUP BY region, state
),
region_m AS (
    SELECT region, SUM(profit)/SUM(sales)*100 AS region_margin
    FROM superstore GROUP BY region
)
SELECT s.region, s.state,
       ROUND(s.state_margin,2)  AS state_margin_pct,
       ROUND(r.region_margin,2) AS region_margin_pct
FROM state_m s
JOIN region_m r ON r.region = s.region
WHERE s.state_margin > r.region_margin
ORDER BY s.region, s.state_margin DESC;

-- 7.5 Best state in every region (window function)
SELECT region, state, total_profit
FROM (
    SELECT region, state, ROUND(SUM(profit),2) AS total_profit,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY SUM(profit) DESC) AS rn
    FROM superstore
    GROUP BY region, state
) x
WHERE rn = 1
ORDER BY total_profit DESC;

-- 7.6 City quartiles by sales (NTILE)
WITH city_sales AS (
    SELECT city, state, SUM(sales) AS s FROM superstore GROUP BY city, state
),
city_q AS (
    SELECT s, NTILE(4) OVER (ORDER BY s DESC) AS sales_quartile FROM city_sales
)
SELECT sales_quartile,
       COUNT(*)        AS cities,
       ROUND(SUM(s),2) AS total_sales
FROM city_q
GROUP BY sales_quartile
ORDER BY sales_quartile;


/* =====================================================================
   SECTION 8 : DISCOUNT IMPACT ON PROFIT
   ===================================================================== */

-- 8.1 Profit by discount band
SELECT discount_band,
       COUNT(*)             AS transactions,
       ROUND(SUM(sales),2)  AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margin_pct
FROM superstore
GROUP BY discount_band
ORDER BY MIN(discount);

-- 8.2 Share of transactions that lose money
SELECT ROUND(SUM(profit < 0) * 100 / COUNT(*), 2) AS pct_loss_transactions,
       ROUND(SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END), 2) AS total_loss_amount
FROM superstore;

-- 8.3 Which sub-categories get the heaviest discounts, and what it costs
SELECT sub_category,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct,
       ROUND(SUM(profit),2)       AS total_profit
FROM superstore
GROUP BY sub_category
ORDER BY avg_discount_pct DESC;

-- 8.4 Loss-making transactions with discount above 30% by category
SELECT category,
       COUNT(*)             AS loss_txns,
       ROUND(SUM(profit),2) AS loss_amount
FROM superstore
WHERE profit < 0 AND discount > 0.30
GROUP BY category
ORDER BY loss_amount;


/* =====================================================================
   SECTION 9 : ADVANCED ANALYSIS
   ===================================================================== */

-- 9.1 Top 10 most profitable transactions & bottom 10 (UNION ALL)
(SELECT 'Top 10' AS bucket, row_id, state, sub_category, sales, discount, profit
 FROM superstore ORDER BY profit DESC LIMIT 10)
UNION ALL
(SELECT 'Bottom 10', row_id, state, sub_category, sales, discount, profit
 FROM superstore ORDER BY profit ASC LIMIT 10);

-- 9.2 Transactions with above-average sales for their own sub-category (correlated subquery)
SELECT COUNT(*) AS above_avg_transactions
FROM superstore s
WHERE s.sales > (SELECT AVG(sales) FROM superstore WHERE sub_category = s.sub_category);

-- 9.3 Segment contribution to each region's sales (window % within partition)
SELECT region, segment,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(sales) * 100 / SUM(SUM(sales)) OVER (PARTITION BY region),2) AS pct_of_region
FROM superstore
GROUP BY region, segment
ORDER BY region, pct_of_region DESC;

-- 9.4 Profit-making vs loss-making states summary
WITH state_p AS (
    SELECT state, SUM(profit) AS p FROM superstore GROUP BY state
)
SELECT CASE WHEN p >= 0 THEN 'Profitable' ELSE 'Loss-making' END AS state_type,
       COUNT(*)            AS states,
       ROUND(SUM(p),2)     AS total_profit
FROM state_p
GROUP BY state_type;
