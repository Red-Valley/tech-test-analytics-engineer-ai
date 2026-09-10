-- Convert to USD and attach the platform fee.
--
-- FX: REVENUE_POLICY.md says USD needs no conversion, and non-USD orders convert at "the last
-- published rate on or before the order date" - rates only publish on business days, so exact-date
-- matching leaves every weekend order with no rate at all (NULL gross on ~35% of non-USD orders).
-- Two bugs here, not one: the join must be "on or before", *and* it must not run for USD orders in
-- the first place. raw_fx_rates carries a currency_code='USD' series too, and it isn't a flat 1.0 -
-- it drifts from ~1.02 in late 2024 down to ~0.90 by late 2025 and back to ~0.94 by FY2026 Q2. That
-- looks like a real rate but there's nothing in REVENUE_POLICY.md that calls for converting USD to
-- USD, and doing it anyway silently discounted every USD order (46% of all orders, the single
-- biggest currency) by several percent. Forcing rate_to_usd = 1 for USD sidesteps the question of
-- what that series even is.
--
-- Fee: REVENUE_POLICY.md says the fee "in force on the date of the order" applies, and the fee
-- schedule changes over time (raw_platform_fees has effective_from/effective_to per platform). The
-- old subquery ignored both order_date and effective_to and just took whichever row had the
-- latest effective_from - i.e. today's fee applied to every historical order regardless of when it
-- was placed. Note effective_to is an *empty string* for open-ended rows, not SQL NULL - build.py
-- loads every CSV column as TEXT, so a blank cell lands as '' and "IS NULL" alone silently drops
-- every currently-open fee row (PSN, EPIC, NSW, and the current STEAM/XBOX rate).

DROP TABLE IF EXISTS stg_order_priced;
CREATE TABLE stg_order_priced AS
SELECT s.*,
       CASE WHEN s.currency_code = 'USD' THEN 1.0
            ELSE (SELECT fx.rate_to_usd
                    FROM raw_fx_rates fx
                   WHERE fx.currency_code = s.currency_code
                     AND fx.rate_date <= s.order_date
                   ORDER BY fx.rate_date DESC
                   LIMIT 1)
       END                                                AS rate_to_usd,
       (SELECT CAST(pf.fee_pct AS REAL)
          FROM raw_platform_fees pf
         WHERE pf.platform_code = s.platform_code
           AND pf.effective_from <= s.order_date
           AND (pf.effective_to IS NULL OR pf.effective_to = '' OR pf.effective_to >= s.order_date)
         ORDER BY pf.effective_from DESC
         LIMIT 1)                                        AS fee_pct
FROM stg_order s;

CREATE INDEX ix_stg_order_priced ON stg_order_priced(order_id);
