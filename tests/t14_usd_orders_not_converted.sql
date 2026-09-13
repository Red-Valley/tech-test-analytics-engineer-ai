-- USD is the reporting currency: a USD order's gross_usd must equal its
-- local amount exactly (rate_to_usd = 1.0), never run through raw_fx_rates
SELECT f.order_id, p.currency_code, p.gross_local, f.gross_usd FROM fact_order f
JOIN stg_order_priced p ON p.order_id = f.order_id
WHERE p.currency_code = 'USD' AND ABS(f.gross_usd - p.gross_local) > 0.001;
