-- defends defect #4: internal/test/QA accounts (email_domain = 'twinhearth.test') buy through the
-- same live stores as real players and must be excluded from every reported metric
SELECT f.order_id, f.player_id
FROM fact_order f
JOIN dim_player p ON p.player_id = f.player_id
WHERE p.is_internal_test = 1;
