-- Canonical item staging: one row per (order_id, line_no).
-- Duplicate business keys are checked separately and cannot multiply order facts.

DROP TABLE IF EXISTS stg_order_item_conflicts;
CREATE TABLE stg_order_item_conflicts AS
SELECT order_id,
       line_no,
       COUNT(*) AS source_row_count,
       COUNT(DISTINCT sku) AS sku_values,
       COUNT(DISTINCT item_type) AS item_type_values,
       COUNT(DISTINCT quantity) AS quantity_values,
       COUNT(DISTINCT unit_price_local) AS unit_price_values
FROM raw_order_items
GROUP BY order_id, line_no
HAVING COUNT(DISTINCT sku) > 1
    OR COUNT(DISTINCT item_type) > 1
    OR COUNT(DISTINCT quantity) > 1
    OR COUNT(DISTINCT unit_price_local) > 1;

DROP TABLE IF EXISTS stg_order_item;
CREATE TABLE stg_order_item AS
WITH ranked AS (
    SELECT i.*,
           ROW_NUMBER() OVER (
               PARTITION BY order_id, line_no
               ORDER BY sku DESC, item_type DESC, quantity DESC,
                        unit_price_local DESC, rowid
           ) AS rn
    FROM raw_order_items i
)
SELECT order_id,
       CAST(line_no AS INTEGER) AS line_no,
       sku,
       item_type,
       CAST(quantity AS REAL) AS quantity,
       CAST(unit_price_local AS REAL) AS unit_price_local
FROM ranked
WHERE rn = 1;

CREATE UNIQUE INDEX ux_stg_order_item ON stg_order_item(order_id, line_no);
