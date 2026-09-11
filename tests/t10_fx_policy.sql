-- FX must be 1 for USD and last published rate on or before order date otherwise

WITH expected AS (
    SELECT
        p.order_id,
        p.currency_code,
        p.order_date,
        p.rate_to_usd,
        p.fx_rate_date,

        CASE
            WHEN p.currency_code = 'USD' THEN 1.0
            ELSE (
                SELECT CAST(fx.rate_to_usd AS REAL)
                FROM raw_fx_rates fx
                WHERE fx.currency_code = p.currency_code
                  AND fx.rate_date <= p.order_date
                ORDER BY fx.rate_date DESC
                LIMIT 1
            )
        END AS expected_rate,

        CASE
            WHEN p.currency_code = 'USD' THEN NULL
            ELSE (
                SELECT fx.rate_date
                FROM raw_fx_rates fx
                WHERE fx.currency_code = p.currency_code
                  AND fx.rate_date <= p.order_date
                ORDER BY fx.rate_date DESC
                LIMIT 1
            )
        END AS expected_rate_date

    FROM stg_order_priced p
)

SELECT
    order_id,
    currency_code,
    order_date,
    rate_to_usd,
    expected_rate,
    fx_rate_date,
    expected_rate_date
FROM expected
WHERE expected_rate IS NULL
   OR rate_to_usd IS NULL
   OR ABS(rate_to_usd - expected_rate) > 0.000000001
   OR (
        currency_code <> 'USD'
        AND fx_rate_date <> expected_rate_date
      )
   OR (
        currency_code = 'USD'
        AND fx_rate_date IS NOT NULL
      );