-- staged refunds must reconcile to the refunds system of record

WITH expected_refunds AS (
    SELECT
        order_id,
        SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
),

comparison AS (
    SELECT
        p.order_id,
        p.gross_local,
        p.refund_local,
        COALESCE(r.refund_local, 0.0) AS expected_refund_local
    FROM stg_order_priced p
    LEFT JOIN expected_refunds r
      ON r.order_id = p.order_id
)

SELECT
    order_id,
    gross_local,
    refund_local,
    expected_refund_local
FROM comparison
WHERE ABS(refund_local - expected_refund_local) > 0.000000001
   OR refund_local > gross_local;