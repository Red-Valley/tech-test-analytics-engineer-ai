-- The revenue fact has one row per order. Item-level amounts are not allocated here.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
WITH refunds_by_order AS (
    SELECT order_id,
           SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
)
SELECT p.order_id,
       p.order_date,
       p.player_id,
       p.title_id,
       p.platform_code,
       p.order_status,
       p.gross_local * p.rate_to_usd                                                                AS gross_usd,
       (p.gross_local - COALESCE(r.refund_local, 0))* p.rate_to_usd * p.fee_pct                     AS platform_fee_usd,
       COALESCE(r.refund_local, 0) * p.rate_to_usd                                                  AS refund_usd,
       (p.gross_local - COALESCE(r.refund_local, 0))* p.rate_to_usd * (1 - p.fee_pct)               AS net_usd
FROM stg_order_priced p
JOIN dim_player dp ON dp.player_id = p.player_id
LEFT JOIN refunds_by_order r ON r.order_id = p.order_id
WHERE p.order_status IN ('completed', 'refunded')
  AND dp.is_test_account = 0;

CREATE INDEX ix_fact_order ON fact_order(order_id);
