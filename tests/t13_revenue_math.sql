-- revenue measures must follow the Finance net revenue formula

SELECT
    order_id,
    gross_usd,
    refund_usd,
    platform_fee_usd,
    net_usd
FROM fact_order
WHERE ABS(
        gross_usd
        - (gross_local * rate_to_usd)
      ) > 0.000000001

   OR ABS(
        refund_usd
        - (refund_local * rate_to_usd)
      ) > 0.000000001

   OR ABS(
        platform_fee_usd
        - (
            (gross_local - refund_local)
            * rate_to_usd
            * fee_pct
          )
      ) > 0.000000001

   OR ABS(
        net_usd
        - (
            (gross_local - refund_local)
            * rate_to_usd
            * (1.0 - fee_pct)
          )
      ) > 0.000000001

   OR ABS(
        net_usd
        - (
            gross_usd
            - refund_usd
            - platform_fee_usd
          )
      ) > 0.000000001;