-- FY2026 covers the policy dates, quarters, and fiscal months
SELECT date, fiscal_year, fiscal_quarter_no, fiscal_month_no
FROM dim_date
WHERE date BETWEEN '2025-10-01' AND '2026-09-30'
  AND (
      fiscal_year != 'FY2026'
      OR fiscal_quarter_no != (((calendar_month + 2) % 12) + 3) / 3
      OR fiscal_month_no != ((calendar_month + 2) % 12) + 1
  )
UNION ALL
SELECT 'FY2026 coverage', fiscal_year, NULL, NULL
FROM dim_date
WHERE date = '2025-10-01'
  AND (SELECT COUNT(*) FROM dim_date
       WHERE date BETWEEN '2025-10-01' AND '2026-09-30') != 365;
