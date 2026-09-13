-- every priced order must resolve to exactly one in-force platform fee between 0 and 1
SELECT order_id, platform_code, order_date, fee_pct FROM stg_order_priced
WHERE fee_pct IS NULL OR fee_pct < 0 OR fee_pct > 1;
