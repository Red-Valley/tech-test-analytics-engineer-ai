-- Staging: one row per order, one row per order line, one row per refund.
--
-- The landing tables are append-only re-lands. The March 2026 loader outage was patched by
-- re-extracting the rest of the month, which landed ~3k orders (and their lines) a second time.
-- Copies are identical except ingested_at, so we keep the most recently ingested version of each
-- key. That rule also does the right thing if a later re-land ever carries a corrected status.

DROP TABLE IF EXISTS stg_order;
CREATE TABLE stg_order AS
WITH ranked AS (
    SELECT o.*,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY ingested_at DESC) AS rn,
           COUNT(*)     OVER (PARTITION BY order_id)                           AS landed_copies
    FROM raw_orders o
)
SELECT order_id,
       player_id,
       title_id,
       platform_code,
       substr(order_ts, 1, 10)              AS order_date,
       order_ts,
       currency_code,
       CAST(gross_amount_local AS REAL)     AS gross_local,
       order_status,
       ingested_at,
       landed_copies
FROM ranked
WHERE rn = 1;

CREATE UNIQUE INDEX ux_stg_order ON stg_order(order_id);

DROP TABLE IF EXISTS stg_order_item;
CREATE TABLE stg_order_item AS
SELECT order_id,
       CAST(line_no AS INTEGER)                       AS line_no,
       sku,
       item_type,
       CAST(quantity AS INTEGER)                      AS quantity,
       CAST(unit_price_local AS REAL)                 AS unit_price_local,
       CAST(quantity AS INTEGER) * CAST(unit_price_local AS REAL) AS line_gross_local
FROM (SELECT DISTINCT * FROM raw_order_items);
-- DISTINCT collapses identical re-landed lines. If two copies of a line ever DIFFER, the unique
-- index below fails the build loudly instead of keeping an arbitrary copy.

CREATE UNIQUE INDEX ux_stg_order_item ON stg_order_item(order_id, line_no);

-- Refunds are the system of record for money returned (full and partial).
DROP TABLE IF EXISTS stg_refund;
CREATE TABLE stg_refund AS
SELECT refund_id,
       order_id,
       refund_ts,
       substr(refund_ts, 1, 10)              AS refund_date,
       CAST(refund_amount_local AS REAL)     AS refund_local,
       refund_reason
FROM (SELECT DISTINCT * FROM raw_refunds);   -- same rule: identical copies collapse, differing ones fail

CREATE UNIQUE INDEX ux_stg_refund ON stg_refund(refund_id);
CREATE INDEX ix_stg_refund_order ON stg_refund(order_id);
