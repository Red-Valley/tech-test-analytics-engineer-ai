-- USD orders must price at exactly 1.0, never through the (non-flat, drifting) 'USD' row of raw_fx_rates
SELECT order_id, currency_code, rate_to_usd FROM stg_order_priced
WHERE currency_code = 'USD' AND rate_to_usd != 1.0;
