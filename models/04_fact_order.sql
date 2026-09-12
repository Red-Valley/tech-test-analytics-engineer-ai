-- The revenue fact. Grain = 1 row per order (order_id is the primary key). Item-level detail
-- (item_type/sku mix) lives in fact_order_item below, at its own order*item grain, so it never
-- multiplies the dollar measures here.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
SELECT p.order_id,
       p.order_date,
       date(p.order_date, '+30 day')                          AS settlement_date,
       p.player_id,
       p.title_id,
       p.platform_code,
       p.order_status,
       p.gross_local * p.rate_to_usd                          AS gross_usd,
       COALESCE(p.refund_local, 0) * p.rate_to_usd            AS refund_usd,
       (p.gross_local - COALESCE(p.refund_local, 0)) * p.rate_to_usd * p.fee_pct       AS platform_fee_usd,
       (p.gross_local - COALESCE(p.refund_local, 0)) * p.rate_to_usd * (1 - p.fee_pct) AS net_usd
FROM stg_order_priced p;

CREATE INDEX ix_fact_order ON fact_order(order_id);

-- Item-level bridge for mix/count analysis (item_type, sku, quantity). Not a source of dollar
-- totals -- join back to fact_order only for counts/shares, never to re-sum gross/net revenue.
DROP TABLE IF EXISTS fact_order_item;
CREATE TABLE fact_order_item AS
SELECT i.order_id, i.line_no, i.sku, i.item_type, i.quantity,
       CAST(i.unit_price_local AS REAL) AS unit_price_local
FROM raw_order_items i
WHERE i.order_id IN (SELECT order_id FROM fact_order);

CREATE INDEX ix_fact_order_item ON fact_order_item(order_id);
