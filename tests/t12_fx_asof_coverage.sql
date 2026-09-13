-- Q2 orders, including weekends, use the latest published rate on or before order date
SELECT p.order_id, p.order_date, p.currency_code, p.rate_to_usd
FROM stg_order_priced p
WHERE p.order_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND p.rate_to_usd IS NULL
UNION ALL
SELECT p.order_id, p.order_date, p.currency_code, p.rate_to_usd
FROM stg_order_priced p
WHERE p.order_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND ABS(p.rate_to_usd - (
      SELECT CAST(fx.rate_to_usd AS REAL)
      FROM raw_fx_rates fx
      WHERE fx.currency_code = p.currency_code
        AND fx.rate_date <= p.order_date
      ORDER BY fx.rate_date DESC
      LIMIT 1
  )) > 0.000001;
