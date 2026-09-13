-- Enrich eligible orders with their order-date FX, fee schedule, and refunds.

DROP TABLE IF EXISTS stg_order_priced;
CREATE TABLE stg_order_priced AS
WITH refunds AS (
    SELECT order_id,
           SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
)
SELECT s.*,
       COALESCE(r.refund_local, 0.0) AS refund_local,
       COALESCE(
           (SELECT CAST(fx.rate_to_usd AS REAL)
              FROM raw_fx_rates fx
             WHERE fx.currency_code = s.currency_code
               AND fx.rate_date <= s.order_date
             ORDER BY fx.rate_date DESC
             LIMIT 1),
           CASE WHEN s.currency_code = 'USD' THEN 1.0 END
       ) AS rate_to_usd,
       (SELECT fx.rate_date
          FROM raw_fx_rates fx
         WHERE fx.currency_code = s.currency_code
           AND fx.rate_date <= s.order_date
         ORDER BY fx.rate_date DESC
         LIMIT 1) AS fx_rate_date,
       (SELECT CAST(pf.fee_pct AS REAL)
          FROM raw_platform_fees pf
         WHERE pf.platform_code = s.platform_code
           AND pf.effective_from <= s.order_date
           AND (pf.effective_to = '' OR pf.effective_to >= s.order_date)
         ORDER BY pf.effective_from DESC
         LIMIT 1) AS fee_pct
FROM stg_order s
JOIN dim_player p ON p.player_id = s.player_id
LEFT JOIN refunds r ON r.order_id = s.order_id
WHERE s.order_status IN ('completed', 'refunded')
  AND p.email_domain <> 'twinhearth.test';

CREATE INDEX ix_stg_order_priced ON stg_order_priced(order_id);
