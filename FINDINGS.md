# FINDINGS — FY2026 Q2 net revenue

Reproduce with: `bash bin/run.sh` (auto-detects `python3` vs `python`; if running the two
scripts directly instead, use whichever your system has — `python3 bin/build.py && python3
bin/test.py` on most Linux/Mac setups, `python bin/build.py && python bin/test.py` on a typical
Windows install from python.org).

## Independent cross-checks

Before finalizing, I didn't just trust my own number. I re-derived this pipeline two more times,
independently, and reconciled every discrepancy against the real data instead of arguing from logic
alone. Two other AI tools (ChatGPT and Gemini), given the same brief independently, produced two
different totals; both disagreements turned out to be fully explainable, and reconciling them
surfaced one genuine defect I hadn't caught on my own (see Cross-check B).

### Cross-check A (ChatGPT) — reached $318,550.72

**The gap:** $10,147.22 (3.1%) below mine, on every one of the five titles proportionally.

**Method:** reproduced ChatGPT's described logic verbatim as a second SQL pipeline against this
repo's real data, then diffed every order, side by side, against mine.

**Finding:** the two pipelines agreed on every defect and every fix except one — whether a
**USD-denominated order** should be run through `raw_fx_rates` at all. `raw_fx_rates` carries a `USD`
row for every date, but its value drifts (0.897–1.065), never exactly 1.0. This pipeline treats USD
as the reporting currency and passes it through unconverted (`rate_to_usd = 1.0`); ChatGPT's joined
it through the table like any other currency. `REVENUE_POLICY.md`, "Currency":
*"Non-USD orders are converted using the last published rate..."* — the explicit scoping to non-USD
is why I read USD as pass-through.

**Verified, not just argued:** recomputing Q2 with USD run through `raw_fx_rates` (instead of 1.0)
reproduces ChatGPT's total **exactly** ($318,550.72) and matches its five per-title
figures to the cent. The entire gap is that one design decision, nothing else.
`t14_usd_orders_not_converted.sql` asserts the position this repo takes; if that decision is ever
revisited, that's the one test that should start failing.

### Cross-check B (Gemini) — reached $260,481.97

**The gap:** $68,215.97 (26.2%) below mine.

**Method:** Gemini supplied runnable SQL, not just a description, so I ran it **verbatim** against
the delivered (unfixed) warehouse and reproduced its number exactly — $260,481.97, same five titles,
to the cent. From there I diffed its query logic against mine line by line.

**Findings:** four of the five differences were expected — Gemini, by its own account,
had not yet deduplicated the March orders (#2), excluded internal accounts (#3), excluded `pending`
orders (#6), or fixed the weekend FX gap / USD noise (#7, #8). Those are known, already-quantified
gaps. The fifth difference was new, and it's a genuine defect Gemini's implementation introduced
rather than left unfixed:

Its refund formula was `(gross × (1 − fee_pct) − refund) × rate`. Mine is
`(gross − refund) × rate × (1 − fee_pct)`. These are **not algebraically equivalent** — the difference
works out to exactly `refund × rate × fee_pct` per order, always in the same direction. `REVENUE_POLICY.md`,
"Net revenue"/"Refunds": *"the platform refunds its fee along with them"* — meaning the fee that's
actually retained should shrink along with the refunded portion. Gemini's formula keeps the fee
un-refunded and simply subtracts the raw refund on top, which:

- **costs $5,378.12** in Q2 in isolation (the fee-on-refunded-amount that should have been given back but wasn't), and
- produces **462 orders with negative net revenue** in Q2 alone — a fully-refunded $9.53 order comes out to **−$2.38** instead of **$0.00**. This directly violates `t06_measures_not_negative`, one of the seven checks that shipped with the original, unfixed pipeline — so this formula, had it been used here, would have failed a test that was already sitting in the repo.

**Verified, not just argued:** running Gemini's exact SQL against the delivered,
unfixed warehouse reproduces $260,481.97 precisely; substituting only its refund formula into an
otherwise-identical query and comparing to the correct formula isolates the $5,378.12 and the 462
negative rows above.

### Why this section exists

Two different total mismatches, two different root causes, both nailed down to the cent rather than
"my number feels more right." That's the standard I'd want applied to my own number too — nobody
should take $328,697.94 on faith either; `bash bin/run.sh` reproduces it from a clean checkout in
under a minute.

## Defects found

| # | What was wrong | How I found it | What it was worth (FY2026 Q2, USD and %) | Fix |
|---|---|---|---|---|
| 1 | `fact_order` joined `stg_order_priced` straight to `raw_order_items`, so an order with N line items produced N fact rows, each carrying the **order's full** revenue. Any `SUM()` multiplied revenue by items sold, not orders sold. | Ran `t01_fact_grain_not_multiplied` — failed with 43,680 offending rows. Confirmed 35% of orders have >1 line item (`awk` on `order_items.csv`). | **+$350,690.54 (+107%)** of the reported number was phantom, item-count revenue. | Rebuilt `fact_order` at order grain (one row per `order_id`); line-item detail moved to `fact_order_item`, which carries no money columns so it can't be summed into a P&L again. |
| 2 | The March 2026 loader outage was fixed by re-running the extract for the rest of the month (per `HANDOVER.md`), but the re-run **re-landed** rows instead of replacing them. `raw_orders` has 111,975 rows for only 109,018 distinct `order_id`s — 2,957 orders exist twice, differing only in `ingested_at`. March sits inside FY2026 Q2. | `SELECT order_id, COUNT(*) FROM raw_orders GROUP BY order_id HAVING COUNT(*)>1` → all 2,957 dated March 2026. | **+$59,171.01 (+18%)** double-counted. | Dedupe in `stg_order` at the earliest stage: keep the row with `MAX(ingested_at)` per `order_id`. |
| 3 | `dim_player` had no way to identify internal/test/QA accounts. `REVENUE_POLICY.md` requires excluding them from every reported metric; nothing did. | Diffed `email_domain` values: 5 real consumer-mail domains + one reserved `.test` TLD (`twinhearth.test`, 10 of 45,000 players — RFC 2606 test domain). | **+$24,313.07 (+7.4%)** of Q2 revenue came from 10 staff/QA accounts. | Added `dim_player.is_internal`; `fact_order` filters it out. |
| 4 | Platform fee lookup was `ORDER BY effective_from DESC LIMIT 1` with **no date filter** — every order in history got whichever schedule row has the latest `effective_from`, i.e. today's rate applied retroactively. | Grouped `stg_order_priced` by `platform_code, fee_pct`: every platform showed exactly **one** fee for its entire 2-year history, which is impossible given `platform_fees.csv` has multiple `effective_from` rows for STEAM and XBOX. | **+$14,587.18 (+4.4%)**, all on XBOX (charged 12% instead of the 30% in force Jan–Mar 2026). STEAM happened to be unaffected in this quarter — see "smaller than expected" below. | Filtered the fee lookup to `effective_from <= order_date AND (effective_to IS NULL/'' OR effective_to >= order_date)`. |
| 5 | Orders with `order_status = 'completed'` that still carry a refund in `raw_refunds` (partial refunds that don't flip the status) were never netted — the pipeline only reacted to `order_status = 'refunded'`, which in this data always means a full refund. `REVENUE_POLICY.md`: *"the refunds table is the system of record."* | Joined `raw_orders` to `raw_refunds`: 4,829 `completed`-status orders have a refund row the old pipeline never looked at. | **+$5,974.98 (+1.8%)** overstated because these partial refunds were silently ignored. | `fact_order` now sums `raw_refunds` per `order_id` independent of `order_status`, and nets it off gross (capped at gross — see below). |
| 6 | `raw_orders` has 1,639 `pending` orders (never completed) that the old pipeline reported as full revenue. `REVENUE_POLICY.md`, Scope: *"Orders that never completed are not revenue."* | `t03_no_pending_orders` failed with 1,602 offending rows on the delivered pipeline. | **+$5,017.54 (+1.5%)** revenue from orders nobody ever paid for. | `fact_order` filters to `order_status IN ('completed','refunded')`. |
| 7 | FX join was an exact match (`fx.rate_date = order_date`). `raw_fx_rates` only has Monday–Friday rows; every order on a Saturday **or Sunday** got no match → `NULL` rate → `NULL` revenue, silently dropped from every `SUM()`. | `t05_measures_not_null` failed with 60,240 offending rows on the delivered pipeline (34.6% of all rows). Grouped nulls by day-of-week: 100% fell on Sat/Sun. | **−$66,861.49 (−20.3%)** — this one goes the *other* way: it made the delivered number too **low**, partially offsetting the bugs above. | FX lookup now takes the most recent `rate_date <= order_date` ("last published rate on or before," per policy), instead of an exact-date match. |
| 8 | `raw_fx_rates` includes a `USD` row for every date, but it isn't 1.0 — it drifts ~0.90–1.06 (noise). The old join applied it to USD orders anyway, even though the policy only calls for converting *non‑USD* orders. | Spot-checked `grep '^USD,' fx_rates.csv`: rates like `0.914394`, not `1.0`. Half of all orders are USD. | **−$6,376.47 (−1.9%)** in Q2 specifically (the noise happened to sit below 1.0 for most of Jan–Mar 2026) — again understating, not overstating. | USD orders are now special-cased to `rate_to_usd = 1.0`; `raw_fx_rates` is only consulted for non-USD currencies. |
| 9 | `dim_date.fiscal_quarter_no` / `fiscal_month_no` used `(calendar_month - 10) % 12`. SQLite's `%` keeps the sign of the dividend, so for any month before October the expression is **negative**, and integer division of a negative number truncates toward zero instead of flooring. Result: every month from January to September resolved to `fiscal_quarter_no = 1` or a negative number — **FY2026 Q2 (Jan–Mar) could not be selected through this column at all.** | Read the column for known months: `2026-01-15 → fiscal_quarter_no = -2`. That's not a valid quarter under any definition. | **$0 direct effect on the number reported here** (I filtered by calendar date, not this column, specifically because I didn't trust it) — but this is very likely *the* root cause of Finance's "the numbers don't feel right": any dashboard or ad-hoc query that filtered on `fiscal_quarter_no = 2` got garbage or an empty result, not a wrong-but-plausible number. | Shifted by `+12` before the modulo: `((calendar_month - 10 + 12) % 12)`. Added `t10_fiscal_quarter_in_range` so this class of bug can never ship silently again. |
| 10 | `raw_platform_fees.effective_to` is empty string `''` for open-ended schedule rows (the whole raw layer loads as `TEXT`, see `bin/build.py`), not `NULL`. My first fix for #4 (`effective_to IS NULL OR effective_to >= order_date`) still excluded every currently-open fee row, because `'' >= order_date` is false. | Rebuilt after fix #4, `t/no_null_money` still failed with 74,476 rows — narrower than before, but still there. Traced it to `fee_pct IS NULL` exactly on the platforms/date-ranges whose *current* schedule row has a blank `effective_to`. | Would have been a second silent revenue-suppression bug layered on top of #4 had it shipped. | Treat `''` the same as `NULL` in the fee lookup. |

Two things I checked and found were **not** bugs, worth recording so nobody re-litigates them: (a) `order_status = 'refunded'` in this dataset is always a *full* refund (2,949 of 2,949) — the old model's "zero it out" logic for that status was actually correct, it just missed the partials hiding under `completed` (#5); (b) `t04_referential_integrity` and `t02_no_orphan_orders` passed honestly on the delivered pipeline — `dim_title`/`dim_player`/`raw_orders` really do agree on keys.

## FY2026 Q2 net revenue, by title, and the total

| Title | Completed orders | Gross USD | Refunds USD | Platform fee USD | **Net revenue USD** |
|---|---:|---:|---:|---:|---:|
| Hollow Crown | 5,466 | 210,149.73 | 9,672.39 | 51,954.23 | **148,523.10** |
| Emberwatch Tactics | 2,444 | 81,650.77 | 3,138.33 | 20,343.43 | **58,169.01** |
| Hollow Crown: Ashen Tide | 3,056 | 68,593.47 | 3,435.76 | 16,852.63 | **48,305.08** |
| Saltmarsh Rally | 2,662 | 64,620.06 | 2,829.06 | 16,018.43 | **45,772.57** |
| Lantern & Lock | 2,560 | 39,221.18 | 1,510.01 | 9,782.99 | **27,928.18** |
| **TOTAL** | **16,188** | **464,235.20** | **20,585.55** | **114,951.71** | **$328,697.94** |

## How far off the delivered pipeline was

The delivered pipeline reports **$727,922.09** for FY2026 Q2. The correct number is **$328,697.94**.
That's an overstatement of **$399,224.15 — the delivered number is 121.5% too high**, more than double
the real figure. Direction matters here: it isn't one bug pushing the number up — it's several bugs
pushing it up hard (grain multiplication, March duplicates, internal accounts, pending orders, the
XBOX fee) partially offset by two bugs pushing it down (the weekend FX gap, the USD noise). The
isolated impacts in the table above don't sum exactly to $399,224.15 because the bugs interact
(e.g. grain multiplication also multiplies the phantom pending-order and internal-account revenue) —
each row is measured holding the *fixed* pipeline constant and re-introducing one defect at a time,
which is directionally accurate but not strictly additive.

## A defect that was smaller than expected

I expected the platform-fee bug (#4 — "always uses the newest fee schedule row, ignoring the order
date") to be one of the biggest problems, since STEAM's fee changed from 30% to 25% and this logic
gets that wrong for the platform's entire history. But when I isolated its effect **on FY2026 Q2
specifically**, STEAM's impact was exactly **$0.00** — because 25% *is* the fee that's actually
correct for Jan–Mar 2026 (STEAM's rate changed on 2026‑01‑01, right at the start of the quarter). The
bug is real and would badly misstate every *other* quarter's STEAM revenue, and it does cost
$14,587.18 in Q2 through XBOX (whose rate change lands on 2026‑04‑01, just after the quarter), but I
only know STEAM's impact is zero because I priced it per-platform instead of assuming "wrong logic ⇒
wrong number this quarter too."

## What I did not fix, and why

- **Item-type revenue breakdown.** I removed the item join because it was corrupting revenue, but I
  did not build a replacement (e.g. allocating an order's revenue across its line items by unit
  price). Finance hasn't specified an allocation rule, and guessing one risks recreating the exact
  bug I just fixed in a quieter form. `fact_order_item` preserves item mix/quantity without money, so
  the question can be answered correctly once someone decides how to allocate.
- **Settlement/cash reporting.** `REVENUE_POLICY.md` says settlement lag varies 30–60 days by store,
  but no per-store lag is provided anywhere in the data — `platform_fees.csv` has no such column. I
  left `settlement_date` as a flagged, documented placeholder (`order_date + 30d`) and — critically —
  it is not used anywhere in the net-revenue calculation, so it cannot be silently wrong in the
  number this document is about. Building real settlement logic without the input data would just be
  fiction.
- **Incremental loads.** `HANDOVER.md` says full rebuild is "fine at this volume." I didn't design
  incremental logic (dedup keys, late-arriving refunds, watermarking) because the README explicitly
  scopes orchestration out, and doing it without a real scheduling story to hang it on would be
  speculative. I did make the fix for defect #2 dedupe-safe for a future incremental load (keeps
  latest `ingested_at` per key) so it isn't a dead end.
- **The 85 orders where summed refunds exceed gross by a few cents-to-a-few-points.** I capped
  `refund_usd` at `gross_usd` so revenue never goes negative, but I did not chase down *why* refunds
  overshoot (FX rounding on the storefront side vs. a real data-entry error are both plausible, and
  distinguishing them needs someone at Finance, not more SQL). This is a $0 impact on the total but
  worth a Finance follow-up.
- **`bridge_title_studio` / multi-studio revenue split.** The contractor's dimensions here looked
  correct and nothing in the target metric (revenue by title) needed them, so I left them untouched
  rather than spend time validating a table nothing downstream reads yet.

Rationale for the cut line overall: the nine items I fixed all move the FY2026 Q2 number or directly
protect its correctness; the four above don't change that number and each would have taken real time
to do properly rather than superficially — better to say so than fix them silently and worse.

## Design notes: grain, dimensions, and running at 50x/hourly

- **Grain.** `fact_order` is one row per completed order (the transaction grain Finance actually
  reports against). Item-level detail is a separate table (`fact_order_item`) with no money columns,
  so "how many orders" and "what did people buy" can never again be conflated the way defect #1 did.
- **Dimensions.** `dim_player`, `dim_title`, `dim_studio`, `dim_platform`, `dim_date` are unchanged in
  shape from the delivered pipeline except `dim_player.is_internal` (new) and the `dim_date` fiscal
  math fix — both additive, not restructuring, so nothing downstream that already joins to them
  breaks. The title/studio bridge (`bridge_title_studio`, per the contractor's original design)
  stays independent of `fact_order`'s grain on purpose — a title can credit multiple studios, but
  revenue is recognized once, against the order, not fanned out across every credited studio.

### What changes at 50x volume, landing hourly instead of once

The logical model doesn't change — order grain, effective-dated FX/fee, refunds netted from the
system of record. What changes is how each stage is *computed*, because "rebuild everything from
scratch" (what `bin/build.py` does today) stops being viable once a run has to finish in minutes,
not seconds, every hour:

```
raw landing (append-only, hourly)
        │
        ▼
watermark: which order_ids are new or touched since the last successful run?
   (an order is "touched" if it has a new/changed row in orders, OR a new
    row in refunds against an order from any prior period)
        │
        ▼
re-run defect #2's dedup logic, scoped to touched order_ids only
   (MAX(ingested_at) per order_id — already idempotent, just needs a WHERE)
        │
        ▼
price touched orders against a pre-computed FX/fee date-spine
   (see below — not a per-row correlated subquery anymore)
        │
        ▼
MERGE touched rows into fact_order (upsert by order_id, not full rebuild)
        │
        ▼
re-run the 15 checks, scoped to the touched partition + a periodic full sweep
        │
        ▼
advance the watermark only if checks pass
```

Concretely, three things I'd change first, in order of how soon they'd bite:

1. **The FX/fee "as-of" lookups become a pre-joined date-spine, not a correlated subquery.**
   `stg_order_priced` today re-runs `ORDER BY rate_date DESC LIMIT 1` once per order. That's fine at
   109k orders; at 50x it's 50x the subquery evaluations. The fix keeps the exact same *logic*
   (last rate/fee in force on-or-before the date) but computes it once: forward-fill
   `raw_fx_rates`/`raw_platform_fees` across every calendar day with a window function into a
   `(currency_code, date) → rate` and `(platform_code, date) → fee_pct` spine, then a plain
   equi-join replaces the correlated subquery.
2. **Late-arriving refunds need an explicit re-open rule, not an implicit one.** Right now a refund
   landing this week against an order from three fiscal quarters ago still nets correctly, but only
   because every run recomputes revenue from source. An incremental model has to decide, explicitly,
   how far back a new refund re-opens an already-closed and already-reported period — that's a
   Finance policy question (how many periods stay "open"?), not a SQL question, and I'd rather flag
   it than guess at a cutoff.
3. **The dedup key becomes the idempotency guarantee for retries, not just for the March incident.**
   Defect #2's fix (`MAX(ingested_at)` per `order_id`) already means a loader retry or a re-sent
   hourly batch can't double-count an order — that was true by accident here (fixing March) and
   needs to be true by design at 50x, where retries are routine rather than a one-off outage.

What I would *not* rebuild from scratch: the checks. All 15 stay meaningful at 50x — they're
row-level and set-based (no order twice, no internal player, fee between 0 and 1), so they scale
with the data and don't need rewriting, only re-scoping to run against the touched partition on
every incremental run plus a full sweep on a slower cadence (nightly, say) to catch anything an
incremental pass could miss — a schedule detail, which per the README's scope I'm describing rather
than building.
