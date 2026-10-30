-- staging keeps one source version per order and uses its latest ingestion
SELECT s.order_id, s.ingested_at
FROM stg_order s
WHERE s.ingested_at != (
          SELECT MAX(r.ingested_at)
          FROM raw_orders r
          WHERE r.order_id = s.order_id
      )
   OR NOT EXISTS (
          SELECT 1
          FROM raw_orders r
          WHERE r.order_id = s.order_id
            AND r.ingested_at = s.ingested_at
            AND r.player_id = s.player_id
            AND r.title_id = s.title_id
            AND r.platform_code = s.platform_code
            AND substr(r.order_ts, 1, 10) = s.order_date
            AND r.currency_code = s.currency_code
            AND CAST(r.gross_amount_local AS REAL) = s.gross_local
            AND r.order_status = s.order_status
      );
