-- refund_usd must use the aggregated refunds table, including partial refunds
WITH refunds AS (
    SELECT order_id, SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
)
SELECT f.order_id,
       f.refund_usd,
       COALESCE(r.refund_local, 0.0)
           * COALESCE(
               (SELECT CAST(fx.rate_to_usd AS REAL)
                FROM raw_fx_rates fx
                WHERE fx.currency_code = o.currency_code
                  AND fx.rate_date <= substr(o.order_ts, 1, 10)
                ORDER BY fx.rate_date DESC
                LIMIT 1),
               CASE WHEN o.currency_code = 'USD' THEN 1.0 END
             ) AS expected_refund_usd
FROM fact_order f
JOIN raw_orders o ON o.order_id = f.order_id
LEFT JOIN refunds r ON r.order_id = f.order_id
WHERE ABS(f.refund_usd - COALESCE(r.refund_local, 0.0)
    * COALESCE(
        (SELECT CAST(fx.rate_to_usd AS REAL)
         FROM raw_fx_rates fx
         WHERE fx.currency_code = o.currency_code
           AND fx.rate_date <= substr(o.order_ts, 1, 10)
         ORDER BY fx.rate_date DESC
         LIMIT 1),
        CASE WHEN o.currency_code = 'USD' THEN 1.0 END
      )) > 0.000001;
