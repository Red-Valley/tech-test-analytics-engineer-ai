# FINDINGS

`data/` is checksum-verified and was never touched. Every number below comes from re-running
`python3 bin/build.py && python3 bin/test.py` on the models in this branch.

## Defects

Dollar impact isolates each fix's marginal effect on **FY2026 Q2 net revenue only**, applied
cumulatively in the order listed (grain → dedup → scope → FX → fee → refunds → QA). Because some
bugs interact (the item-level fan-out multiplies every other bug's effect too), the order changes
individual deltas somewhat; it does not change the total variance between the delivered pipeline
and the corrected one. % is against the corrected FY2026 Q2 total of **$328,697.94**.

| What was wrong | How I found it | Worth (FY2026 Q2, USD / %) | Fix |
|---|---|---|---|
| `fact_order` joined the order-level money columns to `raw_order_items` (line items), so an order's revenue was repeated once per line item instead of once. | `t01_fact_grain_not_multiplied` failed out of the box (43,680 offending rows) the moment I ran `bin/test.py`. | **-$445,484.11 (135.6%)** | Dropped the join to `raw_order_items` from the revenue fact; `fact_order` is now one row per order. Item-type breakdown isn't in the ask (by title + total) and doing it correctly would mean prorating fee/refunds across mixed-type baskets — a decision for Finance, not me, to make (see "what I did not fix"). |
| The March 2026 loader outage was fixed by re-running the extract for the rest of the month (`HANDOVER.md`). That re-run re-landed rows already landed: 2,957 `order_id`s appear twice in `raw_orders`, identical except `ingested_at` — all dated March, all inside FY2026 Q2. Nothing deduped it. | `t01` doesn't catch this — it compares fact-row-count to raw-row-count for the *same* `order_id`, and raw itself already has the duplicate. Found it by checking `GROUP BY order_id HAVING COUNT(*)>1` on `raw_orders` directly, then cross-checking dates against `HANDOVER.md`'s mention of the outage. | **-$46,240.63 (14.1%)** | `stg_order` now dedupes with `ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY ingested_at DESC)`, keeping the most-recently-ingested copy. New test: `t08`. |
| `fact_order` had no `order_status` filter at all — `pending` orders (never completed) were counted as revenue. | `t03_no_pending_orders` failed (1,602 offending rows). | **-$3,268.48 (1.0%)** | `fact_order` now filters `order_status IN ('completed','refunded')`. |
| FX conversion joined on `fx.rate_date = order_date` (exact match). Rates only publish on business days, so every weekend order in a non-USD currency got `NULL` for `rate_to_usd`, and `NULL` money silently drops out of any `SUM`. | `t05_measures_not_null` failed (60,240 rows, item-grain-inflated). Traced it to `fx_rates` having zero rows for `dow IN (0,6)` while ~35% of non-USD orders fall on those days. | **+$131,410.37 (40.0%)** | FX now resolves via "last published rate on or before the order date" (`rate_date <= order_date ORDER BY rate_date DESC LIMIT 1`), matching `REVENUE_POLICY.md` verbatim. |
| `raw_fx_rates` has a `currency_code='USD'` series too, and it isn't flat at 1.0 — it drifts from ~1.02 (late 2024) down to ~0.90 (late 2025) and back to ~0.93-0.95 through FY2026 Q2. The original join converted USD orders through this series anyway, since it only matched on `currency_code`. | Noticed `stg_order_priced.rate_to_usd` for USD rows wasn't uniformly `1.0`; pulled the monthly min/max/avg of that series and saw the drift. `REVENUE_POLICY.md` never asks for USD-to-USD conversion. | **+$11,545.01 (3.5%)** — see "smaller than expected" below | USD orders now force `rate_to_usd = 1.0` and skip the FX table entirely. New test: `t12`. |
| The fee lookup was `ORDER BY effective_from DESC LIMIT 1` with no date bound — every order got *today's* fee regardless of when it was placed. For FY2026 Q2 specifically this mispriced XBOX (12% instead of the correct 30% — the 12% rate doesn't start until 2026-04-01) and would have mispriced STEAM outside Q2. | Read `platform_fees.csv` next to `REVENUE_POLICY.md`'s "the rate in force on the date of the order... changes over time" and saw the subquery ignored `order_date` completely. | **-$16,218.38 (4.9%)** | Fee now resolves via `effective_from <= order_date AND (effective_to IS NULL OR effective_to = '' OR effective_to >= order_date)`. Gotcha along the way: `effective_to` loads as an empty string, not SQL `NULL` (every landing column is `TEXT`) — `IS NULL` alone silently drops every currently-open fee row. New test: `t10`. |
| Refunds were only recognised when `order_status = 'refunded'` (assumed = full refund, `net_usd` zeroed). Partial refunds (`partial_goodwill`, `price_adjustment`) on orders that stayed `'completed'` were never joined to `raw_refunds` at all — 4,829 such orders system-wide. | `REVENUE_POLICY.md`: "a partially refunded order is still a completed order" + "the refunds table is the system of record." Checked whether any `'completed'` orders had rows in `raw_refunds` — they did, thousands of them, contributing nothing to `refund_usd`. | **-$6,654.86 (2.0%)** | `fact_order` now `LEFT JOIN`s every order (not just `status='refunded'`) to a `SUM(refund_amount_local)` per `order_id`, nets it off gross before the fee, and re-derives the fee on the refund-net amount ("the platform refunds its fee along with them"). New test: `t11`. |
| No exclusion of internal/QA accounts. `raw_players.email_domain = 'twinhearth.test'` (10 players, `.test` is the RFC 2606 reserved testing TLD) were counted like real players. | `REVENUE_POLICY.md`: "Internal, test and QA accounts are excluded from every reported metric." Grouped `raw_players` by `email_domain` and one value stood out immediately. | **-$24,313.07 (7.4%)** | Added `dim_player.is_internal`, `fact_order` now excludes it. New test: `t09`. |

**Also fixed, no Q2 revenue impact:** `dim_date.fiscal_quarter_no`/`fiscal_month_no` used
`(month - 10) % 12`, and SQLite's `%` keeps the sign of the dividend — every calendar month Jan-Sep
(fiscal Q2-Q4) evaluated to a **negative** quarter number (e.g. January → `-2`). `fact_order` never
joined `dim_date`, so this didn't touch the number reported here, but any report or dashboard built
against `dim_date` — which is the whole point of having it — would have been broken the moment
someone filtered on `fiscal_quarter_no`. Replaced with a `CASE`-based fiscal-month calc that's
always positive by construction. New test: `t13`.

## FY2026 Q2 net revenue

| Title | Net revenue (USD) |
|---|---:|
| Hollow Crown | $148,523.10 |
| Emberwatch Tactics | $58,169.01 |
| Hollow Crown: Ashen Tide | $48,305.08 |
| Saltmarsh Rally | $45,772.57 |
| Lantern & Lock | $27,928.18 |
| **Total** | **$328,697.94** |

Reproducible with `python3 bin/build.py && python3 bin/report.py`. `report.py` runs the exact
query above (`dim_date.fiscal_year='FY2026' AND fiscal_quarter_no=2`); it agrees exactly with the
plain `order_date BETWEEN '2026-01-01' AND '2026-03-31'` filter, which is itself a check that the
`dim_date` fix is correct.

## How far off the delivered pipeline was

The pipeline as handed over reports **$727,922.09** for FY2026 Q2. The correct number is
**$328,697.94**. The delivered pipeline overstates net revenue by **$399,224.15 — 121.5% too
high**, i.e. it reports more than double the real figure. The single largest cause is the
item-level fan-out (worth more on its own than every other defect combined); the FX weekend-NULL
bug is the second largest and points the *other* direction, so the two partially offset each other
in the final delivered number — which is exactly the kind of thing that makes "the checks are
green" a dangerous signal on its own.

## Smaller than expected

The USD-through-a-drifting-"FX"-rate bug. On paper it looked like the scariest defect in the
list: it silently touches 46% of all orders (USD is the single largest currency by volume), runs
across the full two-year dataset, and the underlying series drifts as far as ±10% from 1.0 over
that window. I expected it to be worth tens of thousands of dollars for the quarter alone. Isolated
to FY2026 Q2, it was worth **$11,545 (3.5% of the corrected total)** — because the drift *within*
a single quarter (the rate sat between roughly 0.916 and 0.946 across Jan-Mar 2026) is much smaller
than the drift *across* the whole two-year series, and I only measured the one quarter I was asked
about. I know this because I ran the same isolation for the full 24-month window as a gut check and
the dollar swing there is roughly 8x larger — the bug is real and worth fixing everywhere, it just
isn't the story for this particular quarter.

## What I did not fix

- **Item-type revenue breakdown.** The original `fact_order` joined to `raw_order_items` to report
  revenue by item type, which is what caused the grain bug in the first place. I removed the join
  rather than reproduce it correctly, because "correctly" means prorating gross/refund/fee across
  an order's line items by some rule (unit price? quantity? something else for bundles?) that
  `REVENUE_POLICY.md` doesn't specify, and the ask here is revenue by *title*, not by item type. A
  wrong proration is worse than no breakdown. If this is needed, it should be a separate mart with
  the proration rule signed off by Finance, not a silent join in the revenue fact.
- **`dim_platform` stub.** Flagged as unfinished in `HANDOVER.md`. No platform attribute beyond
  `platform_code` exists anywhere in the landing data, and nothing in the revenue calc needs one.
- **Exact per-store settlement lag.** `REVENUE_POLICY.md` says settlement runs 30-60 days and
  varies by store; nothing in `data/` gives the per-store number, so `fact_order.settlement_date`
  is still the contractor's flat `order_date + 30`. It's clearly labeled as an approximation in the
  model and it plays no part in the revenue formula — settlement date is a cash-reporting concern,
  and mixing it into revenue reporting is exactly the mistake `REVENUE_POLICY.md` warns about.
- **Incremental load.** Out of scope per the brief (orchestration/scheduling), and the contractor's
  own handover note is right that at this volume a full rebuild is fine. Below is the shape I'd move
  to before it isn't.

### Running this tomorrow, at 50x the volume, landing hourly

The dedup key this exercise forced me to find (`order_id`, tie-broken by `ingested_at`) is also
the key an incremental load needs: land each batch into a staging area, `INSERT OR REPLACE`/merge
into a persistent `stg_order` keyed on `order_id` instead of `DROP`/`CREATE`-ing it from a full
CSV scan every run, and only re-run `stg_order_priced` → `fact_order` for touched `order_id`s (fee
and FX are both pure functions of `(platform_code/currency_code, order_date)`, so they're cheap to
recompute per-row without touching untouched rows). `raw_platform_fees` and `raw_fx_rates` are tiny
reference tables — full-refresh those every run regardless of volume. Two things I'd change before
trusting this at 50x: move off SQLite's single-writer-file model onto something that supports
concurrent incremental writes (Postgres or DuckDB, per the brief's own suggestion), and turn the
correlated-subquery FX/fee lookups into proper merge-joins against a pre-bucketed reference table —
they scale fine at this volume but a scalar subquery per row is the first thing I'd profile away.
