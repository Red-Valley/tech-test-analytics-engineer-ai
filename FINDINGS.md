# FINDINGS — FY2026 Q2 net revenue

```bash
python3 bin/run.py                       # build → 16 tests → independent cross-check → the number
python3 analysis/defect_waterfall.py     # the price of every defect, recomputed from data/*.csv
```

Python 3.8+ standard library only. No install, no account.

---

## The answer

**FY2026 Q2 (1 Jan – 31 Mar 2026) net revenue: $328,697.94**

| Title | Orders | Gross | Refunds | Platform fee | **Net revenue** |
|---|---:|---:|---:|---:|---:|
| T-01 Hollow Crown | 5,466 | 210,149.73 | 9,672.39 | 51,954.23 | **148,523.10** |
| T-02 Hollow Crown: Ashen Tide | 3,056 | 68,593.47 | 3,435.76 | 16,852.63 | **48,305.08** |
| T-03 Lantern & Lock | 2,560 | 39,221.18 | 1,510.01 | 9,782.99 | **27,928.18** |
| T-04 Saltmarsh Rally | 2,662 | 64,620.06 | 2,829.06 | 16,018.43 | **45,772.57** |
| T-05 Emberwatch Tactics | 2,444 | 81,650.77 | 3,138.33 | 20,343.43 | **58,169.01** |
| **Total** | **16,188** | **464,235.21** | **20,585.55** | **114,951.71** | **328,697.94** |

**The delivered pipeline reported $727,922.09: overstated by $399,224.15, i.e. +121.5%.** Leadership
has been looking at a number more than twice the real one. Finance's "doesn't feel right" was correct.

**Why I trust it.** The number is produced twice, by two implementations that share no code:
the SQL warehouse (`models/`), and a pure-Python recompute that reads the CSVs directly
(`analysis/defect_waterfall.py`). They agree to the cent on every title, and `bin/run.py` fails if
they ever stop agreeing. The same Python script, with every fix turned off, reproduces the delivered
$727,922.09 exactly, so the defect prices below are measured, not estimated.

A third derivation was made **blind**. An agent was given only the policy, the handover and the CSVs.
It could not see `models/`, `analysis/` or this document, and was never told the expected number.
It arrived at $328,697.94 independently, matching on every title to the cent, using `Decimal`
arithmetic and its own dedupe and FX logic. Two further agents audited the pipeline against the
policy and hunted for data issues not listed here. Neither found a revenue defect. Their
attribution and reporting risks are under "What I did not fix" (see `AI_WORKFLOW.md` §4).

---

## Defects

**How to read the money columns.** *Waterfall*: start from the delivered logic and fix defects one
at a time in the order listed. Each step is that fix's contribution, and the steps sum exactly to
the $399,224.15 gap. *Isolated*: start from the correct logic and re-introduce only that defect.
The two differ because defects interact. Fan-out multiplied every other error, and the FX NULLs
hid part of it. Positive means the delivered number was **too high**. Percentages are of the
correct $328,697.94.

| # | What was wrong | How I found it | Worth, FY26 Q2: waterfall | Isolated | Fix |
|---|---|---|---:|---:|---|
| D1 | **Fan-out.** `fact_order` joined `order_items` to get `item_type`, so the order-level gross was repeated on every line. Q2: 37,620 fact rows for 16,523 orders. | Shipped `t01` failed (43,680 orders). Confirmed that line totals reconcile to order gross on 106,061 / 106,061 non-duplicated orders, so gross is a header amount. | **+$445,484 (+135.5%)** | +$350,691 (+106.7%) | Order-grain `fact_order`. A separate `fact_order_line` allocates order measures by line share, and lines sum back to orders (`t15`). |
| D2 | **March 2026 re-land counted twice.** The outage fix in HANDOVER re-extracted March, so 2,957 orders (and their lines) landed twice. The copies are identical except `ingested_at` (re-landed 2026-04-01 05:40). | `COUNT(*)` 111,975 vs `COUNT(DISTINCT order_id)` 109,018 on `raw_orders`. All duplicates have order dates in March 2026, i.e. inside Q2. | **+$46,241 (+14.1%)** | +$59,171 (+18.0%) | Dedupe in staging on `order_id`, keeping the latest `ingested_at`. Unique index on every stg/fact key. |
| D3 | **Pending orders counted.** The fact only zeroed `refunded`, so `pending` (never completed) flowed into net revenue. Q2: 235 orders. | Shipped `t03` failed (1,602 orders). | **+$3,268 (+1.0%)** | +$5,018 (+1.5%) | Scope = `completed` + `refunded` (a fully refunded order did complete and nets to 0). |
| D4 | **Internal / QA accounts included.** 10 players on `@twinhearth.test` with 67–124 orders each (the largest real player has 15). Q2: 100 orders. | Profiled `email_domain`: one domain that is not a consumer mailbox, with outlier order counts. | **+$18,936 (+5.8%)** | +$24,313 (+7.4%) | `dim_player.is_internal`, filtered in the fact. `t12` matches `%twinhearth%` independently of the flag. |
| D5 | **Weekend orders silently dropped.** FX was joined on the exact order date, but rates are published on business days only. Every weekend order (6,045 in Q2, USD included) got a NULL rate, and `SUM()` ignores NULLs. | Shipped `t05` failed (60,240 rows). Every orphan was on `strftime('%w') IN (0, 6)`, and there were no weekday gaps in the rate file. | **−$124,732 (−37.9%)** | −$66,861 (−20.3%) | Gap-filled `fx_rate_daily` (last rate on or before each calendar day), then an equi-join. |
| D6 | **USD "converted" with a USD→USD rate that isn't 1.** `fx_rates.csv` carries a USD series drifting 0.897–1.031 (0.91–0.95 in Q2), and the pipeline applied it to the 7,216 USD orders in Q2. | Profiling `fx_rates` per currency: USD min/max ≠ 1. | **−$10,770 (−3.3%)** | −$10,147 (−3.1%) | USD = 1.0 by definition. The USD row in the file is never used. |
| D7 | **Platform fee: latest rate applied to all history.** `ORDER BY effective_from DESC LIMIT 1` ignores the order date. In Q2, Xbox was charged 12% instead of 30% (the 12% only starts 2026-04-01). | Read `03_stg_order_priced.sql` against the policy, then counted fee by platform. | **+$14,821 (+4.5%)** | +$14,587 (+4.4%) | Type-2 `dim_platform_fee` (inclusive windows), joined on `order_date BETWEEN effective_from AND effective_to`. |
| D8 | **Partial refunds ignored.** The fact used `order_status = 'refunded'` as its refund logic. The refunds table (the system of record) also holds goodwill credits and price adjustments on `completed` orders: 759 in Q2, 4,829 overall. | Reconciled `refunds` to orders: all 2,864 `refunded` orders are refunded in full, and 4,829 `completed` orders have partial refunds. | **+$5,975 (+1.8%)** | +$5,975 (+1.8%) | Refunds summed from the refunds table and attributed to the order date. The fee is charged on (gross − refund). |
| D9 | **`dim_date` fiscal calendar broken.** `((m - 10) % 12)` is negative for Jan–Sep in SQLite, so Q2 months had `fiscal_quarter_no` −2/−1 and **no month mapped to Q2 at all**. | `SELECT DISTINCT calendar_month, fiscal_quarter_no FROM dim_date`. | $0 to this number (the delivered figure came from date ranges). Anyone filtering `fiscal_quarter_no = 2` got **$0**. | — | `((m + 2) % 12)`, plus a `fiscal_quarter` label. The report now goes through `dim_date`. |
| D10 | **`settlement_date` = order + 30 days, hard-coded.** Policy says 30–60 days, varying by store. | Read `04_fact_order.sql` against the "Settlement" section. | $0 (revenue is recognised on order date) | — | Column removed, not guessed. See "not fixed". |
| D11 | **Shipped tests could not catch the money errors.** `t01` compared fact counts to `raw_orders`, which itself holds the duplicates, so a doubled order passed. Nothing checked FX, fees, refunds, scope or totals. | Reading `tests/`. HANDOVER says as much: "I never got to checking the money." | enabled all of the above | — | 9 new tests and 3 rewritten. See below. |

Sum of waterfall: +445,484.11 + 46,240.63 + 3,268.48 + 18,936.48 − 124,731.69 − 10,770.06 + 14,821.22 + 5,974.98 = **+$399,224.15**.

---

## Smaller than I expected: the platform-fee bug (D7)

The fee lookup took the newest rate for every order, ever. Two stores changed their rate. Steam,
the biggest store (42% of Q2 gross), went from 30% to 25%, and Xbox went from 30% to 12%. I expected
Steam to dominate the impact.

**Steam's contribution to the Q2 error is exactly $0.** Steam's newest rate (25%) took effect on
2026-01-01, the first day of Q2, so for this quarter "latest" and "in force on the order date"
happen to be the same row. The whole $14,587 isolated impact is Xbox, whose 12% only starts on
2026-04-01. I know this because the per-platform, per-quarter breakdown of
`(gross − refunds) × (correct fee − applied fee)` gives STEAM $0 in FY2026-Q2, but $8,776 in
FY2026-Q1 and $3.4–6.8k in every FY2025 quarter. The bug is real and costs more in every other
quarter; Q2 is the one quarter where half of it cancels by calendar coincidence.

*(Runner-up: pending orders. 1,602 pending orders sound alarming, but only 235 are in Q2, and with
the fan-out fixed they were worth $3.3k, 1%.)*

## Tests added: what they protect

Every new test was checked by **mutation**. I re-introduced each defect, alone, into the fixed
pipeline and confirmed that at least one test fails. All 9 money defects are caught.

| Test | Guards | Fails on re-introduced |
|---|---|---|
| `t01` (rewritten) one row per `order_id` | grain | D1, D2 |
| `t03` (tightened) only `completed`/`refunded` | scope | D3 |
| `t05` (extended) no NULL rate / fee / money | silent NULL drops | D5 |
| `t08` gross per currency × month = de-duplicated in-scope landing data | duplicates, fan-out, scope leaks, as **money** not counts | D1, D2, D3, D4 |
| `t09` FX = last published rate ≤ order date; USD = 1 | FX policy | D5, D6 |
| `t10` fee = the single schedule row in force on the order date | fee policy | D7 |
| `t11` refunds in fact = refunds table, refund ≤ gross, `refunded` ⇒ full | refunds as system of record | D8 |
| `t12` no internal player in the fact, by two markers independent of the flag: a `%twinhearth%` domain, **or** orders placed before the player's own signup date (315 orders, all QA; 0 for real players) | internal accounts, including QA staff who sign up with a personal email | D4 |
| `t13` fiscal quarter, month, year and the `FY2026-Q2` label, per policy, for every date | calendar | D9 |
| `t14` gross − refund = fee + net, and net = formula | arithmetic drift | — |
| `t15` lines sum to orders | item-type breakdown can't fan out again | D1 |
| `t16` leadership report = fact, per fiscal quarter × title | a bad filter or join in the mart itself | — |

The audit agent flagged that `t08` inner-joined players: an order whose player is missing from
`players.csv` would be dropped by the model **and** by the test, and still pass. `t08` now uses a
left join. It also flagged that line and refund dedupe used a bare `GROUP BY`, which keeps an
arbitrary copy if two copies ever differ. Staging now uses `DISTINCT` plus a unique index, so
differing copies fail the build loudly.
| `bin/run.py` cross-check | warehouse = independent recompute, per title | any logic error |

## What I did not fix, and why

- **Cash view of refunds** (by refund date) and **settlement**. Policy defines both, but this number
  is revenue. Settlement needs per-store payout terms that don't exist in the data, so I removed
  the made-up `+30 days` rather than replace it with another guess. Next step: a `platform_terms`
  source and a `fact_refund` at refund grain.
- **FX rate for refunds.** I convert a refund at the *order-date* rate, consistent with attributing
  it to the order date. The policy doesn't say. If Finance converts at the refund-date rate, Q2
  net moves by **$9.60** (measured). Immaterial, but it's a Finance decision, not a code one.
- **The Q2 number will keep moving.** Refunds are attributed to the order date, and 272 refunds on
  Q2 orders (−$3,762 net) landed *after* 31 March, the latest on 2026-06-09. A Q2 figure Finance
  snapshotted in early April would be about $3.8k higher than this one, and both would be right
  for their date. A closed-quarter snapshot / restatement log is the fix; it's process, not a bug.
- **Internal-account detection is one rule** (email domain). Staff using personal emails would get
  through. A maintained staff/QA list from HR or QA tooling is the real source.
- **Timezone.** `order_ts` has no zone, and I took the date as written. Measured sensitivity: at
  UTC−8, 52 orders ($1,217) leave Q2 at the 1 Jan edge and 61 ($1,212) join at 1 Apr. At UTC+9,
  63 join and 42 leave. Either way the net Q2 change is under $400 (0.1%). It needs the source
  systems' spec, not a guess.
- **Revenue by studio would double-count.** `title_studio_credits` lists two studios for T-02 and
  T-05 (Lead + Co-development). A studio report built through `bridge_title_studio` would count
  $106,474 of Q2 twice. No report does that today; a studio mart must use `credit_role = 'Lead'`
  (it matches `titles.lead_studio_id` on every title) or an explicit revenue-share weight.
- **A close-of-quarter snapshot can't be rebuilt.** `refunds.csv` has no `ingested_at`, so "Q2 as
  reported on 1 April" isn't reproducible. The loader should stamp refunds the way it stamps orders.
- **Not migrated to dbt / DuckDB.** For a team I'd use dbt (tests and lineage come for free). In
  3 hours, the one-command, zero-install rule was worth more than the tooling change. The SQL is
  written so it ports with little change.

## Model design, and how it runs at 50× hourly

- **Grain.** `fact_order`: one row per in-scope order, all measures additive in USD.
  `fact_order_line`: one row per order line, measures allocated and reconciled to the order fact.
  `rpt_revenue_fiscal_quarter_title`: the leadership mart.
- **Dimensions.** `dim_date` (fiscal attributes), `dim_title`, `dim_studio` + `bridge_title_studio`
  (co-development credits), `dim_player` (with `is_internal`), `dim_platform`, `dim_platform_fee`
  (type-2), and `fx_rate_daily` (gap-filled, one row per currency × day).
- **Incremental, hourly.** Land append-only. Dedupe staging by `order_id` on the latest
  `ingested_at` with `MERGE`, using an `ingested_at` watermark. A new refund **restates its
  order's date**, so each run rebuilds the fact for the set of order dates touched by new orders
  *or* new refunds in the batch, partitioned by `order_date`. Fee and FX changes are as-of joins
  against small dimensions, so they stay cheap at any volume. A newly published FX rate re-prices
  only the orders since the previous rate date.
- **Guard rails at scale.** The tests above become post-load assertions on the touched partitions.
  The independent recompute becomes a nightly reconciliation of closed quarters against Finance's
  ledger.
