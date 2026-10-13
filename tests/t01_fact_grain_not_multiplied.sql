-- fact_order has exactly one row per order_id (D1 fan-out, D2 duplicate re-land)
-- The original version compared against raw_orders, which itself holds the March re-land twice,
-- so a doubled order passed. Uniqueness is the grain; the landing table is not the reference.
SELECT order_id, COUNT(*) AS rows_in_fact
FROM fact_order
GROUP BY order_id
HAVING COUNT(*) > 1;
