# Superstore Sales & Profit Analysis (MySQL)

SQL analysis of 9,994 retail transactions covering data cleaning, KPIs, and business insights.

**Tools:** MySQL 8.0, SQL (CTEs, window functions, subqueries, views)

## What's inside
- `PROJECT.sql`: table creation, data quality checks, cleaning, and 34 analysis queries
- `SampleSuperstore.csv`: the dataset (9,994 rows, 13 columns)

## Data cleaning
- Checked every column for NULLs and blank values (none found)
- Checked for invalid values in sales, quantity, and discount (none found)
- Found and removed 17 duplicate rows using ROW_NUMBER(), leaving 9,977 clean rows

## Analysis covered
- Overall KPIs: sales, profit, margin, units sold, average discount
- Sales and profit by region, category, sub-category, segment, and ship mode
- Top and bottom states and cities by sales and profit
- Discount impact on profit
- Window functions: RANK, NTILE, running and percentage-of-total calculations

## Key findings
- $2.30M in sales and $286K in profit (12.47% margin) across 4 regions and 49 states
- Furniture has only a 2.49% margin, compared with about 17% for Technology and Office Supplies
- Tables (-$17.7K) and Bookcases lose money overall
- Discounts above 40% lead to a -77% margin, and 18% of transactions lose money
- 10 states are loss-making, led by Texas, Ohio, and Pennsylvania

## Recommendations
- Cap discounts on low-margin products such as Tables and Bookcases
- Review pricing and discount policy in Texas, Ohio, and Pennsylvania

## How to run
1. Open `PROJECT.sql` in MySQL Workbench
2. Import `SampleSuperstore.csv` into the `superstore_raw` table using the Table Data Import Wizard
3. Run the script section by section

## Author
Jaswanth Bulagondla | Data Analyst
