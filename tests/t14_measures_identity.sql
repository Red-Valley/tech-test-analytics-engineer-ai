-- money adds up on every order: gross - refunds = platform fee + net revenue, fee in [0,1)
SELECT order_id, gross_usd, refund_usd, platform_fee_usd, net_revenue_usd, fee_pct
FROM fact_order
WHERE ABS((gross_usd - refund_usd) - (platform_fee_usd + net_revenue_usd)) > 0.0001
   OR ABS(net_revenue_usd - (gross_local - refund_local) * rate_to_usd * (1 - fee_pct)) > 0.0001
   OR fee_pct < 0 OR fee_pct >= 1;
