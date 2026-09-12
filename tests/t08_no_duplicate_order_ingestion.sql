-- defends defect #1: the March re-ingest must not double-count an order in staging
SELECT order_id, COUNT(*) AS n
FROM stg_order
GROUP BY order_id
HAVING COUNT(*) > 1;
