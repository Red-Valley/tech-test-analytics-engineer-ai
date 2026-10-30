-- USD uses a rate of 1; other currencies use the latest rate on or before order date
SELECT p.order_id, p.currency_code, p.order_date, p.rate_to_usd,
       CASE WHEN p.currency_code = 'USD' THEN 1.0
            ELSE (
                SELECT CAST(fx.rate_to_usd AS REAL)
                FROM raw_fx_rates fx
                WHERE fx.currency_code = p.currency_code
                  AND fx.rate_date <= p.order_date
                ORDER BY fx.rate_date DESC
                LIMIT 1
            )
       END AS expected_rate
FROM stg_order_priced p
WHERE p.rate_to_usd IS NULL
   OR ABS(p.rate_to_usd - CASE WHEN p.currency_code = 'USD' THEN 1.0
                              ELSE (
                                  SELECT CAST(fx.rate_to_usd AS REAL)
                                  FROM raw_fx_rates fx
                                  WHERE fx.currency_code = p.currency_code
                                    AND fx.rate_date <= p.order_date
                                  ORDER BY fx.rate_date DESC
                                  LIMIT 1
                              )
                         END) > 0.000001;
