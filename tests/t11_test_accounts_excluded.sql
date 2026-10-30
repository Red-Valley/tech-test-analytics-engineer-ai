-- test accounts are correctly flagged and never enter the revenue fact
SELECT rp.player_id
FROM raw_players rp
LEFT JOIN dim_player dp ON dp.player_id = rp.player_id
WHERE dp.player_id IS NULL
   OR dp.is_test_account != CASE
       WHEN LOWER(rp.email_domain) = 'twinhearth.test' THEN 1
       ELSE 0
   END
UNION
SELECT f.player_id
FROM fact_order f
JOIN dim_player dp ON dp.player_id = f.player_id
WHERE dp.is_test_account != 0;
