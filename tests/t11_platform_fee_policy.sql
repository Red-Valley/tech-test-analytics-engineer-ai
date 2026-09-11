-- platform fee must be the contract rate effective on the order date

WITH expected AS (
    SELECT
        p.order_id,
        p.platform_code,
        p.order_date,
        p.fee_pct,

        (
            SELECT CAST(pf.fee_pct AS REAL)
            FROM raw_platform_fees pf
            WHERE pf.platform_code = p.platform_code
              AND pf.effective_from <= p.order_date
              AND (
                    pf.effective_to IS NULL
                    OR pf.effective_to = ''
                    OR pf.effective_to >= p.order_date
                  )
            ORDER BY pf.effective_from DESC
            LIMIT 1
        ) AS expected_fee_pct

    FROM stg_order_priced p
)

SELECT
    order_id,
    platform_code,
    order_date,
    fee_pct,
    expected_fee_pct
FROM expected
WHERE expected_fee_pct IS NULL
   OR fee_pct IS NULL
   OR ABS(fee_pct - expected_fee_pct) > 0.000000001;