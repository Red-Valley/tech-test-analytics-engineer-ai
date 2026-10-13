-- no NULL money, rate or fee on the fact (D5: same-day FX join left weekend orders NULL)
SELECT order_id, order_date, currency_code, rate_to_usd, fee_pct, gross_usd, refund_usd,
       platform_fee_usd, net_revenue_usd
FROM fact_order
WHERE rate_to_usd IS NULL OR fee_pct IS NULL OR gross_usd IS NULL OR refund_usd IS NULL
   OR platform_fee_usd IS NULL OR net_revenue_usd IS NULL;
