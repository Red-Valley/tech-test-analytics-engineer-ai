-- refund_usd is capped at gross_usd upstream; this guards the cap doesn't regress
SELECT order_id, gross_usd, refund_usd FROM fact_order
WHERE refund_usd > gross_usd + 0.01;
