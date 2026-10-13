# AI_WORKFLOW

**Summary.** I used one tool, Claude Code: a main agent with broad delegation for discovery and
the fix, plus three parallel, deliberately blind subagents for independent verification. The
agents did the profiling, the coding and most of the verification design. My job was to set the
brief, approve the plan, review what came back, and check that the result holds. Total time was
about an hour. The agents' speed is the reason that fit; the review is the reason I'm willing to
stand behind the number.

## 1. Tools, and why

**Claude Code (Opus 5.5), in agent mode inside VS Code.** Nothing else: no chat assistant, no IDE
autocomplete.

Why an agent rather than a chat: this task is *profile, then prove*. That means hundreds of small
SQL queries, where each result decides the next query. An agent that runs `sqlite3` and `python3`
in the repo and reads its own output closes that loop in seconds. A chat window would have meant me
pasting query results back and forth, and that's where the time limit goes.

Why delegate broadly instead of steering query by query: I'd rather spend my time judging results
than typing queries. The trade-off is that I own a pipeline I didn't type, so I treated the
verification below as non-negotiable.

## 2. Prompts and what came back

I wrote few prompts, and wrote them broad on purpose. Here is what I asked, what the agent did with
it, and what I checked.

1. **"Explícame el archivo README.md"** (*explain the README*).
   It found the README one directory below where I'd opened the workspace, and summarised the
   brief and the grading. The useful part was its reading of the incentives: a green test run with
   a wrong number is graded worse than an incomplete one, and triage is graded. That decided my
   strategy before any code: **find and price defects; don't chase green tests.**

2. **"Actúa como si fueras un ingeniero de datos senior y ayúdame a completar esta prueba"**
   (*act as a senior data engineer and help me complete this test*).
   This one prompt produced most of the work. What came back, in order:
   - It read every doc, model and test before changing anything, and ran the delivered pipeline
     for a baseline: **$727,922.09** for FY2026 Q2, with 4 of 7 tests passing.
   - It profiled every landing table. It found the March duplicate re-land by connecting
     `ingested_at` timestamps to the HANDOVER note about the loader outage, and the fact fan-out by
     showing that line totals reconcile exactly to order gross. In total it found 9 money defects
     plus 2 structural ones.
   - **Unprompted**, it wrote a second, independent implementation: pure Python over the CSVs,
     sharing no code with the SQL (`analysis/defect_waterfall.py`). With every fix off it
     reproduces the delivered $727,922.09 to the cent. With every fix on it matches the warehouse
     to the cent. That turns a list of suspected bugs into a full accounting of the gap: the
     defect waterfall sums exactly to $399,224.15.
   - **Unprompted**, it mutation-tested its own tests. It re-introduced each defect alone into a
     throwaway copy of the fixed pipeline and confirmed that at least one test fails for each.
   - It ran `bin/run.py` in a clean copy with no `build/`, to prove the one-command rule instead of
     assuming it.

   I did not ask for those three verification steps; the agent chose them. I'm listing them as
   its contribution, not mine. My contribution was deciding that they were the right bar, and then
   checking them myself (below).

3. **My review, without prompting the agent:**
   - Read every changed model and test in `models/` and `tests/` against
     `docs/REVENUE_POLICY.md`.
   - Ran `python3 bin/run.py` myself and got the same 15/15 tests and $328,697.94.
   - Read `FINDINGS.md` end to end, checking that every number has a method behind it.

4. **"Ayúdame a revisar y personalizar el AI_WORKFLOW.md"** (*help me review and personalise this
   file*). Its first draft of this file had a problem, described in section 3. It flagged the
   problem itself, asked me how I'd actually worked (tools, time, what I'd reviewed), and rewrote
   the file from my answers. That is the version you're reading.

5. **"¿Cómo puedo mejorar el AI_WORKFLOW… que use agentes en paralelo o algo así?"** (*how can I
   improve this, e.g. with parallel agents?*). The agent pushed back on the framing first: claiming
   parallel agents in a document doesn't make it stronger; using them for something that could
   change the answer does. It proposed three **blind** agents, and I approved them (see §4).

## 3. When the AI was confidently wrong

**It put words in my mouth.** The first draft of this file described the independent recompute,
the mutation tests and the clean-checkout run as things *I* had asked for ("I asked for the number
to be reproduced by code that shares nothing with the SQL…"). I never wrote those prompts; the
agent had decided on those steps by itself. The draft read smoothly and fit what this section asks
for. It was simply false. It was caught when I asked the agent to review the file before
submission: it compared the document against the actual conversation and flagged that the
attribution didn't match. **Lesson:** an AI writing about its own process will tell the story the
reader wants. The record (the conversation and the commands that were run) is the reference, not
the narrative.

**It stated a number it hadn't measured.** While writing `FINDINGS.md`, it claimed that converting
refunds at the refund-date FX rate instead of the order-date rate would move Q2 by "cents to a few
dollars". When it re-checked its own claims before handing over, it ran the query: **$9.60**. The
conclusion survived (immaterial), but the sentence had been a guess presented as a finding, which
the brief scores at zero. The rule that caught it: every number in `FINDINGS.md` must trace to a
query that was actually run.

**A wrong hypothesis that never became a finding.** `fx_rates` had fewer Thursday/Friday rows (525)
than Monday rows (530). The first read was "missing holiday rates", which would have meant some
weekday orders also get no FX. A full weekday-calendar scan found zero missing business days; the
date range just contains one fewer Thursday and Friday.

**A subagent's count was mislabelled.** The blind reproduction agent reported "8,736 USD orders in
Q2". Re-running its script and querying the data showed that 8,736 is *rows*: it includes the
duplicated March copies and every status. The distinct USD orders number 7,362. Its final number was
right; the supporting fact was not. Subagent reports were treated as claims to re-run, not as
results.

**It wrote a test that hung the build.** Hardening `t12` with the audit agent's "orders before
signup" marker, the agent first wrote a correlated `EXISTS` over `raw_orders` with no index on
`player_id`: about 100k × 112k comparisons. Verification ran for over 5 minutes before it was
stopped. The test was rewritten as one aggregated join, and the full `bin/run.py` now takes about
11 s. It was caught only because every change was verified in a clean copy before committing,
instead of being assumed fine because it was "just a test".

**The structural guard:** the independent recompute. Had the agent mis-modelled a policy rule in
SQL, the Python version (written from the policy, not from the SQL) would disagree, and
`bin/run.py` would fail.

## 4. Parallel agents, subagents, worktrees

**Discovery and the fix ran on one agent, sequentially.** The discovery was a chain: the fan-out had
to be understood before the duplicates could be priced, and both before FX. Splitting a chain
across agents just makes each one rebuild the same context.

**Verification ran on three parallel subagents, each blind in a different way.** Parallel agents
that read the same files and the same conclusions agree for the wrong reason. So each one was cut
off from exactly the information that would have biased it.

| Agent | Allowed to see | Not allowed to see | Mandate | What came back |
|---|---|---|---|---|
| **Blind reproducer** | `REVENUE_POLICY.md`, `HANDOVER.md`, `data/*.csv` | `models/`, `analysis/`, `tests/`, FINDINGS, the expected number | Compute FY2026 Q2 from the policy alone | **$328,697.94, matching every title to the cent.** It independently found the duplicates, the USD≠1 rate and the QA accounts, using `Decimal` arithmetic. That makes three implementations, two of them blind to each other. |
| **Policy auditor** | policy, `models/`, `tests/`, the built DB | FINDINGS, `analysis/` | Map every policy sentence to code and test; find violations | **No violations.** Five weak tests, all fixed: `t08` inner join hid orphan orders, `t12` used the same marker as the model, nothing tested the leadership mart (new `t16`), `t13` ignored the quarter label, and the bare-`GROUP BY` dedupe kept an arbitrary copy. It also contributed a second internal-account marker (orders placed before signup). |
| **Defect hunter** | data, the built DB, a list of the known defects | FINDINGS, `analysis/` | Find what the first pass missed | **No new revenue defect** across ~20 hypotheses (SKU vs title, pre-launch orders, refund timing, price sanity…). Three reporting risks, now in FINDINGS: double-counting revenue by studio (+$106k), timezone sensitivity (<$400) and no `ingested_at` on refunds. |

**How the work was split, and why it's safe:**
- Every agent was read-only on the repo. Scratch work went to throwaway directories, and `data/` was
  never writable. No worktrees: the branch had uncommitted work, and a worktree from `HEAD` would
  have audited the *old* pipeline.
- The agents ran in the background while the main session kept working. The DB rebuild was held
  until the last agent finished, because `build.py` deletes `warehouse.db` while they were still
  querying it.
- **Nothing an agent reported went in unverified.** Each claim used in FINDINGS was re-run by the
  main session: the blind script was executed, and the studio, timezone and pre-signup numbers were
  re-queried. One label was wrong (§3).

**What I'd add with more time:** a dbt port as a fourth implementation, and a cash/settlement view
built by an agent that sees only the policy's "Settlement" section.
