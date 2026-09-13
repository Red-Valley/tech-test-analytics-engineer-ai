# AI_WORKFLOW

## 1. Tool(s) and why

Claude (Sonnet), used agentically in a sandboxed Linux environment with direct tool access — `bash`,
file view/edit, and Python — not a plain chat window with copy-pasted answers. That mattered here
because the task isn't "explain SQL," it's "find what's wrong in a specific 285k-row SQLite
warehouse," and the only honest way to do that is to run queries against the actual data and let the
results, not intuition, decide what's a defect. Every claim in `FINDINGS.md` is backed by a query I
ran in this session against `build/warehouse.db` or the raw CSVs — nothing in there is from
"knowing what these bugs usually look like."

I also used two other AI tools — ChatGPT and Gemini — as independent second and third opinions on
the same brief, deliberately without giving either one access to this repo's actual SQL. The goal
was to see whether a differently-built pipeline landed on the same number, and if not, why. Both
disagreed with my total; both disagreements were run down to the cent against the real data rather
than settled by argument. That process, and what it turned up, is documented in `FINDINGS.md` under
"Independent cross-checks" — including a real formula defect in one of the other implementations
(refunds weren't netting the platform fee back, per `REVENUE_POLICY.md`'s explicit requirement that
"the platform refunds its fee along with them," which produced negative net revenue on 462 orders).
I did not otherwise use ChatGPT or Gemini to write any of this repo's SQL, tests, or documentation —
Claude did that work; the other two tools were reviewers, not authors.

## 2. Concrete prompts (self-directed, since this was one continuous session) and what came back

1. **"Run the pipeline and tests exactly as delivered before touching anything."**
   → `python3 bin/build.py && python3 bin/test.py`. Came back 4/7 passing: grain multiplication,
   pending orders, and null money all failed with row counts. This became the starting checklist
   instead of a vague "something's wrong."

2. **"For every table, show me the actual distinct values / date ranges / row counts — don't assume
   the schema from the column names."**
   → This is what surfaced the defects that *aren't* visible from reading the SQL alone: `order_status`
   has exactly 3 values (`completed`/`pending`/`refunded`), `email_domain` has 5 real domains plus one
   `.test` domain, `raw_orders` has 111,975 rows for 109,018 distinct `order_id`s, `effective_to` in
   `platform_fees.csv` is an empty string rather than blank/NULL once loaded as TEXT. None of these
   would show up from reading `models/*.sql` in isolation — they only show up by querying the data.

3. **"Rebuild the untouched original repo in a separate directory and compute FY2026 Q2 net revenue
   from it, so I have an apples-to-apples 'as delivered' number, not just a description of bugs."**
   → `$727,922.09`, vs. `$328,697.94` from the fixed pipeline. Having both numbers, computed the same
   way (same date filter, same SQLite file format), is what let "How far off was it, and in which
   direction" in `FINDINGS.md` be a stated number instead of a guess.

4. **"For each defect, isolate its dollar impact on FY2026 Q2 specifically, holding the rest of the
   fixed pipeline constant — don't assume severity from how bad the bug looks in the SQL."**
   → This is what caught the platform-fee finding: the "always uses the newest fee schedule" bug
   looked like it should be a big STEAM problem (30%→25%), but priced against Q2 specifically it was
   exactly $0.00 for STEAM (25% happens to be correct for Jan–Mar 2026) and $14,587.18 for XBOX
   instead. Without asking for the isolated, per-platform number I would have written up the wrong
   headline for that defect.

5. **"Before writing FINDINGS.md, check the two things that read like extra bugs but might not be —
   is `refunded` status ever a partial refund, and does the fee-in-force fix actually clear the null
   money check by itself?"**
   → Both checks changed what shipped: `refunded`-status orders are 100% full refunds (2,949 for
   2,949) in this data, so the old model's zero-out logic for that status was never actually wrong —
   the real refund bug was the 4,829 *`completed`*-status orders with a hidden partial refund. And the
   fee-in-force fix alone didn't clear the null-money test — see the next section.

## 3. One moment the AI was confidently wrong, and how I caught it

After fixing the platform-fee lookup to filter on `effective_from <= order_date AND (effective_to IS
NULL OR effective_to >= order_date)`, I was confident that resolved the fee-timing bug — the logic
matches `REVENUE_POLICY.md` and reads correctly. I rebuilt and re-ran the test suite expecting `no
NULL money on the fact` to go green.

It didn't: 74,476 rows still had null money, down from 60,240 but *worse in absolute terms* than
before the fix in one way — the fee lookup was now failing for platforms whose *current* fee row has
no `effective_to` at all (PSN, EPIC, NSW, and the open-ended row for STEAM/XBOX). The bug was that
`bin/build.py` loads every landing file as `TEXT`, so a blank CSV cell for `effective_to` lands as an
empty string `''`, not SQL `NULL` — and `'' >= order_date` is `false`, so my `IS NULL` check silently
excluded every open-ended fee row. I only caught this because I re-ran the test suite after the fix
instead of treating "the logic looks right" as sufficient — the row count went from 60,240 to 74,476,
which was the signal that something was still wrong (a correct fix should have made that number
strictly smaller). I traced it with one targeted query (`GROUP BY platform_code, fee_pct` on
`stg_order_priced` and looked for `NULL`), found the pattern, and added `effective_to = ''` to the
condition. This is now `t13_fee_pct_in_unit_range` and `t05_measures_not_null`, so a regression on
this exact loader quirk fails loudly instead of silently again.

## 4. Parallel agents / subagents / worktrees

I didn't use them, deliberately. The pipeline stages are strictly sequential and each one's
correctness depends on the previous one being right (staging dedup → FX/fee pricing → the revenue
fact → the fiscal mart), so splitting the fixes across parallel agents would have meant either (a)
agents working against each other's half-fixed intermediate tables, or (b) re-serializing their work
at the end anyway and re-deriving the same dependency order I already had. For a single ~285k-row
SQLite file on one machine, the bottleneck was never compute — it was sequential reasoning about
which defect to trust once, not throughput. If this were the fifty-times-larger, hourly-landing
version of this pipeline mentioned in the README, the place I *would* parallelize is orthogonal
investigation: one agent characterizing data-quality edges per landing file while another drafts the
dbt-style model layer, then a single reviewer (human or AI) reconciling both before either touches
`models/`.
