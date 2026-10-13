-- gross per currency and month equals the de-duplicated, in-scope landing orders (D1, D2, D3, D4)
-- Recomputed from raw_* with an independent dedupe (DISTINCT on the full order record), so a
-- fan-out, a double-landed order or a scope leak shows up as a money difference, not just a count.
-- LEFT JOIN to players: an order whose player is missing from the players file is still revenue
-- here, so if the model's player join silently drops it, this test fails.
WITH src AS (
    SELECT DISTINCT o.order_id, o.currency_code, substr(o.order_ts, 1, 7) AS ym,
           CAST(o.gross_amount_local AS REAL) AS g
    FROM raw_orders o
    LEFT JOIN raw_players p ON p.player_id = o.player_id
    WHERE o.order_status IN ('completed', 'refunded')
      AND lower(COALESCE(p.email_domain, '')) NOT LIKE '%twinhearth%'
),
s AS (SELECT currency_code, ym, COUNT(*) AS n, ROUND(SUM(g), 2) AS g FROM src GROUP BY 1, 2),
f AS (SELECT currency_code, substr(order_date, 1, 7) AS ym, COUNT(*) AS n, ROUND(SUM(gross_local), 2) AS g
      FROM fact_order GROUP BY 1, 2)
SELECT s.currency_code, s.ym, s.n AS src_orders, f.n AS fact_orders, s.g AS src_gross, f.g AS fact_gross
FROM s LEFT JOIN f ON f.currency_code = s.currency_code AND f.ym = s.ym
WHERE f.n IS NULL OR f.n <> s.n OR ABS(f.g - s.g) > 0.005
UNION ALL
SELECT f.currency_code, f.ym, NULL, f.n, NULL, f.g
FROM f LEFT JOIN s ON s.currency_code = f.currency_code AND s.ym = f.ym
WHERE s.ym IS NULL;
