-- every non-USD order must resolve to a priced FX rate; no order should be
-- dropped from revenue just because it landed on a non-business day
SELECT order_id, currency_code, order_date FROM stg_order_priced
WHERE currency_code != 'USD' AND rate_to_usd IS NULL;
