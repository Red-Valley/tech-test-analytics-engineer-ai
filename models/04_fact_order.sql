-- The revenue fact. One row per completed order.
--
-- FIX 1 (grain): the old model joined straight to raw_order_items and put
-- the item_type on the row. An order with 3 line items therefore produced 3
-- fact rows, each carrying the ORDER's full gross/fee/net amount - so any
-- SUM() over the fact multiplied revenue by the number of items sold, not
-- once per order. 43,680 orders (out of ~109k) have more than one line item.
-- Revenue belongs to the order; item mix is a separate question and now
-- lives in fact_order_item (05), which carries no money columns so it can't
-- be summed into a P&L by mistake.
--
-- FIX 2 (scope - status): the old model kept every order regardless of
-- status and only zeroed 'refunded' ones. Per REVENUE_POLICY.md ("Scope"):
-- "Orders that never completed are not revenue." We now keep only
-- 'completed' and 'refunded' orders (a refunded order was still a completed
-- order) and drop 'pending' (1,639 orders).
--
-- FIX 3 (scope - internal accounts): per REVENUE_POLICY.md ("Scope"),
-- internal/test/QA accounts must be excluded from every reported metric.
-- The old model didn't touch dim_player at all. We now exclude
-- dim_player.is_internal = 1.
--
-- FIX 4 (refunds): the old model treated order_status = 'refunded' as the
-- ONLY signal that revenue should be reduced, and reduced it to zero
-- regardless of whether the refund was partial. Per REVENUE_POLICY.md
-- ("Refunds"): "The refunds table is the system of record. It contains full
-- refunds and partial refunds ... a partially refunded order is still a
-- completed order." In the data, 4,829 orders carry a refund in
-- raw_refunds while STILL showing order_status = 'completed' - the old
-- model counted those at full, un-refunded gross. We now sum actual refund
-- amounts per order straight from raw_refunds, independent of
-- order_status, and net them off gross. A handful of orders (85) have a
-- summed refund that exceeds the original gross by a few cents/points
-- (likely FX or goodwill rounding on the storefront side); we cap the
-- refund at gross so net revenue never goes below zero rather than silently
-- reporting negative revenue on an order.
--
-- FIX 5 (fee on refund): per REVENUE_POLICY.md ("Net revenue" / "Refunds"):
-- "the platform refunds its fee along with them." So the fee that is
-- actually retained applies to the NET (post-refund) amount, not the
-- original gross. platform_fee_usd below is fee_pct * (gross - refund).
DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
SELECT p.order_id,
       p.order_date,
       date(p.order_date, '+30 day')                                   AS settlement_date,
       p.player_id,
       p.title_id,
       p.platform_code,
       p.order_status,
       p.gross_local * p.rate_to_usd                                   AS gross_usd,
       MIN(p.gross_local, COALESCE(r.refund_local, 0)) * p.rate_to_usd AS refund_usd,
       (p.gross_local - MIN(p.gross_local, COALESCE(r.refund_local, 0)))
           * p.rate_to_usd * p.fee_pct                                 AS platform_fee_usd,
       (p.gross_local - MIN(p.gross_local, COALESCE(r.refund_local, 0)))
           * p.rate_to_usd * (1 - p.fee_pct)                           AS net_usd
FROM stg_order_priced p
JOIN dim_player pl ON pl.player_id = p.player_id AND pl.is_internal = 0
LEFT JOIN (
    SELECT order_id, SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
) r ON r.order_id = p.order_id
WHERE p.order_status IN ('completed', 'refunded');

CREATE INDEX ix_fact_order ON fact_order(order_id);
