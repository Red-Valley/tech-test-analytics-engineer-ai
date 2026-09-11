-- Convert to USD and attach the platform fee.
-- FX comes from the daily rate file. Fees come from the platform fee schedule.
--
-- FIX 1 (FX date matching): the old join matched fx.rate_date = order_date
-- exactly. raw_fx_rates only has Monday-Friday rows (rates are published on
-- business days only), so every order placed on a Saturday or Sunday got no
-- match at all -> NULL rate -> NULL revenue for ~35% of all orders. Per
-- REVENUE_POLICY.md ("Currency"): "Non-USD orders are converted using the
-- last published rate on or before the order date." We now pick the most
-- recent rate on or before the order date instead of an exact match.
--
-- FIX 2 (USD pass-through): raw_fx_rates also contains a 'USD' row for every
-- date, but it isn't exactly 1.0 - it drifts (~0.90-1.06) like a noisy
-- decoy. REVENUE_POLICY.md is explicit that conversion applies to "non-USD
-- orders"; USD orders are already in the reporting currency and must not be
-- run through this table at all. We special-case currency_code = 'USD' to
-- rate_to_usd = 1.0.
--
-- FIX 3 (fee date matching): the old subquery took
-- `ORDER BY effective_from DESC LIMIT 1` with no date filter at all, so
-- every order in history got whichever fee row happens to have the latest
-- effective_from - i.e. today's rate applied retroactively to the past.
-- Per REVENUE_POLICY.md ("Net revenue"): "the rate in force on the date of
-- the order is the one that applies." We now filter to schedule rows that
-- were actually in force on the order date. Note the whole raw layer is
-- loaded as TEXT (see bin/build.py), so an open-ended effective_to in the
-- CSV lands as an empty string '', not NULL - both are treated as "still in
-- force" below.
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
       END                                              AS rate_to_usd,
       (SELECT CAST(pf.fee_pct AS REAL)
          FROM raw_platform_fees pf
         WHERE pf.platform_code   = s.platform_code
           AND pf.effective_from <= s.order_date
           AND (pf.effective_to IS NULL OR pf.effective_to = '' OR pf.effective_to >= s.order_date)
         ORDER BY pf.effective_from DESC
         LIMIT 1)                                        AS fee_pct
FROM stg_order s;

CREATE INDEX ix_stg_order_priced ON stg_order_priced(order_id);
