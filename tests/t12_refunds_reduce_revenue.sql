-- defends defect #7: refunds.csv is the system of record (full AND partial refunds) and must
-- always reduce net_usd -- not just when order_status happens to be 'refunded'
SELECT f.order_id, f.refund_usd
FROM fact_order f
JOIN (SELECT DISTINCT order_id FROM raw_refunds) r ON r.order_id = f.order_id
WHERE f.refund_usd IS NULL OR f.refund_usd <= 0;
