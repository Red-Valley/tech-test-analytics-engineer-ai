-- refunds from raw_refunds reduce gross before the platform fee is applied
WITH refunds_by_order AS (
    SELECT order_id,
           SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
)
SELECT f.order_id
FROM fact_order f
JOIN stg_order_priced p ON p.order_id = f.order_id
LEFT JOIN refunds_by_order r ON r.order_id = f.order_id
WHERE p.rate_to_usd IS NOT NULL
  AND p.fee_pct IS NOT NULL
  AND (
      ABS(f.refund_usd - COALESCE(r.refund_local, 0) * p.rate_to_usd) > 0.000001
      OR ABS(f.platform_fee_usd
             - (p.gross_local - COALESCE(r.refund_local, 0))
               * p.rate_to_usd * p.fee_pct) > 0.000001
      OR ABS(f.net_usd
             - (p.gross_local - COALESCE(r.refund_local, 0))
               * p.rate_to_usd * (1 - p.fee_pct)) > 0.000001
  );
