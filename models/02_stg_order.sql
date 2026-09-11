-- Staging: one row per order out of the landing table.
--
-- FIX: raw_orders is not order-grain. The March 2026 loader outage was
-- resolved by re-running the extract for the rest of the month (see
-- HANDOVER.md), and that re-run re-landed rows instead of replacing them:
-- 2,957 orders (5,914 rows) from March 2026 exist twice in raw_orders, same
-- order_ts/amount/status, differing only in ingested_at. Every model built
-- straight on raw_orders was silently double-counting all of March 2026 -
-- which sits inside FY2026 Q2. We deduplicate here, at the earliest point in
-- the pipeline, keeping the most recently ingested copy per order_id, so
-- every downstream model is protected without repeating this logic.
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
WHERE o.ingested_at = (
    SELECT MAX(o2.ingested_at) FROM raw_orders o2 WHERE o2.order_id = o.order_id
);

CREATE INDEX ix_stg_order ON stg_order(order_id);
