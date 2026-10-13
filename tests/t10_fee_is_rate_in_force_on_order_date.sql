-- platform fee = the contract rate in force on the order date, from the schedule (D7)
SELECT f.order_id, f.order_date, f.platform_code, f.fee_pct AS fee_applied,
       (SELECT GROUP_CONCAT(pf.fee_pct) FROM raw_platform_fees pf
         WHERE pf.platform_code = f.platform_code
           AND f.order_date >= pf.effective_from
           AND (pf.effective_to = '' OR f.order_date <= pf.effective_to)) AS fee_in_force
FROM fact_order f
WHERE 1 <> (SELECT COUNT(*) FROM raw_platform_fees pf
             WHERE pf.platform_code = f.platform_code
               AND f.order_date >= pf.effective_from
               AND (pf.effective_to = '' OR f.order_date <= pf.effective_to)
               AND CAST(pf.fee_pct AS REAL) = f.fee_pct);
