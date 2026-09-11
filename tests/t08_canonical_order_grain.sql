-- staging must contain exactly one canonical row per source order_id

SELECT
    order_id,
    COUNT(*) AS row_count
FROM stg_order
GROUP BY order_id
HAVING COUNT(*) <> 1

UNION ALL

SELECT
    '__ROW_COUNT_MISMATCH__' AS order_id,
    COUNT(*) AS row_count
FROM stg_order
HAVING COUNT(*) <> (
    SELECT COUNT(DISTINCT order_id)
    FROM raw_orders
);