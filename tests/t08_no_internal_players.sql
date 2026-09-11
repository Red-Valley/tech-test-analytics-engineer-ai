-- internal, test and QA accounts must never appear in the revenue fact
SELECT f.order_id, f.player_id FROM fact_order f
JOIN dim_player p ON p.player_id = f.player_id
WHERE p.is_internal = 1;
