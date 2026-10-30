-- fact_order has exactly one row per order
SELECT order_id, COUNT(*) AS rows_per_order
FROM fact_order f
GROUP BY order_id
HAVING COUNT(*) > 1;
