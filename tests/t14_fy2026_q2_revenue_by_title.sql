-- FY2026 Q2 revenue must reconcile to the verified title totals
WITH actual AS (
    SELECT f.title_id,
           ROUND(SUM(f.net_usd), 2) AS net_usd
    FROM fact_order f
    JOIN dim_date d ON d.date = f.order_date
    WHERE d.fiscal_year = 'FY2026'
      AND d.fiscal_quarter_no = 2
    GROUP BY f.title_id
),
expected(title_id, net_usd) AS (
    VALUES
        ('T-01', 148523.10),
        ('T-02', 48305.08),
        ('T-03', 27928.18),
        ('T-04', 45772.57),
        ('T-05', 58169.01)
)
SELECT expected.title_id, expected.net_usd, actual.net_usd
FROM expected
LEFT JOIN actual ON actual.title_id = expected.title_id
WHERE actual.net_usd IS NULL
   OR ABS(actual.net_usd - expected.net_usd) > 0.01
UNION ALL
SELECT 'TOTAL', 328697.94, ROUND(SUM(net_usd), 2)
FROM actual
HAVING ABS(ROUND(SUM(net_usd), 2) - 328697.94) > 0.01;
