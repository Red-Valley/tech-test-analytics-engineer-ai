-- defends defect #5: fx_rates.csv has no Saturday/Sunday row for any currency; orders placed on
-- a weekend must still resolve to the last published (business-day) rate, never NULL
SELECT order_id, order_date, rate_to_usd
FROM stg_order_priced
WHERE strftime('%w', order_date) IN ('0', '6')
  AND rate_to_usd IS NULL;
