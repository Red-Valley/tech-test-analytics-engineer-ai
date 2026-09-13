-- Convert canonical orders to USD and attach the fee effective on order date.
-- FX is business-day data, so this is an as-of lookup, not an exact-date join.

DROP TABLE IF EXISTS stg_order_priced;
CREATE TABLE stg_order_priced AS
SELECT s.*,
       (
           SELECT CAST(fx.rate_to_usd AS REAL)
           FROM raw_fx_rates fx
           WHERE fx.currency_code = s.currency_code
             AND fx.rate_date <= s.order_date
           ORDER BY fx.rate_date DESC
           LIMIT 1
       ) AS rate_to_usd,
       (
           SELECT CAST(pf.fee_pct AS REAL)
           FROM raw_platform_fees pf
           WHERE pf.platform_code = s.platform_code
             AND pf.effective_from <= s.order_date
             AND (pf.effective_to = '' OR pf.effective_to >= s.order_date)
           ORDER BY pf.effective_from DESC
           LIMIT 1
       ) AS fee_pct
FROM stg_order s;

CREATE UNIQUE INDEX ux_stg_order_priced ON stg_order_priced(order_id);
