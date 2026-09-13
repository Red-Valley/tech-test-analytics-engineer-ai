-- FY2026 Q2 is exactly 2026-01-01 through 2026-03-31 (FY starts October)
SELECT date, fiscal_year, fiscal_quarter_no
FROM dim_date
WHERE date BETWEEN '2026-01-01' AND '2026-03-31'
  AND (fiscal_year <> 'FY2026' OR fiscal_quarter_no <> 2)
UNION ALL
SELECT date, fiscal_year, fiscal_quarter_no
FROM dim_date
WHERE date IN ('2025-12-31', '2026-04-01')
  AND ((date = '2025-12-31' AND (fiscal_year <> 'FY2026' OR fiscal_quarter_no <> 1))
    OR (date = '2026-04-01' AND (fiscal_year <> 'FY2026' OR fiscal_quarter_no <> 3)));
