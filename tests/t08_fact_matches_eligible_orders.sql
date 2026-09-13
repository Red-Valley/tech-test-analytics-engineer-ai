-- fact_order must have exactly one row for each latest eligible order
WITH latest_orders AS (
    SELECT o.*,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY ingested_at DESC) AS row_number
    FROM raw_orders o
), expected AS (
    SELECT o.order_id
    FROM latest_orders o
    JOIN dim_player p ON p.player_id = o.player_id
    WHERE o.row_number = 1
      AND o.order_status IN ('completed', 'refunded')
      AND p.email_domain <> 'twinhearth.test'
), actual AS (
    SELECT order_id, COUNT(*) AS row_count
    FROM fact_order
    GROUP BY order_id
)
SELECT order_id FROM expected
EXCEPT
SELECT order_id FROM actual WHERE row_count = 1
UNION ALL
SELECT order_id FROM actual
EXCEPT
SELECT order_id FROM expected
UNION ALL
SELECT order_id FROM actual WHERE row_count <> 1;
