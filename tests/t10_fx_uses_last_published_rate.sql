-- non-USD orders must use the most recent published FX rate on or before order_date
SELECT s.order_id, s.order_date, s.rate_to_usd
FROM stg_order_priced s
WHERE s.currency_code <> 'USD'
  AND (
      s.rate_to_usd IS NULL
      OR ABS(s.rate_to_usd - (
          SELECT CAST(fx.rate_to_usd AS REAL)
          FROM raw_fx_rates fx
          WHERE fx.currency_code = s.currency_code
            AND fx.rate_date <= s.order_date
          ORDER BY fx.rate_date DESC
          LIMIT 1
      )) > 0.000001
  );
