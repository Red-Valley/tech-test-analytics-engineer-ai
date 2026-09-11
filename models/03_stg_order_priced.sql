-- Enrich each canonical order with the Finance-approved pricing inputs:
--
-- 1. USD orders require no currency conversion: rate_to_usd = 1.
-- 2. Non-USD orders use the last published FX rate on or before order_date.
-- 3. Platform fees use the contract rate effective on order_date.
-- 4. Refunds come from raw_refunds, the Finance system of record.
--
-- Grain remains exactly one row per order_id.

DROP TABLE IF EXISTS stg_order_priced;

CREATE TABLE stg_order_priced AS
WITH refunds AS (
    SELECT
        order_id,
        SUM(CAST(refund_amount_local AS REAL)) AS refund_local
    FROM raw_refunds
    GROUP BY order_id
)

SELECT
    s.order_id,
    s.player_id,
    s.title_id,
    s.platform_code,
    s.order_date,
    s.order_ts,
    s.currency_code,
    s.gross_local,
    s.order_status,
    s.ingested_at,

    COALESCE(r.refund_local, 0.0) AS refund_local,

    CASE
        WHEN s.currency_code = 'USD' THEN 1.0
        ELSE (
            SELECT CAST(fx.rate_to_usd AS REAL)
            FROM raw_fx_rates fx
            WHERE fx.currency_code = s.currency_code
              AND fx.rate_date <= s.order_date
            ORDER BY fx.rate_date DESC
            LIMIT 1
        )
    END AS rate_to_usd,

    CASE
        WHEN s.currency_code = 'USD' THEN NULL
        ELSE (
            SELECT fx.rate_date
            FROM raw_fx_rates fx
            WHERE fx.currency_code = s.currency_code
              AND fx.rate_date <= s.order_date
            ORDER BY fx.rate_date DESC
            LIMIT 1
        )
    END AS fx_rate_date,

    (
        SELECT CAST(pf.fee_pct AS REAL)
        FROM raw_platform_fees pf
        WHERE pf.platform_code = s.platform_code
          AND pf.effective_from <= s.order_date
          AND (
              pf.effective_to IS NULL
              OR pf.effective_to = ''
              OR pf.effective_to >= s.order_date
          )
        ORDER BY pf.effective_from DESC
        LIMIT 1
    ) AS fee_pct

FROM stg_order s

LEFT JOIN refunds r
  ON r.order_id = s.order_id;


CREATE UNIQUE INDEX ix_stg_order_priced
    ON stg_order_priced(order_id);

CREATE INDEX ix_stg_order_priced_date
    ON stg_order_priced(order_date);