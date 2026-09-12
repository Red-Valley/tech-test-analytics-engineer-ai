-- Staging: one row per order out of the landing table.
--
-- Scope, per REVENUE_POLICY.md: reported revenue covers completed orders from real players.
-- - order_status = 'pending' never completed -> excluded here (refunds are still revenue: a
--   refunded/partially-refunded order was completed, so 'refunded' stays in scope).
-- - internal/test/QA accounts are excluded from every reported metric, everywhere they appear.
DROP TABLE IF EXISTS stg_order;
CREATE TABLE stg_order AS
SELECT o.order_id,
       o.player_id,
       o.title_id,
       o.platform_code,
       substr(o.order_ts, 1, 10)            AS order_date,
       o.order_ts,
       o.currency_code,
       CAST(o.gross_amount_local AS REAL)   AS gross_local,
       o.order_status,
       o.ingested_at
FROM raw_orders o
JOIN dim_player pl ON pl.player_id = o.player_id
WHERE o.ingested_at = (
    SELECT MAX(o2.ingested_at) FROM raw_orders o2 WHERE o2.order_id = o.order_id
)
AND o.order_status != 'pending'
AND pl.is_internal_test = 0;

CREATE UNIQUE INDEX ix_stg_order ON stg_order(order_id);