-- platform fee must be the contract rate in force on order_date
SELECT s.order_id, s.order_date, s.fee_pct
FROM stg_order_priced s
WHERE s.fee_pct <> (
    SELECT CAST(pf.fee_pct AS REAL)
    FROM raw_platform_fees pf
    WHERE pf.platform_code = s.platform_code
      AND pf.effective_from <= s.order_date
      AND (pf.effective_to = '' OR pf.effective_to >= s.order_date)
    ORDER BY pf.effective_from DESC
    LIMIT 1
);
