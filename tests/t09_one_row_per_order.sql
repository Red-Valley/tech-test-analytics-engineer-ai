-- fact_order is order-grain: exactly one row per order_id, never more
SELECT order_id, COUNT(*) AS n FROM fact_order
GROUP BY order_id HAVING COUNT(*) > 1;
