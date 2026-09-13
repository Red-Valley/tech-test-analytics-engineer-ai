-- refunds are aggregated once per order and cannot exceed gross
WITH refund_totals AS (
    SELECT order_id, SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
)
SELECT f.order_id, f.gross_usd, f.refund_usd
FROM fact_order f
WHERE f.refund_usd < -0.000001
   OR f.refund_usd > f.gross_usd + 0.000001
   OR ABS(f.refund_usd - COALESCE((
       SELECT r.refund_local * p.rate_to_usd
       FROM refund_totals r
       JOIN stg_order_priced p ON p.order_id = r.order_id
       WHERE r.order_id = f.order_id
   ), 0)) > 0.000001;
