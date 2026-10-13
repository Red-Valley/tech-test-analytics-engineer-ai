-- every refund on an in-scope order reaches the fact, and no order refunds more than it grossed (D8)
-- The refunds table is the system of record: partial refunds on 'completed' orders count too.
WITH r AS (SELECT order_id, SUM(CAST(refund_amount_local AS REAL)) AS refund_local
           FROM (SELECT DISTINCT * FROM raw_refunds) GROUP BY order_id)
SELECT f.order_id, f.order_status, f.gross_local, f.refund_local AS fact_refund, r.refund_local AS src_refund
FROM fact_order f
LEFT JOIN r ON r.order_id = f.order_id
WHERE ABS(f.refund_local - COALESCE(r.refund_local, 0)) > 0.005
   OR f.refund_local > f.gross_local + 0.005
   OR (f.order_status = 'refunded' AND ABS(f.refund_local - f.gross_local) > 0.005);
