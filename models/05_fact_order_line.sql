-- Line-level revenue fact. Grain: ONE ROW PER ORDER LINE, same scope as fact_order.
--
-- This is what the old fact_order tried to be: revenue by item type. Joining lines onto the order
-- header repeated the full order amount on every line. Here each line carries its own share:
-- order-level measures are allocated by the line's share of the order's gross (lines sum exactly
-- to the order gross in the source), so SUM over lines == SUM over fact_order for every measure.

DROP TABLE IF EXISTS fact_order_line;
CREATE TABLE fact_order_line AS
WITH line_share AS (
    SELECT i.*,
           i.line_gross_local / SUM(i.line_gross_local) OVER (PARTITION BY i.order_id) AS share
    FROM stg_order_item i
)
SELECT f.order_id,
       l.line_no,
       f.order_date,
       f.player_id,
       f.title_id,
       f.platform_code,
       l.sku,
       l.item_type,
       l.quantity,
       f.gross_usd        * l.share AS gross_usd,
       f.refund_usd       * l.share AS refund_usd,
       f.platform_fee_usd * l.share AS platform_fee_usd,
       f.net_revenue_usd  * l.share AS net_revenue_usd
FROM fact_order f
JOIN line_share l ON l.order_id = f.order_id;

CREATE UNIQUE INDEX ux_fact_order_line ON fact_order_line(order_id, line_no);
