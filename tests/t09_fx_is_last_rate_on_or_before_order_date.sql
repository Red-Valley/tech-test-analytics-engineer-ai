-- FX applied = last published rate on or before the order date; USD = 1 (D5, D6)
SELECT f.order_id, f.order_date, f.currency_code, f.rate_to_usd, f.fx_rate_date
FROM fact_order f
WHERE (f.currency_code = 'USD' AND f.rate_to_usd <> 1.0)
   OR (f.currency_code <> 'USD' AND (
          f.fx_rate_date IS NULL
       OR f.fx_rate_date > f.order_date
       -- a newer published rate existed on or before the order date
       OR EXISTS (SELECT 1 FROM raw_fx_rates r
                   WHERE r.currency_code = f.currency_code
                     AND r.rate_date > f.fx_rate_date AND r.rate_date <= f.order_date)
       -- the rate used is not the one published for fx_rate_date
       OR NOT EXISTS (SELECT 1 FROM raw_fx_rates r
                       WHERE r.currency_code = f.currency_code
                         AND r.rate_date = f.fx_rate_date
                         AND CAST(r.rate_to_usd AS REAL) = f.rate_to_usd)));
