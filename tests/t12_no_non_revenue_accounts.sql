-- internal, test, and QA accounts must not reach reported revenue
SELECT f.order_id, p.email_domain
FROM fact_order f
JOIN dim_player p ON p.player_id = f.player_id
WHERE p.email_domain = 'twinhearth.test';
