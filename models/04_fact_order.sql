-- The revenue fact. One row per order (see FINDINGS.md on why item-level grain was removed).
--
-- Scope (REVENUE_POLICY.md "Scope"): completed orders from real players. 'pending' orders never
-- completed and are dropped. Internal/QA accounts (dim_player.is_internal) are dropped from every
-- reported metric even though they transacted through the same live stores as everyone else.
--
-- Refunds (REVENUE_POLICY.md "Refunds"): the refunds table is the system of record for both full
-- and partial refunds, and "a partially refunded order is still a completed order" - so this joins
-- every order (not just status='refunded') to its refund rows and nets whatever comes back. Refunds
-- are attributed to the *original order's* date for revenue reporting, so they ride the same FX
-- rate and fee_pct already resolved for that order rather than looking anything up again.
--
-- Net revenue (REVENUE_POLICY.md "Net revenue"): gross minus refunds, net of the platform fee -
-- and "the platform refunds its fee along with them", so the fee is calculated on the
-- already-refund-net amount, not on the original gross.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
SELECT p.order_id,
       p.order_date,
       date(p.order_date, '+30 day')                              AS settlement_date, -- approx; see FINDINGS.md
       p.player_id,
       p.title_id,
       p.platform_code,
       p.order_status,
       p.gross_local * p.rate_to_usd                              AS gross_usd,
       COALESCE(r.refund_local, 0) * p.rate_to_usd                AS refund_usd,
       (p.gross_local - COALESCE(r.refund_local, 0)) * p.rate_to_usd * p.fee_pct
                                                                   AS platform_fee_usd,
       (p.gross_local - COALESCE(r.refund_local, 0)) * p.rate_to_usd * (1 - p.fee_pct)
                                                                   AS net_usd
FROM stg_order_priced p
JOIN dim_player pl ON pl.player_id = p.player_id AND pl.is_internal = 0
LEFT JOIN (
    SELECT order_id, SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
) r ON r.order_id = p.order_id
WHERE p.order_status IN ('completed', 'refunded');

CREATE INDEX ix_fact_order ON fact_order(order_id);
