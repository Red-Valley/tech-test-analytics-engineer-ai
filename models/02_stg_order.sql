-- Staging: one row per order out of the landing table.
--
-- The March 2026 loader outage (see HANDOVER.md) was fixed by re-running the extract for the
-- rest of the month. That re-run re-landed rows that had already landed: 2,957 order_ids appear
-- twice in raw_orders, both copies identical except ingested_at, all dated 2026-03-xx. Nothing
-- downstream deduped it, so every one of those orders was counted twice - entirely inside the
-- FY2026 Q2 window we're being asked to report. Keep the most recently ingested copy of each
-- order_id; ties can't happen here since ingested_at differs between the original load and the
-- re-run, but MIN(rowid) breaks any future tie deterministically instead of picking at random.

DROP TABLE IF EXISTS stg_order;
CREATE TABLE stg_order AS
SELECT order_id, player_id, title_id, platform_code, order_date, order_ts,
       currency_code, gross_local, order_status, ingested_at
FROM (
    SELECT o.order_id,
           o.player_id,
           o.title_id,
           o.platform_code,
           substr(o.order_ts, 1, 10)          AS order_date,
           o.order_ts,
           o.currency_code,
           CAST(o.gross_amount_local AS REAL) AS gross_local,
           o.order_status,
           o.ingested_at,
           ROW_NUMBER() OVER (
               PARTITION BY o.order_id
               ORDER BY o.ingested_at DESC, o.rowid ASC
           ) AS rn
    FROM raw_orders o
)
WHERE rn = 1;

CREATE INDEX ix_stg_order ON stg_order(order_id);
