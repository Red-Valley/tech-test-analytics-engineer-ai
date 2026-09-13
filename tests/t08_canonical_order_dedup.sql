-- one staging row per source order_id and no conflicting duplicate business values
SELECT order_id, COUNT(*) AS rows_in_staging
FROM stg_order
GROUP BY order_id
HAVING COUNT(*) <> 1
UNION ALL
SELECT order_id, source_row_count
FROM stg_order_conflicts
UNION ALL
SELECT 'canonical_order_count', (SELECT COUNT(*) FROM stg_order)
WHERE (SELECT COUNT(*) FROM stg_order) <> (SELECT COUNT(DISTINCT order_id) FROM raw_orders);
