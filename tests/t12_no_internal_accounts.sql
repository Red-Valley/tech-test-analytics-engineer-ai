-- no internal / test / QA account activity in the revenue fact (D4)
-- Two markers, both independent of dim_player.is_internal:
--  * email domain matched loosely, so a new variant (twinhearth.com, qa.twinhearth.test) fails here;
--  * a player with orders placed BEFORE their own signup date. Only test accounts do this
--    (315 orders, all on @twinhearth.test; zero for real players), so it catches internal
--    accounts that register with a personal email.
WITH pre_signup AS (
    SELECT DISTINCT o.player_id
    FROM raw_orders o
    JOIN raw_players p ON p.player_id = o.player_id
    WHERE substr(o.order_ts, 1, 10) < p.signup_date
)
SELECT f.order_id, f.player_id, p.email_domain,
       CASE WHEN lower(p.email_domain) LIKE '%twinhearth%' THEN 'internal email domain'
            ELSE 'player has orders before signup' END AS reason
FROM fact_order f
JOIN raw_players p ON p.player_id = f.player_id
LEFT JOIN pre_signup s ON s.player_id = f.player_id
WHERE lower(p.email_domain) LIKE '%twinhearth%' OR s.player_id IS NOT NULL;
