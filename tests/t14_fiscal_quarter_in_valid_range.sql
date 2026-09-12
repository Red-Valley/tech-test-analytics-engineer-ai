-- defends defect #3: SQLite's modulo on a negative dividend produced fiscal_quarter_no/
-- fiscal_month_no outside 1..4 / 1..12 for every fiscal month except Oct-Dec, so a filter for
-- "Q2" (fiscal_quarter_no = 2) silently returned zero rows
SELECT date, fiscal_quarter_no, fiscal_month_no
FROM dim_date
WHERE fiscal_quarter_no NOT BETWEEN 1 AND 4
   OR fiscal_month_no NOT BETWEEN 1 AND 12;
