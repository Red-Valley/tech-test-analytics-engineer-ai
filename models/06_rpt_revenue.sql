-- Reporting mart: net revenue by fiscal quarter and title. This is the number leadership sees.
-- Fiscal attribution goes through dim_date, never through ad-hoc date arithmetic in the report.

DROP TABLE IF EXISTS rpt_revenue_fiscal_quarter_title;
CREATE TABLE rpt_revenue_fiscal_quarter_title AS
SELECT d.fiscal_year,
       d.fiscal_quarter_no,
       d.fiscal_quarter,
       f.title_id,
       t.title_name,
       COUNT(*)                         AS orders,
       ROUND(SUM(f.gross_usd), 2)        AS gross_usd,
       ROUND(SUM(f.refund_usd), 2)       AS refund_usd,
       ROUND(SUM(f.platform_fee_usd), 2) AS platform_fee_usd,
       ROUND(SUM(f.net_revenue_usd), 2)  AS net_revenue_usd
FROM fact_order f
JOIN dim_date  d ON d.date     = f.order_date
JOIN dim_title t ON t.title_id = f.title_id
GROUP BY d.fiscal_year, d.fiscal_quarter_no, d.fiscal_quarter, f.title_id, t.title_name;
