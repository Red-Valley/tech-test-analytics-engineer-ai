# Findings

## Executive result

Twin Hearth Studios' **FY2026 Q2 net revenue is $328,697.94**.

The delivered warehouse reported **$727,922.09** for the same January 1–March 31, 2026 period. It therefore overstated Finance-defined net revenue by:

* **$399,224.15**
* **121.46% of the correct revenue**

I calculated the final result independently from the raw landing tables using the rules in `docs/REVENUE_POLICY.md`, then rebuilt the warehouse models and verified that the repaired pipeline reproduced the same result.

## FY2026 Q2 net revenue

| Title                    | Eligible orders |     Net revenue |
| ------------------------ | --------------: | --------------: |
| Hollow Crown             |           5,466 |     $148,523.10 |
| Hollow Crown: Ashen Tide |           3,056 |      $48,305.08 |
| Lantern & Lock           |           2,560 |      $27,928.18 |
| Saltmarsh Rally          |           2,662 |      $45,772.57 |
| Emberwatch Tactics       |           2,444 |      $58,169.01 |
| **Total**                |      **16,188** | **$328,697.94** |

The final Finance calculation reconciles as:

| Component                   |       FY2026 Q2 |
| --------------------------- | --------------: |
| Gross revenue               |     $464,235.20 |
| Refunds                     |    ($20,585.55) |
| Platform fees after refunds |   ($114,951.71) |
| **Net revenue**             | **$328,697.94** |

Formula:

```text
net revenue = (gross - refunds) × FX × (1 - platform fee rate)
```

*Revenue is recognized on the original order date. Revenue formulas were changed due to FX changes but will mantain the same for USD transactions since FX for USD was set to 1.0.

---

## Defects found

The impact figures below are **standalone counterfactuals against the original $727,922.09 delivered result**: I corrected only the named defect and deliberately left the other defects unchanged.

Because several defects affect the same orders, these standalone impacts overlap and **must not be added together**. A separate sequential reconciliation is provided below.

| What was wrong                                             | How I found it                                                                                                                                                                                                                                                               |                                                                                 FY2026 Q2 impact vs delivered result | Fix                                                                                                                                           |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **March source extract was replayed**                      | Q2 contained 19,480 physical `raw_orders` rows but only 16,523 order IDs. Exactly 2,957 March order IDs appeared twice, with identical business fields and different ingestion timestamps. The same replay duplicated 4,392 unique order-item rows into 8,784 physical rows. |                                                                              **+$271,032.94 overstatement (37.23%)** | Canonicalize `raw_orders` to one row per `order_id`, retaining the latest landed version before downstream modeling.                          |
| **Order-level revenue was multiplied by order-item grain** | The original Q2 fact contained 37,620 rows for only 16,523 distinct orders. `fact_order` joined whole-order gross amounts to every `raw_order_items` row, repeating the same money for legitimate multi-item purchases.                                                      |                                                                              **+$445,484.11 overstatement (61.20%)** | Define the revenue fact at one row per business order. Keep item-level detail separate instead of repeating whole-order revenue across items. |
| **Non-USD FX required an exact-date match**                | 6,045 Q2 orders had no exact-date FX rate. Every missing rate occurred on Saturday or Sunday, and all 6,045 had a valid previously published rate.                                                                                                                           |                                                                             **−$212,586.04 understatement (29.20%)** | For non-USD orders, select the latest published rate where `rate_date <= order_date`.                                                         |
| **USD orders were unnecessarily FX-converted**             | The model applied `rate_to_usd` to all currencies. The supplied USD series varied from 0.897238 to 1.031291 even though Finance specifies conversion for **non-USD** orders.                                                                                                 |                                                                             **−$178,852.51 understatement (24.57%)** | Use `rate_to_usd = 1.0` for USD orders.                                                                                                       |
| **Historical platform fees used the latest contract rate** | XBOX's Q2 contractual fee was 30% through March 31, 2026, but the model selected its later 12% rate effective April 1 for historical orders. Other Q2 platforms matched their current rates.                                                                                 |                                                                                **+$33,126.17 overstatement (4.55%)** | Select the platform fee whose effective date range contains the order date.                                                                   |
| **Partial refunds were ignored**                           | Finance identifies `raw_refunds` as the system of record. Q2 contained 1,231 refunded orders: 465 full refunds and **766 partial refunds**. The partial-refund orders retained `order_status='completed'`, so status-based logic ignored them.                               |                                                                                **+$15,295.81 overstatement (2.10%)** | Aggregate refunds by `order_id` and calculate net revenue from `(gross - refunds)` rather than relying on order status.                       |
| **Pending orders were recognized as revenue**              | The delivered Q2 fact included 235 distinct pending orders and recognized $8,248.81 from the non-NULL subset. Finance explicitly excludes orders that never completed.                                                                                                       |                                                                                 **+$8,248.81 overstatement (1.13%)** | Restrict the revenue fact to completed/refunded orders.                                                                                       |
| **Internal/test accounts were included**                   | Only 10 of 45,000 players use the explicit `twinhearth.test` domain. Those accounts generated 100 distinct Q2 orders and were present in the delivered revenue fact despite Finance explicitly excluding internal/test/QA activity.                                          |                                                                              **+$124,264.88 overstatement (17.07%)** | Exclude players with the internal/test domain from reported metrics.                                                                          |
| **Fiscal quarter arithmetic was invalid for Jan–Sep**      | The original modulo expression generated fiscal quarter values `-2`, `-1`, `0`, and `1`. Querying `FY2026` + `Q2` therefore returned zero rows even though Jan–Mar revenue existed.                                                                                          | **$727,922.09 / 100% reporting understatement** when the delivered pipeline was queried through its fiscal dimension | Replace negative-modulo arithmetic with explicit Oct–Dec/Q1, Jan–Mar/Q2, Apr–Jun/Q3, Jul–Sep/Q4 mappings.                                     |

The fiscal-calendar defect is a reporting/classification defect rather than an additional order-level revenue adjustment, so it is not included in the monetary reconciliation below.

---

## Sequential reconciliation

To prove the final difference, I also applied the corrections sequentially. Unlike the standalone impacts above, these adjustments are additive.

| Stage                          |         Revenue |        Change |
| ------------------------------ | --------------: | ------------: |
| Delivered logic reproduced     |     $727,922.09 |             — |
| Remove March replay            |     $456,889.14 | ($271,032.95) |
| Correct revenue grain          |     $236,197.35 | ($220,691.79) |
| Use as-of FX for non-USD       |     $312,685.01 |   +$76,487.66 |
| Stop converting USD            |     $381,035.10 |   +$68,350.09 |
| Apply historical platform fees |     $364,683.41 |  ($16,351.69) |
| Use refunds system of record   |     $358,028.55 |   ($6,654.86) |
| Exclude pending orders         |     $353,011.01 |   ($5,017.54) |
| Exclude internal/test accounts | **$328,697.94** |  ($24,313.07) |

Total sequential change:

```text
$328,697.94 - $727,922.09 = -$399,224.15
```

The reconciliation balances exactly.

---

## Method used to establish the correct number

I treated `docs/REVENUE_POLICY.md` as the specification rather than treating the existing models or green tests as authoritative.

The independent reference calculation:

1. Selected orders dated January 1 through March 31, 2026.
2. Canonicalized replayed extracts to one row per `order_id`.
3. Kept only completed/refunded business orders.
4. Excluded `twinhearth.test` internal/test accounts.
5. Used `raw_refunds` as the refund system of record.
6. Assigned USD orders an FX rate of 1.
7. Used the last published rate on or before the order date for non-USD currencies.
8. Selected the platform fee effective on the order date.
9. Calculated `(gross - refunds) × FX × (1 - fee_pct)`.
10. Aggregated from one row per order to title and total.

Before accepting the result I checked:

```text
duplicate eligible order IDs = 0
missing FX rates             = 0
missing platform fee rates   = 0
refund amounts > gross       = 0
```

The repaired warehouse independently reproduces the same **$328,697.94** result.

---

## A defect whose impact was smaller than expected

I expected the inclusion of pending orders to be more material because the original fact explicitly contained them and the supplied test already identified the defect.

After quantification, however, pending orders accounted for only **$8,248.81**, or **1.13% of the delivered Q2 result**. It was still a clear Finance-policy violation and therefore needed correction, but it was much less important financially than the replay, fact-grain, FX, or internal-account defects.

This was useful for prioritization: visible test failures were not necessarily the largest sources of financial error.

---

## Data model and scaling decisions

### Logical model

The repaired warehouse uses an explicit order-level revenue grain:

| Model                 | Grain                                | Purpose                                                                  |
| --------------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| `raw_*`               | source landing grain                 | Immutable source evidence                                                |
| `dim_date`            | one row per calendar date            | Calendar and fiscal reporting                                            |
| `dim_player`          | one row per player                   | Player attributes used for reporting and eligibility                     |
| `dim_title`           | one row per title                    | Title reporting attributes                                               |
| `dim_platform`        | one row per platform                 | Platform dimension                                                       |
| `dim_studio`          | one row per studio                   | Studio reporting attributes                                              |
| `bridge_title_studio` | one title/studio/credit relationship | Supports the many-to-many title/studio relationship                      |
| `stg_order`           | one row per `order_id`               | Canonical order after handling replayed landings                         |
| `stg_order_priced`    | one row per `order_id`               | Order enriched with refunds, FX, and historically effective platform fee |
| `fact_order`          | one eligible business order          | Finance revenue fact                                                     |

The most important modeling decision is that `fact_order` remains at **order grain**.

`raw_order_items` is intentionally not joined directly into the revenue fact because gross revenue, refunds, FX, and platform fees are defined at order level. Repeating those measures across item rows would multiply revenue. If item-level revenue reporting becomes a requirement, I would build a separate item fact and introduce an explicit Finance-approved allocation rule rather than implicitly duplicating order-level money.

### Why the assessment implementation uses a full rebuild

The supplied harness is small, local, and SQLite-based. For the assessment I kept that architecture because it provides:

* deterministic clean-checkout reproduction;
* no external services or dependencies;
* a simple way for the reviewer to reproduce the complete result with one command;
* an easy way to prove all transformations from immutable landing data.

For this dataset, the full rebuild is appropriate.

I would **not** use the same physical execution pattern once the data is approximately 50× larger and arrives hourly.

### Production execution at 50× volume

The logical model above would remain the same, but the physical execution would become incremental.

#### 1. Raw ingestion would remain append-only

Hourly source batches would be landed without mutating prior records.

Each batch would preserve metadata such as:

```text
source ingestion timestamp
batch/run identifier
source filename or object
business key
```

The raw layer would remain the audit trail and would not be deduplicated in place.

This is important because the supplied data already demonstrates why replay-safe ingestion matters: the March extract was loaded twice.

#### 2. Canonical orders would be incrementally merged

Instead of rebuilding `stg_order` from the entire order history every hour, each run would identify only new or changed `order_id` values since the previous successful watermark.

For those keys:

```text
new raw order versions
        ↓
rank by ingested_at
        ↓
select canonical version
        ↓
MERGE / UPSERT into canonical order table
```

The operation would be idempotent: replaying the same batch would not create another business order.

The canonical business key remains:

```text
order_id
```

#### 3. Refunds must also trigger historical-order updates

Incrementality cannot be based only on newly arrived orders.

A refund can arrive after the original order, while Finance recognizes the adjustment against the original order date. Therefore each hourly run would construct a set of **affected order IDs** from both:

```text
new/changed orders
UNION
new/changed refunds
```

Only those orders would need to be repriced and merged into `fact_order`.

This allows a refund received today to correctly update revenue for an order originally recognized in a prior fiscal period without rebuilding every historical order.

#### 4. FX and platform fees would be effective-dated lookup dimensions

The production model would preserve the same semantics used in this submission:

```text
FX:
last published rate where rate_date <= order_date

platform fee:
effective_from <= order_date <= effective_to
```

At larger scale I would materialize and index these lookup structures rather than repeatedly scanning their raw landing tables.

Natural access paths would include:

```text
FX:            (currency_code, rate_date)
platform fee:  (platform_code, effective_from, effective_to)
```

Because these tables are small relative to orders, they could also be materialized into date-effective lookup tables where appropriate.

#### 5. The revenue fact would be incrementally upserted

`fact_order` would continue to enforce:

```text
one row per order_id
```

Changed eligible orders would be inserted or updated. Orders that become ineligible because of corrected source data would be removed or soft-invalidated according to the warehouse's audit strategy.

For an analytical warehouse supporting large scans, I would partition the fact by `order_date` and cluster/index around common access patterns such as:

```text
order_date
title_id
platform_code
player_id
```

The exact physical implementation would depend on the target warehouse.

#### 6. Dimensions would be maintained independently

The supplied attributes are sufficient for Type 1 dimensions in this assessment.

In production I would explicitly decide attribute history requirements with the reporting team:

* title/studio/platform descriptive corrections could use Type 1 where historical values do not need preservation;
* player attributes would use Type 2 only if Finance or Analytics needs reporting based on the attribute value that was true at order time;
* internal/test eligibility should ideally be supplied as an authoritative player/account attribute instead of inferred permanently from an email domain.

The fiscal date dimension is deterministic and would be generated ahead of the reporting horizon rather than rebuilt every hour.

#### 7. Hourly orchestration

An hourly production run would conceptually be:

```text
land source batch
      ↓
validate batch / preserve raw rows
      ↓
identify affected order_ids
      ↓
merge canonical orders
      ↓
aggregate changed refunds
      ↓
apply effective-dated FX + fee rules
      ↓
merge affected fact_order rows
      ↓
run data-quality / business-rule tests
      ↓
publish successful watermark
```

The watermark would advance only after a successful transaction/run so failed batches could be rerun safely.

### Data quality at larger scale

The tests added in this submission are intended to protect model invariants rather than a hardcoded revenue result.

They validate rules such as:

* one canonical order per `order_id`;
* one eligible order per revenue fact row;
* USD FX identity;
* non-USD as-of FX;
* historically effective platform fees;
* refund reconciliation to the system of record;
* Finance revenue arithmetic;
* correct fiscal calendar mapping.

In production these same checks would run in CI for model changes and as post-load data-quality checks for hourly batches.

I would additionally monitor operational metrics such as:

```text
raw rows received per batch
distinct business keys
duplicate/replay rate
orders inserted/updated
refund-driven historical updates
missing FX/fee lookups
rejected records
batch latency
```

### Technology trade-off

SQLite is appropriate for this assessment because the goal is a self-contained and reproducible investigation. It is not my proposed warehouse for sustained 50× hourly production volume.

On a production analytical platform I would use the warehouse's native incremental capabilities—such as `MERGE`, partitioning, clustering/indexing, orchestration, and transactional batch metadata—while retaining the **same logical grains and Finance rules demonstrated here**.

The important architectural decision is therefore not SQLite versus a specific cloud product; it is preserving:

```text
immutable raw evidence
→ replay-safe canonical order
→ effective-dated pricing
→ one-row-per-order Finance fact
```

as volume and ingestion frequency increase.


---

## What I did not fix

I deliberately did not build orchestration, scheduling, CI, dashboards, authentication, or infrastructure because the assessment explicitly marks them out of scope.

I also did not build an item-level revenue allocation model. `raw_order_items` contains useful product detail, but Finance defines the monetary transaction at order level and provides no allocation policy for splitting refunds, platform fees, or order-level revenue across individual items. Inventing an allocation method during a three-hour investigation would create unsupported business logic. The correct choice was to keep `fact_order` at order grain and treat item-level revenue attribution as a separate requirement requiring an agreed allocation rule.

I did not replace SQLite with dbt, DuckDB, Fabric, or another platform. The supplied stack was sufficient to prove the defects and reproduce the correct result with one command, so migration would have consumed assessment time without improving the answer.

---

## Reproduction

From a clean checkout:

```bash
python bin/run.py
```

This rebuilds the warehouse, executes the complete test suite, and prints FY2026 Q2 net revenue by title and total.

Expected final total:

```text
16,188 eligible orders
FY2026 Q2 net revenue = $328,697.94
```

## Test that would have got this

They are added inside the tests folder, these are:

|Test Name|Test Reason|
|------|------|
|t08_canonical_order_grain.sql|Staging must contain exactly one canonical row per source order_id|
|t09_fact_matches_finance_scope.sql|Fact_order must contain exactly the orders eligible under Finance scope|
|t10_fx_policy.sql|FX must be 1 for USD and last published rate on or before order date otherwise|
|t11_platform_fee_policy.sql|Platform fee must be the contract rate effective on the order date|
|t12_refunds_match_system_of_record.sql|Staged refunds must reconcile to the refunds system of record|
|t13_revenue_math.sql|Revenue measures must follow the Finance net revenue formula|
|t14_fiscal_calendar.sql|Fiscal calendar must follow an October-start fiscal year|