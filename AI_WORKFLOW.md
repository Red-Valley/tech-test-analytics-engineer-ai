# AI_WORKFLOW

## 1. Tool(s) and why

Claude (Anthropic), inside a single continuous chat session with code execution (bash + a
persistent sandbox filesystem, not just a code-completion window). I used one tool end to end
rather than switching between an editor-integrated assistant and a separate chat: this task is
mostly "run something, read the real output, form a hypothesis, run something else to check it" —
`bin/build.py`, `bin/test.py`, and a lot of ad hoc SQL against `build/warehouse.db` — and having
the model actually execute those and see the real rows back (not guess at them) is what made the
quantification in `FINDINGS.md` possible at all. I did not reach for a second, more code-focused
tool because nothing here was large-scale refactoring — four small SQL model files and a handful of
new test files.

## 2. Concrete prompts and what came back

**"Run the harness before changing anything, and show me exactly what fails."**
→ `bin/build.py` loaded clean; `bin/test.py` came back 4/7, failing on grain multiplication
(43,680 rows), pending orders in the fact (1,602 rows), and NULL money (60,240 rows). This is what
the README asks for as a starting point, and it's also what shaped everything after it — three
concrete, reproducible failures to chase instead of a vague "the number feels wrong."

**"Before assuming the given tests are the full picture, check `HANDOVER.md` and
`REVENUE_POLICY.md` against what the raw tables actually contain."**
→ This is what surfaced the two defects no test caught: the handover's throwaway line about
re-running the March extract turned into a targeted `GROUP BY order_id HAVING COUNT(*) > 1` query
that found the 2,957 duplicated orders; the policy's line about internal/QA accounts turned into a
`GROUP BY email_domain` on `raw_players` that immediately surfaced `twinhearth.test`.

**"`platform_fees.csv` has effective-dated rows — check whether the pipeline actually uses the
date, or just grabs a row."**
→ Reading the old subquery (`ORDER BY effective_from DESC LIMIT 1`, no date filter) against the
actual `platform_fees.csv` contents showed it would hand every XBOX order in FY2026 Q2 a 12% fee
instead of the correct 30% — the 12% rate isn't effective until April 2026, a quarter after the
one being reported on.

**"Isolate each fix's dollar impact instead of just reporting a before/after total."**
→ I parameterized the pipeline logic as a single Python function with a boolean flag per defect,
ran it against the same `raw_*` tables with flags toggled on cumulatively, and diffed the running
total after each one. That's the waterfall in `FINDINGS.md` — without it I'd only have "the number
was wrong by $399k," not which defect was worth what.

**"Prove the new tests aren't tautological — run them against the original, unfixed models and
confirm they fail for the right reason."**
→ Copied the six new test files into a clean checkout still on the original `models/`, ran
`bin/test.py`, and got 4/13 passing with each new test failing with a row count or error that
matches the corresponding defect (e.g. `t12` returned 33,283 USD orders priced at a non-1.0 rate).

## 3. A moment it was confidently wrong

Checking whether refund amounts matched gross exactly for every `status='refunded'` order turned
up 85 orders where the refund total was *exactly double* the gross amount — which looked, for a few
minutes, like a third refund-related defect on top of the ones already found (maybe a refund
double-posting bug in `raw_refunds`?). I was ready to write it up as one. Before doing that I
checked whether those 85 order_ids had anything else in common, and they did: every one of them was
also a member of the 2,957 March duplicate-order set already found. The "double refund" wasn't in
the data at all — it was an artifact of my own diagnostic query joining a single refund row to two
duplicated `raw_orders` rows for the same order, which summed the one real refund amount twice. The
fix wasn't a new defect, it was to run that check *after* deduping, not before. I caught it by
requiring a second, independent signal (membership in the known-duplicate set) before trusting a
finding that would otherwise have gone straight into `FINDINGS.md` as its own line item.

## 4. Parallel agents / subagents / worktrees

Not used. Every step here depended on the result of the one before it — you can't measure the
dollar impact of fixing partial refunds until the grain, dedup, and status-filter fixes are already
in place underneath it, or the "impact" you'd measure is contaminated by bugs that haven't been
removed yet. That made this a genuinely sequential debugging session rather than a set of
independent sub-tasks, so there was nothing to parallelize without either getting wrong intermediate
numbers or rebuilding the same warehouse repeatedly for no benefit.
