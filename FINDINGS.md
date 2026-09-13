# Revenue pipeline findings

## FY2026 Q2 net revenue

| Title | Net revenue (USD) |
| --- | ---: |
| Hollow Crown | 143,903.20 |
| Hollow Crown: Ashen Tide | 46,743.25 |
| Lantern & Lock | 27,041.07 |
| Saltmarsh Rally | 44,306.21 |
| Emberwatch Tactics | 56,557.00 |
| **Total** | **318,550.72** |

Each title is rounded for display; the total is rounded from the unrounded order-level total.

The delivered model reports **$727,922.09**, an overstatement of **$409,371.37 (128.5%)**.

## Defects

The impact figures isolate each issue against the repaired, order-grain calculation where possible. They overlap and must not be summed.

| Defect | How found | FY2026 Q2 impact | Fix |
| --- | --- | ---: | --- |
| March re-extract duplicated 2,957 order IDs | Compared `COUNT(*)` to `COUNT(DISTINCT order_id)` by order month; only March differs. | +$57,768.94 (+18.1%) | Keep the latest landed record per `order_id` in `stg_order`. |
| Fact was joined to order items | 43,680 orders have multiple item rows; monetary fields were repeated once per line. | +$340,462.82 (+106.9%) | Keep `fact_order` at one row per order. Build a separately allocated line-level fact only if item reporting is required. |
| FX joined only the exact calendar date | 39,001 source orders have no exact FX row; rates are published on business days. | -$66,861.49 (-21.0%) when omitted | Select the last rate on or before `order_date`. |
| Fee lookup selected the latest contract rate | The original scalar lookup lacked order-date bounds, despite schedules changing for Steam and Xbox. | -$14,147.82 (-4.4%) in the repaired population | Filter fee schedules to the row effective on `order_date`. |
| Refund status was treated as the refund ledger | There are 7,693 refund records, including partial goodwill credits; a partially refunded completed order was not handled correctly. | +$5,797.27 (+1.8%) if refund records are ignored | Aggregate `raw_refunds` by order and apply it to the original order date. |
| Test accounts entered revenue | `twinhearth.test` has 100 distinct Q2 order IDs after deduplication. | +$23,567.25 (+7.4%) | Exclude that internal/test domain before the revenue fact. |
| Fiscal Q2 was calculated incorrectly | SQLite negative modulo made January--March fiscal quarters negative instead of Q2. | Reporting period unavailable | Derive fiscal month with a positive month shift. |
| Settlement date was hard-coded to 30 days | Compared the model to the policy, which specifies a store-specific 30--60 day delay; no settlement schedule is supplied. | $0.00 revenue impact | Remove the fabricated field. A cash-reporting model needs a supplied settlement schedule. |

## Method

The delivered-pipeline benchmark was calculated from the original `fact_order` output, filtered to `2026-01-01 <= order_date < 2026-04-01`, before applying any repair. The repaired report uses the latest record for each order ID, excludes pending and `twinhearth.test` accounts, aggregates refunds by order, applies the last available FX rate on or before the order date, and applies the fee contract active on that date. Net revenue is `(gross - refunds) * FX * (1 - platform fee)`.

The refund-ledger defect was smaller than expected at $5,797.27. I expected partial refunds to be more material because there are 7,693 refund records. I validated the smaller impact by comparing the corrected aggregated refund amount with the status-driven calculation order by order; it is far below the $340,462.82 item fanout but still substantial enough to protect with a test.

## Scope deliberately left out

I did not build incremental ingestion, orchestration, CI, dashboards, a line-item allocation model, or a cash-settlement model. The last requires a store-specific settlement schedule that is not provided. The brief timebox prioritizes a reproducible financial number, evidence-backed defects, and assertions. For production, I would add a watermark-based incremental raw load, snapshots of effective-dated reference data, uniqueness constraints, a separately allocated order-item fact when item-type reporting is needed, and a cash fact once settlement terms are available.
