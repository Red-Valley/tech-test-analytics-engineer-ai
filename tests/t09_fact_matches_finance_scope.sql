-- fact_order must contain exactly the orders eligible under Finance scope

WITH expected AS (
    SELECT
        s.order_id
    FROM stg_order s
    JOIN dim_player p
      ON p.player_id = s.player_id
    WHERE s.order_status IN ('completed', 'refunded')
      AND p.email_domain <> 'twinhearth.test'
),

offenders AS (
    SELECT
        e.order_id,
        'missing_from_fact' AS issue
    FROM expected e
    LEFT JOIN fact_order f
      ON f.order_id = e.order_id
    WHERE f.order_id IS NULL

    UNION ALL

    SELECT
        f.order_id,
        'unexpected_in_fact' AS issue
    FROM fact_order f
    LEFT JOIN expected e
      ON e.order_id = f.order_id
    WHERE e.order_id IS NULL
)

SELECT *
FROM offenders;