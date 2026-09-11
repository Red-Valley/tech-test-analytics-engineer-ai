-- Finance revenue fact.
--
-- Grain: one row per eligible business order.
--
-- Revenue policy:
--   * completed/refunded orders only
--   * internal/test/QA players excluded
--   * refunds come from the refunds system of record
--   * platform fees are refunded proportionally with refunds
--   * revenue is recognised on the original order date
--
-- Net revenue:
--   (gross - refunds) * FX * (1 - platform fee)

DROP TABLE IF EXISTS fact_order;

CREATE TABLE fact_order AS
SELECT
    p.order_id,
    p.order_date,
    p.player_id,
    p.title_id,
    p.platform_code,
    p.order_status,
    p.currency_code,

    p.gross_local,
    p.refund_local,
    p.rate_to_usd,
    p.fx_rate_date,
    p.fee_pct,

    p.gross_local
        * p.rate_to_usd
        AS gross_usd,

    p.refund_local
        * p.rate_to_usd
        AS refund_usd,

    (p.gross_local - p.refund_local)
        * p.rate_to_usd
        * p.fee_pct
        AS platform_fee_usd,

    (p.gross_local - p.refund_local)
        * p.rate_to_usd
        * (1.0 - p.fee_pct)
        AS net_usd

FROM stg_order_priced p

JOIN dim_player dp
  ON dp.player_id = p.player_id

WHERE p.order_status IN ('completed', 'refunded')
  AND dp.email_domain <> 'twinhearth.test';


CREATE UNIQUE INDEX ix_fact_order
    ON fact_order(order_id);

CREATE INDEX ix_fact_order_date
    ON fact_order(order_date);

CREATE INDEX ix_fact_order_title
    ON fact_order(title_id);