-- The revenue fact. Joined to the line items so the report can break revenue down by item type.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
WITH base_orders AS (
    SELECT p.order_id,
           p.order_date,
           date(p.order_date, '+30 day')                          AS settlement_date,
           p.player_id,
           p.title_id,
           p.platform_code,
           p.order_status,
           p.gross_local,
           p.rate_to_usd,
           p.fee_pct,
           p.gross_local * p.rate_to_usd                          AS gross_usd,
           (p.gross_local * p.rate_to_usd) * p.fee_pct            AS platform_fee_usd
      FROM stg_order_priced p
      JOIN raw_players pl ON pl.player_id = p.player_id
     WHERE p.order_status IN ('completed', 'refunded')
       AND pl.acquisition_channel NOT LIKE '%test%'
       AND pl.email_domain NOT LIKE '%test%'
       AND pl.email_domain NOT LIKE '%internal%'
       ),
refund_aggregation AS (
    SELECT order_id,
           COALESCE(SUM(CAST(refund_amount_local AS REAL)), 0) AS refund_local
      FROM raw_refunds
     GROUP BY order_id
),
order_items_summary AS (
     SELECT i.order_id,
           MIN(i.item_type) AS item_type
      FROM raw_order_items i
     GROUP BY i.order_id
)
SELECT o.order_id,
       o.order_date,
       o.settlement_date,
       o.player_id,
       o.title_id,
       o.platform_code,
       i.item_type,
       o.order_status,
       o.gross_usd,
       o.platform_fee_usd,
       COALESCE(r.refund_local, 0) * o.rate_to_usd                AS refund_usd,
       (o.gross_usd - (COALESCE(r.refund_local, 0) * o.rate_to_usd)) * (1 - o.fee_pct) AS net_usd
FROM base_orders o
LEFT JOIN order_items_summary i ON i.order_id = o.order_id
LEFT JOIN refund_aggregation r ON r.order_id = o.order_id;

CREATE INDEX ix_fact_order ON fact_order(order_id);
