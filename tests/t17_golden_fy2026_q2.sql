-- Golden FY2026 Q2 net revenue by title and in total, compared in integer cents
WITH expected(title_id, expected_cents) AS (
    VALUES
        ('T-01', 14390320),
        ('T-02', 4674325),
        ('T-03', 2704107),
        ('T-04', 4430621),
        ('T-05', 5655700),
        ('__TOTAL__', 31855072)
),
actual(title_id, actual_cents) AS (
    SELECT title_id,
           CAST(ROUND(SUM(net_usd) * 100.0) AS INTEGER)
    FROM fact_order
    WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
    GROUP BY title_id
    UNION ALL
    SELECT '__TOTAL__',
           CAST(ROUND(COALESCE(SUM(net_usd), 0) * 100.0) AS INTEGER)
    FROM fact_order
    WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
)
SELECT e.title_id, e.expected_cents, a.actual_cents
FROM expected e
LEFT JOIN actual a ON a.title_id = e.title_id
WHERE a.title_id IS NULL
   OR a.actual_cents <> e.expected_cents
UNION ALL
SELECT a.title_id, NULL, a.actual_cents
FROM actual a
LEFT JOIN expected e ON e.title_id = a.title_id
WHERE e.title_id IS NULL
ORDER BY 1;
