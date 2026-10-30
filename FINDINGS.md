# Revenue pipeline findings

## FY2026 Q2 answer

FY2026 Q2 is **2026-01-01 through 2026-03-31**. Net revenue is recognized on the
order date. The repaired fact contains one row per order and reports:

| Title | FY2026 Q2 net revenue (USD) |
|---|---:|
| Hollow Crown | $148,523.10 |
| Hollow Crown: Ashen Tide | $48,305.08 |
| Lantern & Lock | $27,928.18 |
| Saltmarsh Rally | $45,772.57 |
| Emberwatch Tactics | $58,169.01 |
| **Total** | **$328,697.94** |

The total is `SUM(fact_order.net_usd)` for dates whose `dim_date` values are
FY2026 fiscal quarter 2. Net per eligible order is
`(gross_local - refunds_local) * rate_to_usd * (1 - fee_pct)`. Refunds are
aggregated by order from `raw_refunds`; the order date determines the reporting
period.

The delivered pipeline reported **$727,922.08**, overstating the corrected result
by **$399,224.14 (121.46% of corrected revenue)**. I reproduced the delivered
logic against the unchanged raw files: exact-date FX, the latest fee row regardless
of its effective dates, status-based refunds, all statuses and players, duplicate
order ingestions, and an inner join to every item line.

### Defects and Q2 value

Each impact below is a one-defect-at-a-time counterfactual: start with the repaired
result, reintroduce only the named behavior, and compare its Q2 total with
$328,697.94. Positive values overstate revenue; negative values understate it.
These impacts are **not additive** because defects interact. The delivered-pipeline
variance above is the full-baseline comparison.

| What was wrong | How it was found | What it was worth (FY2026 Q2, USD and %) | Fix |
|---|---|---:|---|
| Joining each order to its item lines copied full order measures onto every line. | The original fact had repeated `order_id` values; the grain test found 43,680 orders repeated in the delivered fact. | **+$350,690.54 (+106.69%)** | Keep the revenue fact at one row per order. Do not expose item-level revenue until an allocation rule is defined. |
| Reingested source orders were not deduplicated. | 2,957 order IDs appeared more than once in `raw_orders`; repeated copies had the same order data and a later `ingested_at`. | **+$59,171.01 (+18.00%)** | Stage the latest ingested copy per order and test that staging retains it. |
| Pending orders were included in revenue. | The original fact contained 1,602 pending orders after source deduplication. | **+$5,017.54 (+1.53%)** | Include only `completed` and `refunded` orders in the revenue fact. |
| Test accounts were included. | Ten source players use the `twinhearth.test` domain; their eligible Q2 orders contributed to the fact. | **+$24,313.07 (+7.40%)** | Preserve all players in `dim_player`, flag the known test domain, and filter flagged players from the revenue fact. |
| FX required an exact same-day match, and USD was converted using a published USD rate instead of 1. | 39,001 original staged orders had no exact-date rate; available earlier rates were ignored. Published USD rates also differ from 1. | **-$127,799.66 (-38.88%)** | Use 1 for USD; for other currencies use the latest rate on or before `order_date`. |
| The platform fee was the latest schedule row, not the rate effective on the order date. | The original lookup ignored `effective_from` and `effective_to`; for example, it applied XBOX's later 12% fee to Q2 orders when 30% was in force. | **+$14,587.18 (+4.44%)** | Match the platform and order date to the effective fee interval. |
| Refunds were inferred from order status rather than read from the refunds system of record. | 759 real-player Q2 completed orders had refund records; those partial refunds did not reduce the delivered measure. | **+$5,974.97 (+1.82%)** | Aggregate `raw_refunds` by order and calculate the platform fee and net revenue on the post-refund amount. |
| The fiscal-month expression produced incorrect month numbers for part of the year. | Checked the fiscal month mapping against the October-start calendar. | **$0.00 (0.00%)** | Use a positive modulo expression and test all FY2026 month and quarter assignments. The fiscal-quarter field used for this Q2 total was already correct. |
| A fixed 30-day settlement date implied a payment date unsupported by the data. | No payout or store settlement schedule is present in the landing files; the policy says delays vary by store. | **$0.00 (0.00%)** | Remove the fabricated settlement date from the revenue fact. Model cash separately when payout data is available. |

### A smaller-than-expected defect

The status-based refund defect changes Q2 net revenue by only **$5,974.97
(1.82%)** in the one-at-a-time comparison. That is smaller than the raw refund
volume might suggest: all 462 Q2 orders marked `refunded` have refunds equal to
their gross, so the old logic's zero net happens to agree for those orders. The
material mismatch is the 759 completed orders with refund records, whose partial
refunds the old logic ignored.

### Scope and trade-offs

- The source identifies test accounts by `email_domain = 'twinhearth.test'`; that
  is the only explicit internal/test identifier in the provided player data. The
  model excludes that known group, but cannot prove that every staff or QA account
  is identified without a more authoritative source attribute.
- There are no store payout dates, settlement transactions, or per-store payout
  delays in the supplied files. I did not invent cash dates or build cash reporting.
- The pipeline remains a full SQLite rebuild to preserve the assessment's
  no-install, one-command reproducibility. For hourly delivery at substantially
  higher volume, I would persist ingestion watermarks, incrementally merge
  deduplicated orders and refund changes, and partition/cluster by order date and
  platform in a production warehouse. I would also monitor late-arriving refunds
  and reconcile payouts to a separate cash fact.
- Item-level revenue allocation remains undefined, so the fact does not claim an
  item-type revenue breakdown.

`python bin/run.py` rebuilds the warehouse and runs the SQL assertions, including
a regression check for the title totals above. Landing files were not edited.
