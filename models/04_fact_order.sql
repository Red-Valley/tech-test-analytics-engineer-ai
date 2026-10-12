-- The revenue fact. Joined to the line items so the report can break revenue down by item type.
DROP TABLE IF EXISTS fact_order;

CREATE TABLE fact_order AS
SELECT
       p.order_id,
       p.order_date,
       date(p.order_date, '+30 day') AS settlement_date,
       p.player_id,
       p.title_id,
       p.platform_code,
       p.order_status,

       p.gross_local * p.rate_to_usd AS gross_usd,

       p.gross_local * p.rate_to_usd * p.fee_pct
           AS platform_fee_usd,

       CASE
           WHEN p.order_status = 'refunded'
           THEN p.gross_local * p.rate_to_usd
           ELSE 0
       END AS refund_usd,

       CASE
           WHEN p.order_status = 'refunded'
           THEN 0
           ELSE p.gross_local * p.rate_to_usd * (1 - p.fee_pct)
       END AS net_usd

FROM stg_order_priced p
JOIN raw_players pl
     ON pl.player_id = p.player_id

WHERE p.order_status = 'completed'
  AND pl.email_domain <> 'twinhearth.test';

CREATE INDEX ix_fact_order ON fact_order(order_id);
