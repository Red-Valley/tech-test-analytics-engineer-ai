-- defends defect #6: the fee applied must be the one in force on the order date, not simply the
-- most recent row in platform_fees.csv (STEAM and XBOX both changed rates during the data's range)
SELECT s.order_id, s.platform_code, s.order_date, s.fee_pct,
       (SELECT CAST(pf.fee_pct AS REAL) FROM raw_platform_fees pf
         WHERE pf.platform_code = s.platform_code
           AND pf.effective_from <= s.order_date
           AND (pf.effective_to IS NULL OR pf.effective_to = '' OR pf.effective_to >= s.order_date)
         ORDER BY pf.effective_from DESC LIMIT 1)         AS expected_fee_pct
FROM stg_order_priced s
WHERE ABS(s.fee_pct - (
        SELECT CAST(pf.fee_pct AS REAL) FROM raw_platform_fees pf
         WHERE pf.platform_code = s.platform_code
           AND pf.effective_from <= s.order_date
           AND (pf.effective_to IS NULL OR pf.effective_to = '' OR pf.effective_to >= s.order_date)
         ORDER BY pf.effective_from DESC LIMIT 1)) > 0.0001;
