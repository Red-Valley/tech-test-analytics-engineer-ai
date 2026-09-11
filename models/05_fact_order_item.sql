-- Line-item detail for the orders in fact_order (mix/volume analysis only).
--
-- Deliberately carries NO money columns. Revenue lives at the order grain in
-- fact_order; allocating an order's gross/fee/net down to individual line
-- items would require a proportional-allocation rule that Finance has not
-- specified (by unit price? by quantity? evenly?), and guessing one here
-- would just recreate the original grain bug in a subtler form. Analysts who
-- need "revenue by item type" should ask Finance how to allocate a
-- multi-item order first; until then, this table answers "what did people
-- buy" (item mix / quantity), and fact_order alone answers "how much did we
-- make."
DROP TABLE IF EXISTS fact_order_item;
CREATE TABLE fact_order_item AS
SELECT i.order_id, i.line_no, i.sku, i.item_type, CAST(i.quantity AS INTEGER) AS quantity
FROM raw_order_items i
JOIN fact_order f ON f.order_id = i.order_id;

CREATE INDEX ix_fact_order_item ON fact_order_item(order_id);
