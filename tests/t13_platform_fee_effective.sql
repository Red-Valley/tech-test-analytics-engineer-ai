-- every order uses the fee schedule row effective on its order date
SELECT p.order_id, p.platform_code, p.order_date, p.fee_pct
FROM stg_order_priced p
WHERE p.fee_pct IS NULL
   OR ABS(p.fee_pct - (
       SELECT CAST(pf.fee_pct AS REAL)
       FROM raw_platform_fees pf
       WHERE pf.platform_code = p.platform_code
         AND pf.effective_from <= p.order_date
         AND (pf.effective_to = '' OR pf.effective_to >= p.order_date)
       ORDER BY pf.effective_from DESC
       LIMIT 1
   )) > 0.000001;
