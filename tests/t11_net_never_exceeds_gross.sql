-- net revenue can never be larger than gross revenue on the same order
SELECT order_id, gross_usd, net_usd FROM fact_order
WHERE net_usd > gross_usd + 0.01;
