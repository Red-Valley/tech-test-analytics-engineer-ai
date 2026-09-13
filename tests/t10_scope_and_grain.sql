-- every financial fact row is a real-player order and the order grain is unique
SELECT f.order_id, f.player_id, f.title_id
FROM fact_order f
JOIN dim_player p ON p.player_id = f.player_id
WHERE COALESCE(p.email_domain, '') = 'twinhearth.test'
   OR f.order_status NOT IN ('completed', 'refunded')
UNION ALL
SELECT order_id, order_id, order_id
FROM fact_order
GROUP BY order_id
HAVING COUNT(*) <> 1;
