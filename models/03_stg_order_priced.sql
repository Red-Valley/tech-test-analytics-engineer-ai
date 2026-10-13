-- Convert to USD and attach the platform fee in force on the order date.
--
-- FX: rates are published on business days only. Policy: use the last published rate on or before
-- the order date (Saturday converts at Friday's rate). We materialise a gap-filled daily rate table
-- once, so the order join is a plain equi-join that scales with order volume.
-- USD is the reporting currency: its rate is 1 by definition. The landing file carries a USD row
-- that is NOT 1 (it drifts 0.90-1.03); it must never be applied.

DROP TABLE IF EXISTS fx_rate_daily;
CREATE TABLE fx_rate_daily AS
WITH cal AS (
    SELECT c.currency_code, d.date
    FROM (SELECT DISTINCT currency_code FROM raw_fx_rates WHERE currency_code <> 'USD') c
    CROSS JOIN dim_date d
),
filled AS (
    SELECT cal.currency_code,
           cal.date,
           (SELECT MAX(f.rate_date) FROM raw_fx_rates f
             WHERE f.currency_code = cal.currency_code AND f.rate_date <= cal.date) AS rate_date
    FROM cal
)
SELECT f.currency_code, f.date, f.rate_date, CAST(r.rate_to_usd AS REAL) AS rate_to_usd
FROM filled f
JOIN raw_fx_rates r ON r.currency_code = f.currency_code AND r.rate_date = f.rate_date
UNION ALL
SELECT 'USD', date, date, 1.0 FROM dim_date;

CREATE UNIQUE INDEX ux_fx_rate_daily ON fx_rate_daily(currency_code, date);

DROP TABLE IF EXISTS stg_order_priced;
CREATE TABLE stg_order_priced AS
SELECT s.*,
       fx.rate_to_usd,
       fx.rate_date                                   AS fx_rate_date,
       pf.fee_pct
FROM stg_order s
LEFT JOIN fx_rate_daily fx
       ON fx.currency_code = s.currency_code
      AND fx.date          = s.order_date
LEFT JOIN dim_platform_fee pf
       ON pf.platform_code = s.platform_code
      AND s.order_date BETWEEN pf.effective_from AND pf.effective_to;

CREATE UNIQUE INDEX ux_stg_order_priced ON stg_order_priced(order_id);
