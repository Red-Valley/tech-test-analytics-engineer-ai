-- only completed orders are revenue: no pending or unknown status in the fact (D3)
-- 'refunded' is a completed order that was later refunded in full; anything else never completed.
SELECT order_id, order_status FROM fact_order
WHERE order_status NOT IN ('completed', 'refunded') GROUP BY order_id;
