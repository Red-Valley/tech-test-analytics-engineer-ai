-- fee_pct on a priced order must come from the platform_fees row effective on that order's own date, not just any row for the platform
SELECT s.order_id, s.platform_code, s.order_date, s.fee_pct
FROM stg_order_priced s
WHERE NOT EXISTS (
    SELECT 1 FROM raw_platform_fees pf
    WHERE pf.platform_code = s.platform_code
      AND pf.effective_from <= s.order_date
      AND (pf.effective_to IS NULL OR pf.effective_to = '' OR pf.effective_to >= s.order_date)
      AND CAST(pf.fee_pct AS REAL) = s.fee_pct
);
