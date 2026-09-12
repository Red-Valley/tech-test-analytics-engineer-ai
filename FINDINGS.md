# FINDINGS — FY2026 Q2 net revenue

## Defects found

Impact is the isolated marginal effect of fixing **only that one variable**, holding every other
defect at its original broken state, measured on FY2026 Q2 (2026-01-01 → 2026-03-31). Percentages
are relative to the pipeline's original baseline number, **$727,922.09**. These deltas are
directional evidence, not additive — several of the bugs amplify each other (see "Deviation"
below), so they do not sum to the total correction.

| What was wrong | How I found it | Impact (USD, %) | Fix |
|---|---|---|---|
| **`04_fact_order.sql` joined `order_items` without aggregating**, so every order's revenue was repeated once per line item (1–3+ items/order) | Row-count check: `fact_order` had 174,089 rows vs. 111,975 orders in `raw_orders`. A concrete example (`ORD-0000001`) showed the same order twice with identical dollar amounts. Rebuilt the fact at order grain, everything else left broken, and diffed `SUM(net_usd)` for Q2 | **$445,484.11 / 61.20%** (overstated) | Grain of `fact_order` = 1 row per order. Item-level detail moved to a separate `fact_order_item` bridge that never multiplies dollar measures |
| **`raw_orders` has 2,957 duplicate `order_id`s**, all dated 2026-03-16→31 — the March loader-outage re-extract (`docs/HANDOVER.md`) re-landed them a second time | `GROUP BY order_id HAVING COUNT(*) > 1` on `raw_orders` (5,914 total rows affected); date range of the duplicates matches the handover note exactly | **$180,688.63 / 24.82%** (overstated, measured with fan-out still present — see note on non-additivity) | Keep the most-recently-ingested row per `order_id` in `stg_order` (`ingested_at = MAX(ingested_at)` per order), unique index enforces it |
| **FX conversion joined on exact `rate_date = order_date`**, but `fx_rates.csv` has no Saturday/Sunday row for *any* currency, including USD | Cross-tab of NULL `rate_to_usd` rows by day-of-week: 100% of nulls fell on `strftime('%w') IN ('0','6')` (18,420 + 18,801 = 37,221 rows, matching `bin/test.py`'s original failure count exactly). In Q2 alone, revenue silently disappeared from every `SUM()` for weekend orders | **$360,290.97 / 49.49%** (**understated** — the fix recovers revenue) | FX join replaced with an as-of lookup: last `rate_date <= order_date`, per currency |
| **Platform fee picked the fee schedule row with the latest `effective_from`, globally**, ignoring the order's own date | `platform_fees.csv` has STEAM (30%→25%, cutover 2026-01-01) and XBOX (30%→12%, cutover 2026-04-01). Verified every XBOX order in the data was charged a flat 12% (`SELECT DISTINCT fee_pct ... WHERE platform_code='XBOX'` returned a single value) regardless of order date — the XBOX cutover is *after* Q2, so every XBOX order in Q2 should have been charged 30% | **$33,126.17 / 4.55%** (overstated) | Fee lookup filtered to `effective_from <= order_date AND (effective_to IS NULL OR effective_to = '' OR effective_to >= order_date)` |
| **`refunds.csv` (the system of record for refunds) was never joined.** The fact only zeroed revenue when `order_status = 'refunded'` | Cross-referenced `raw_refunds` against `order_status`: `refunded` orders are always ~100%-of-gross refunds (already correctly zeroed by the flag, coincidentally), but **4,952 orders stay `completed`** with a **partial** refund (`partial_goodwill`/`price_adjustment`, ~35.8% of gross on average) that was never subtracted | **$15,295.81 / 2.10%** (overstated) | `refund_usd` = actual `SUM(refund_amount_local)` from `raw_refunds` converted to USD; `net_usd = (gross - refund) * (1 - fee)`, no dependency on `order_status` |
| **No scope filter**: `order_status = 'pending'` (never completed) and `email_domain = 'twinhearth.test'` (10 internal/QA accounts with anomalously large orders) were both included as ordinary revenue | Counted `pending` rows (1,602 in the fact); found the `twinhearth.test` domain isolated among 5 real domains in `raw_players` (10 accounts vs. ~9,000 each for the rest) | **$132,513.68 / 18.20%** combined ($8,248.81 / 1.13% pending + $124,264.87 / 17.07% test accounts) | `stg_order` excludes `order_status = 'pending'` and joins `dim_player.is_internal_test = 0` |
| **`dim_date.fiscal_quarter_no`/`fiscal_month_no` used `(month - 10) % 12`**, which is negative for Jan-Sep under SQLite's modulo semantics, so Q2 never evaluated to `2` | Queried `dim_date` directly: FY2026 only had `fiscal_quarter_no = 1` (Oct-Dec) correct; Jan-Mar produced `-2` | Categorical, not additive to the $ waterfall — **any report filtering `fiscal_quarter_no = 2` returned 0 rows / $0**, a silent 100% loss, not a partial skew | Rewrote as `(month + 2) % 12` (never negative), verified FY2026 Q2 now maps exactly to 2026-01-01→2026-03-31 |

## FY2026 Q2 net revenue

**Total: $318,550.72** (gross $449,851.40, refunds $19,899.87), 16,188 in-scope orders.

| Title | Net revenue (USD) | Orders |
|---|---:|---:|
| Hollow Crown | $143,903.20 | 5,466 |
| Emberwatch Tactics | $56,557.00 | 2,444 |
| Hollow Crown: Ashen Tide | $46,743.25 | 3,056 |
| Saltmarsh Rally | $44,306.21 | 2,662 |
| Lantern & Lock | $27,041.07 | 2,560 |
| **Total** | **$318,550.72** | **16,188** |

## Deviation of the delivered pipeline

The delivered pipeline, run as-is over the same date range, reports **$727,922.09** — no reporting
model exists in `models/`, so this is the number a naive `SUM(net_usd)` produces today (nulls
silently ignored by `SUM`, as they would be by anyone running this without knowing better).

**The delivered pipeline overstated FY2026 Q2 net revenue by $409,371.37 — +128.5% over the correct
number.** Two overstating defects (item fan-out and March duplicates) compound multiplicatively —
each duplicated order was *also* multiplied by its item count — so the pipeline reported more than
double what Finance should have seen, even though one defect (the weekend FX gap) was pulling the
number the other way by dropping real revenue entirely.

This also explains, directionally, why Finance's own spreadsheet disagreed: it isn't one clean
bug with one clean sign, it's four overstating defects and one understating defect stacked on top
of each other, landing on net overstatement.

## A defect smaller than expected

The platform-fee timing bug. Two platforms had a rate change scheduled close to Q2 (STEAM
2026-01-01, XBOX 2026-04-01), which looked like it would be a major distortion. In practice it
moved only 4.55% of Q2 revenue, because: STEAM's rate change lands exactly on the Q2 start date,
so "most recent globally" and "in force on the order date" agree for nearly all of STEAM's Q2
orders; only XBOX (a smaller share of volume) carries a mismatch, and only in one direction
(undercharging the fee, so *overstating* net revenue). Proof: isolating this fix alone moved Q2
net revenue from $727,922.09 to $694,795.92 — a $33,126.17 swing, an order of magnitude smaller
than the two grain defects.

My first attempt at measuring this actually showed an ~82% collapse, which was my own bug: I
filtered the fee schedule assuming an open-ended row (no end date) meant `effective_to IS NULL`.
`SELECT typeof(effective_to) FROM raw_platform_fees` showed it's actually an empty string (`''`),
not SQL `NULL` — so the filter matched nothing for EPIC/NSW/PSN and the still-open STEAM/XBOX rows,
and every one of those orders lost its fee entirely. Fixing the filter to
`effective_to IS NULL OR effective_to = ''` brought the isolated impact down to the real figure.

## What I did not fix, and why

- **`settlement_date` is a fixed `order_date + 30 days` for every store.** REVENUE_POLICY.md says
  settlement varies 30-60 days by store, but there is no per-store settlement-day reference
  anywhere in `data/`. Guessing a number per store would be inventing a business rule, not fixing
  one, and settlement is explicitly a *cash* concept, not a *revenue* one — it has zero effect on
  the FY2026 Q2 net revenue number this assessment is graded on.
- **`dim_platform` remains a stub** (`platform_code` only, no display name/region). It was flagged
  as unfinished in `docs/HANDOVER.md`. It doesn't affect revenue correctness or grain — purely
  cosmetic completeness — and wasn't worth the time against the defects above.
- **No incremental load / real orchestration was built.** Target design for 50x volume landing
  hourly: idempotent upsert by `order_id` (not `DROP TABLE`/full rebuild), partitioning by
  `order_date` so a partial-month backfill (like the March outage recovery) doesn't require
  reprocessing all history, and a dedupe safety net kept even with upsert, because the source has
  already demonstrated it can re-deliver rows. DuckDB would be my recommendation for that future
  scale (columnar, native Parquet/CSV, still runs embedded with no server) — not switched here
  because it doesn't change today's number and the one-command SQLite path is what a reviewer with
  no installs can run immediately. Building actual orchestration is explicitly out of scope per the
  README ("Orchestration and scheduling ... don't build it").

## Reproducibility

One command from a clean checkout:

```
python3 bin/build.py && python3 bin/test.py
```

(On Windows, if `python3` isn't aliased, use `python`.) `bin/build.py` loads `data/` and runs
`models/*.sql` in order; `bin/test.py` runs all 14 checks in `tests/` (7 original + 7 new) against
the resulting `build/warehouse.db`. Both exit 0.

**Windows-checkout note:** if `bin/test.py` reports `data/` checksum mismatches on a fresh Windows
clone, that's `core.autocrlf` rewriting the CSVs to CRLF at checkout time, not a real edit — this
repo ships a `.gitattributes` (`data/*.csv -text`) that prevents it. If it still shows mismatches
because your working tree already has CRLF versions checked out, force a rewrite with:
`del data\*.csv` then `git checkout HEAD -- data` (deleting first is necessary — `git checkout`
alone won't rewrite a file it already considers unmodified, even after the attribute changes).
