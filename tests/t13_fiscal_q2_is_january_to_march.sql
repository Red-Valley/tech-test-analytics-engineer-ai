-- FY2026 Q2 must contain 2026-01-01 through 2026-03-31
SELECT date, fiscal_year, fiscal_quarter_no
FROM dim_date
WHERE date IN ('2026-01-01', '2026-03-31')
  AND (fiscal_year <> 'FY2026' OR fiscal_quarter_no <> 2);
