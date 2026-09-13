-- Item detail is one row per (order_id, line_no), limited to reportable orders.
-- It contains item measures only; order-level gross/refund/net stay in fact_order.

DROP TABLE IF EXISTS fact_order_item;
CREATE TABLE fact_order_item AS
SELECT i.order_id,
       i.line_no,
       i.sku,
       i.item_type,
       i.quantity,
       i.unit_price_local,
       i.quantity * i.unit_price_local AS item_total_local
FROM stg_order_item i
JOIN fact_order f ON f.order_id = i.order_id;

CREATE UNIQUE INDEX ux_fact_order_item ON fact_order_item(order_id, line_no);
