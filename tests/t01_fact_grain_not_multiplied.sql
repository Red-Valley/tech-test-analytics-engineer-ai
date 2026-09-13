-- fact_order is exactly one row per canonical order_id
SELECT order_id, COUNT(*) AS in_fact
FROM fact_order
GROUP BY order_id
HAVING COUNT(*) <> 1;
