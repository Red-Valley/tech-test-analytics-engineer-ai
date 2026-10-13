-- revenue by item type adds back to revenue by order (D1: the item-type breakdown caused the fan-out)
WITH l AS (SELECT order_id, SUM(gross_usd) AS g, SUM(net_revenue_usd) AS n, COUNT(*) AS lines
           FROM fact_order_line GROUP BY order_id)
SELECT f.order_id, f.gross_usd, l.g AS line_gross, f.net_revenue_usd, l.n AS line_net
FROM fact_order f
LEFT JOIN l ON l.order_id = f.order_id
WHERE l.order_id IS NULL
   OR ABS(f.gross_usd - l.g) > 0.0001
   OR ABS(f.net_revenue_usd - l.n) > 0.0001;
