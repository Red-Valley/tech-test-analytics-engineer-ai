-- item staging and reportable item fact are unique at (order_id, line_no)
SELECT order_id, line_no, COUNT(*) AS rows_in_staging
FROM stg_order_item
GROUP BY order_id, line_no
HAVING COUNT(*) <> 1
UNION ALL
SELECT order_id, line_no, source_row_count
FROM stg_order_item_conflicts
UNION ALL
SELECT 'canonical_item_count', NULL, (SELECT COUNT(*) FROM stg_order_item)
WHERE (SELECT COUNT(*) FROM stg_order_item)
   <> (SELECT COUNT(*) FROM (SELECT order_id, line_no FROM raw_order_items GROUP BY order_id, line_no));
