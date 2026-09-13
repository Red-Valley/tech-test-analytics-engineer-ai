-- Net revenue reconciles to gross less refunds less the fee on the residual
SELECT order_id, gross_usd, refund_usd, platform_fee_usd, net_usd
FROM fact_order
WHERE gross_usd < -0.000001
   OR refund_usd < -0.000001
   OR platform_fee_usd < -0.000001
   OR net_usd < -0.000001
   OR ABS(net_usd - (gross_usd - refund_usd - platform_fee_usd)) > 0.000001
   OR (order_status = 'refunded' AND ABS(net_usd) > 0.000001);
