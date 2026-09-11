-- Staging: one canonical row per business order.
--
-- The landing table can contain replayed extracts. In the supplied data,
-- 2,957 March orders were landed twice with identical business values.
-- Keep the latest landed version of each order_id so downstream models
-- operate at one row per business order.

DROP TABLE IF EXISTS stg_order;

CREATE TABLE stg_order AS
WITH ranked_orders AS (
    SELECT
        o.order_id,
        o.player_id,
        o.title_id,
        o.platform_code,
        substr(o.order_ts, 1, 10) AS order_date,
        o.order_ts,
        o.currency_code,
        CAST(o.gross_amount_local AS REAL) AS gross_local,
        o.order_status,
        o.ingested_at,

        ROW_NUMBER() OVER (
            PARTITION BY o.order_id
            ORDER BY o.ingested_at DESC
        ) AS row_num

    FROM raw_orders o
)

SELECT
    order_id,
    player_id,
    title_id,
    platform_code,
    order_date,
    order_ts,
    currency_code,
    gross_local,
    order_status,
    ingested_at

FROM ranked_orders
WHERE row_num = 1;


CREATE UNIQUE INDEX ix_stg_order
    ON stg_order(order_id);