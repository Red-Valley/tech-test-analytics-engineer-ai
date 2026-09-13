-- Financial fact at exactly one row per canonical order_id.
-- Item detail is modeled separately in fact_order_item; order measures never
-- join directly to raw_order_items.

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order AS
WITH refunds AS (
    SELECT order_id,
           SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
),
eligible AS (
    SELECT p.order_id,
           p.order_date,
           p.player_id,
           p.title_id,
           p.platform_code,
           p.order_status,
           p.gross_local,
           p.gross_local * p.rate_to_usd AS gross_usd,
           COALESCE(r.refund_local, 0) * p.rate_to_usd AS refund_usd,
           p.fee_pct
    FROM stg_order_priced p
    JOIN dim_player dp ON dp.player_id = p.player_id
    LEFT JOIN refunds r ON r.order_id = p.order_id
    WHERE p.order_status IN ('completed', 'refunded')
      AND COALESCE(dp.email_domain, '') <> 'twinhearth.test'
)
SELECT order_id,
       order_date,
       CAST(NULL AS TEXT) AS settlement_date,
       player_id,
       title_id,
       platform_code,
       order_status,
       gross_local,
       gross_usd,
       refund_usd,
       (gross_usd - refund_usd) * fee_pct AS platform_fee_usd,
       (gross_usd - refund_usd) * (1 - fee_pct) AS net_usd
FROM eligible;

CREATE UNIQUE INDEX ux_fact_order ON fact_order(order_id);
