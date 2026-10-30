-- Staging: keep the latest ingested copy of each order.

DROP TABLE IF EXISTS stg_order;
CREATE TABLE stg_order AS
WITH ranked_orders AS (
    SELECT o.*,
           ROW_NUMBER() OVER (
               PARTITION BY o.order_id
               ORDER BY o.ingested_at DESC
           ) AS row_num
    FROM raw_orders o
)
SELECT order_id,
       player_id,
       title_id,
       platform_code,
       substr(order_ts, 1, 10)               AS order_date,
       order_ts,
       currency_code,
       CAST(gross_amount_local AS REAL)      AS gross_local,
       order_status,
       ingested_at
FROM ranked_orders
WHERE row_num = 1;

CREATE INDEX ix_stg_order ON stg_order(order_id);
