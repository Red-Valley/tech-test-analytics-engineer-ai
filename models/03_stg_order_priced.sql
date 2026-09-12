-- Convert to USD and attach the platform fee.
-- FX comes from the daily rate file. Fees come from the platform fee schedule.
--
-- FX: rates are published on business days only (no Saturday/Sunday row, for any currency,
-- including USD). REVENUE_POLICY.md: convert at the last published rate on or before the order
-- date -- so weekend orders use the prior business day's rate, not an exact-date match.
DROP TABLE IF EXISTS stg_order_priced;
CREATE TABLE stg_order_priced AS
SELECT s.*,
       (SELECT fx.rate_to_usd
          FROM raw_fx_rates fx
         WHERE fx.currency_code = s.currency_code
           AND fx.rate_date <= s.order_date
         ORDER BY fx.rate_date DESC
         LIMIT 1)                                        AS rate_to_usd,
       (SELECT CAST(pf.fee_pct AS REAL)
          FROM raw_platform_fees pf
         WHERE pf.platform_code = s.platform_code
           AND pf.effective_from <= s.order_date
           AND (pf.effective_to IS NULL OR pf.effective_to = '' OR pf.effective_to >= s.order_date)
         ORDER BY pf.effective_from DESC
         LIMIT 1)                                        AS fee_pct,
       (SELECT SUM(CAST(r.refund_amount_local AS REAL))
          FROM raw_refunds r
         WHERE r.order_id = s.order_id)                  AS refund_local
FROM stg_order s;

CREATE INDEX ix_stg_order_priced ON stg_order_priced(order_id);