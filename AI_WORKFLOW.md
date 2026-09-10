# AI_WORKFLOW


## 1. Tool(s) and why

Claude (Anthropic), inside a single continuous chat session with code execution (bash + a
persistent sandbox filesystem, not just a code-completion window). I chose it because it helped me
understand the code faster and find errors quickly enough to actually fix them within the time I
had — instead of reading four SQL files cold and guessing what each subquery did, I could have it
run `bin/build.py`/`bin/test.py`, show me the real failing rows, and explain what each defect meant
against `REVENUE_POLICY.md`.

Driven by a single high-level directive ("ayúdame a resolverlo") rather than a sequence of narrow,
line-by-line prompts — the agent investigated and fixed the pipeline autonomously from that one
instruction, and my own prompts after that were about verifying and understanding the result, not
directing new technical work. I used one tool end to end rather than switching between an
editor-integrated assistant and a separate chat: this task is mostly "run something, read the real
output, form a hypothesis, run something else to check it" — and having the model actually execute
those and see the real rows back (not guess at them) is what made the quantification in
`FINDINGS.md` possible at all. I did not reach for a second, more code-focused tool because nothing
here was large-scale refactoring — four small SQL model files and a handful of new test files.

## 2. Concrete prompts and what came back

**"Me ayudas a resolverlo" (help me solve it) — a single high-level directive, not a sequence of
narrow prompts.**
→ From that one instruction, the agent autonomously cloned the repo, ran `bin/build.py` and
`bin/test.py` (4/7 passing, failing on grain multiplication, pending orders, and NULL money),
read `HANDOVER.md` and `REVENUE_POLICY.md` against what the raw tables actually contained, found
all 8 defects, fixed them, and built the dollar-quantified waterfall in `FINDINGS.md`.

**"¿Eso cumple con todo lo que se debe hacer en la prueba?" (does this satisfy everything the test
asks for?) — checked the delivered work against the README's own evaluation table.**
→ Surfaced two real gaps: the PR itself didn't exist yet (only a local commit), and
"one-command reproducibility" (5% of the grade) was weaker than it should be — getting the actual
FY2026 Q2 number still required hand-written SQL after the build. Led directly to adding
`bin/report.py`.

**"Hay tres formas de resolver el fan-out del grano: quitar el join, prorratear por línea, o
agregar antes de unir. Explícame los trade-offs de cada una — yo decido cuál implementar."**
→ Got a trade-off breakdown of all three: removing the join (safest, loses the item-type
breakdown), prorating by line (keeps the breakdown, but requires inventing a split rule
`REVENUE_POLICY.md` never specifies), and aggregating item data before the join (keeps the join
1:1 but doesn't actually answer "revenue by item type"). Chose to remove the join — the deliverable
asks for revenue by title, not item type, and a made-up proration rule is worse than no breakdown.

**"Aquí está mi versión de la subquery de FX [código pegado]. ¿Qué le falta comparado con la
política?"**
→ Confirmed the pasted FX/fee logic matches `REVENUE_POLICY.md` line by line (the "last rate on or
before the order date" wording, and the `effective_to = ''` gotcha from CSVs loading every column
as `TEXT`) — nothing missing today. Flagged one forward-looking risk instead of a current bug: both
scalar subqueries can silently return `NULL` if a future currency or platform has no covering row,
which wouldn't break the build but would silently drop that order's money from any `SUM`.

**"No me des el SQL corregido — dime en palabras qué condición le falta al `WHERE`, y yo lo
escribo."**
→ Explained in words, not code: `fact_order`'s `WHERE` only filters on `order_status`, so an order
with an unresolved `fee_pct`/`rate_to_usd` would still enter the fact with `NULL` money and
disappear from any `SUM` without being flagged — the missing condition is an explicit not-null
check on those two derived columns. Left the actual SQL for me to write.

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
