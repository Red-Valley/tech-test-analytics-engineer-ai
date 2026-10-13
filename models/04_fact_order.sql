-- The revenue fact. Grain: ONE ROW PER ORDER, in-scope orders only.
--
-- In scope (REVENUE_POLICY "Scope"): completed orders from real players.
--   * order_status 'completed' or 'refunded' (a fully refunded order did complete; its gross and
--     its refund both belong in the numbers and net to zero). 'pending' never completed: excluded.
--   * internal / test / QA accounts excluded via dim_player.is_internal.
--
-- Measures (all additive, all USD at the order-date rate):
--   gross_usd         what the player paid
--   refund_usd        sum of refunds (full + partial) from the refunds table, attributed to the
--                     ORDER date (revenue view; the cash view by refund date is a separate concern)
--   platform_fee_usd  store's cut on (gross - refunds): the store refunds its fee with the refund
--   net_revenue_usd   (gross - refunds) * (1 - fee)
--
-- Item-type breakdowns live in fact_order_line (05), never by joining lines onto this table.
-- settlement_date is intentionally not carried: settlement delay varies by store (30-60 days) and
-- there is no source for the terms. A hard-coded +30 days was wrong for most stores.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
WITH refunds AS (
    SELECT order_id, SUM(refund_local) AS refund_local, COUNT(*) AS refund_count
    FROM stg_refund
    GROUP BY order_id
)
SELECT p.order_id,
       p.order_date,
       p.player_id,
       p.title_id,
       p.platform_code,
       p.order_status,
       p.currency_code,
       p.gross_local,
       COALESCE(r.refund_local, 0)                                        AS refund_local,
       COALESCE(r.refund_count, 0)                                        AS refund_count,
       p.rate_to_usd,
       p.fx_rate_date,
       p.fee_pct,
       p.gross_local * p.rate_to_usd                                      AS gross_usd,
       COALESCE(r.refund_local, 0) * p.rate_to_usd                        AS refund_usd,
       (p.gross_local - COALESCE(r.refund_local, 0)) * p.rate_to_usd * p.fee_pct
                                                                          AS platform_fee_usd,
       (p.gross_local - COALESCE(r.refund_local, 0)) * p.rate_to_usd * (1 - p.fee_pct)
                                                                          AS net_revenue_usd,
       p.ingested_at
FROM stg_order_priced p
JOIN dim_player pl ON pl.player_id = p.player_id
LEFT JOIN refunds r ON r.order_id = p.order_id
WHERE p.order_status IN ('completed', 'refunded')
  AND pl.is_internal = 0;

CREATE UNIQUE INDEX ux_fact_order ON fact_order(order_id);
CREATE INDEX ix_fact_order_date ON fact_order(order_date, title_id);
