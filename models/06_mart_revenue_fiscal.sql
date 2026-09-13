-- Net revenue by fiscal period and title. This is the table the FY2026 Q2
-- headline number is read from.
DROP TABLE IF EXISTS mart_revenue_by_fiscal_period;
CREATE TABLE mart_revenue_by_fiscal_period AS
SELECT d.fiscal_year,
       d.fiscal_quarter_no,
       f.title_id,
       t.title_name,
       COUNT(*)                AS completed_orders,
       SUM(f.gross_usd)        AS gross_usd,
       SUM(f.refund_usd)       AS refund_usd,
       SUM(f.platform_fee_usd) AS platform_fee_usd,
       SUM(f.net_usd)          AS net_revenue_usd
FROM fact_order f
JOIN dim_date  d ON d.date = f.order_date
JOIN dim_title t ON t.title_id = f.title_id
GROUP BY d.fiscal_year, d.fiscal_quarter_no, f.title_id, t.title_name;
