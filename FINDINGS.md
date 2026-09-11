# FINDINGS — FY2026 Q2 net revenue

Reproduce with: `bash bin/run.sh` (or `python3 bin/build.py && python3 bin/test.py`).

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
  breaks.
- **At 50x the volume:** the join-based FX/fee "as-of" lookups (`ORDER BY ... LIMIT 1` correlated
  subqueries) are the first thing I'd replace — they're correct but re-scan per row. At 50x I'd
  pre-join each `(currency_code, date)` and `(platform_code, date)` once into a date-spine table (a
  single window-function pass instead of a correlated subquery per order), which is the same
  as-of-join *logic*, just computed once instead of once per row.
- **Landing hourly instead of daily:** the dedup fix for defect #2 (`MAX(ingested_at)` per
  `order_id`) already behaves correctly as an incremental/idempotent upsert key, not just a
  full-rebuild patch — re-landing the same order twice in an hour, or the loader retrying after a
  partial failure, resolves the same way it does now. What's genuinely missing for hourly landing
  (and out of scope per the README) is a watermark so `bin/build.py` doesn't re-scan all of history
  every run, and a policy for late-arriving refunds against orders from a prior, already-closed
  period — right now a refund landing next week against last month's order still nets correctly
  (revenue is recomputed from source each run), but that only works because this is a full rebuild;
  an incremental model would need to explicitly re-open the affected order's partition.

