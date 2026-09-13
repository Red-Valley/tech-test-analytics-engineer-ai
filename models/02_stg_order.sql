-- Canonical order staging: one deterministic row per source order_id.
-- Duplicate business keys are retained in stg_order_conflicts so the build
-- runner can fail closed rather than silently choosing conflicting facts.

DROP TABLE IF EXISTS stg_order_conflicts;
CREATE TABLE stg_order_conflicts AS
SELECT order_id,
       COUNT(*) AS source_row_count,
       COUNT(DISTINCT player_id) AS player_values,
       COUNT(DISTINCT title_id) AS title_values,
       COUNT(DISTINCT platform_code) AS platform_values,
       COUNT(DISTINCT order_ts) AS order_ts_values,
       COUNT(DISTINCT currency_code) AS currency_values,
       COUNT(DISTINCT gross_amount_local) AS gross_values,
       COUNT(DISTINCT order_status) AS status_values
FROM raw_orders
GROUP BY order_id
HAVING COUNT(DISTINCT player_id) > 1
    OR COUNT(DISTINCT title_id) > 1
    OR COUNT(DISTINCT platform_code) > 1
    OR COUNT(DISTINCT order_ts) > 1
    OR COUNT(DISTINCT currency_code) > 1
    OR COUNT(DISTINCT gross_amount_local) > 1
    OR COUNT(DISTINCT order_status) > 1;

DROP TABLE IF EXISTS stg_order;
CREATE TABLE stg_order AS
WITH ranked AS (
    SELECT o.*,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY ingested_at DESC, order_ts DESC, player_id DESC,
                        title_id DESC, platform_code DESC, currency_code DESC,
                        gross_amount_local DESC, order_status DESC
           ) AS rn
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
       ingested_at
FROM ranked
WHERE rn = 1;

CREATE UNIQUE INDEX ux_stg_order ON stg_order(order_id);
