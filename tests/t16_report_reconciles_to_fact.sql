-- the leadership report equals the fact it is built from, per fiscal quarter and title
-- rpt_revenue_fiscal_quarter_title is the number leadership sees; a bad join or filter there would
-- otherwise pass every fact-level test.
WITH f AS (
    SELECT d.fiscal_quarter, f.title_id, COUNT(*) AS orders, ROUND(SUM(f.net_revenue_usd), 2) AS net
    FROM fact_order f JOIN dim_date d ON d.date = f.order_date
    GROUP BY 1, 2
)
SELECT COALESCE(f.fiscal_quarter, r.fiscal_quarter) AS fiscal_quarter,
       COALESCE(f.title_id, r.title_id) AS title_id,
       f.orders AS fact_orders, r.orders AS rpt_orders, f.net AS fact_net, r.net_revenue_usd AS rpt_net
FROM f FULL OUTER JOIN rpt_revenue_fiscal_quarter_title r
  ON r.fiscal_quarter = f.fiscal_quarter AND r.title_id = f.title_id
WHERE f.orders IS NULL OR r.orders IS NULL OR f.orders <> r.orders OR ABS(f.net - r.net_revenue_usd) > 0.005;
