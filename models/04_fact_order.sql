-- The revenue fact has one row per completed, real-player order.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
SELECT p.order_id,
       p.order_date,
       p.player_id,
       p.title_id,
       p.platform_code,
       p.currency_code,
       p.order_status,
       p.fx_rate_date,
       p.rate_to_usd,
       p.fee_pct,
       p.gross_local * p.rate_to_usd                          AS gross_usd,
       p.refund_local * p.rate_to_usd                         AS refund_usd,
       (p.gross_local - p.refund_local) * p.rate_to_usd
           * p.fee_pct                                        AS platform_fee_usd,
       (p.gross_local - p.refund_local) * p.rate_to_usd
           * (1 - p.fee_pct)                                  AS net_usd
FROM stg_order_priced p;

CREATE INDEX ix_fact_order ON fact_order(order_id);
