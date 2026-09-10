-- every order that has a row in raw_refunds must show a positive refund_usd on the fact (partial refunds on still-'completed' orders were previously dropped entirely)
SELECT f.order_id FROM fact_order f
WHERE f.order_id IN (SELECT DISTINCT order_id FROM raw_refunds)
AND (f.refund_usd IS NULL OR f.refund_usd <= 0);
