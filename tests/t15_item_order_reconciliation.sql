-- Canonical item amounts reconcile to each reportable order's gross local amount
SELECT f.order_id, f.gross_local, COALESCE(SUM(i.item_total_local), 0) AS item_total_local
FROM fact_order f
LEFT JOIN fact_order_item i ON i.order_id = f.order_id
GROUP BY f.order_id, f.gross_local
HAVING ABS(f.gross_local - COALESCE(SUM(i.item_total_local), 0)) > 0.000001
UNION ALL
SELECT order_id, line_no, COUNT(*)
FROM fact_order_item
GROUP BY order_id, line_no
HAVING COUNT(*) <> 1;
