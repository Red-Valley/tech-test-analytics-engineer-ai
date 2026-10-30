# Data & Analytics Engineer (AI) — Technical Assessment

**Time limit:** 3 hours max.

---

## Context

**Twin Hearth Studios** publishes five titles across five storefronts. Revenue lands in a warehouse
that a contractor built and then left. The pipeline runs. The tests are green enough that nobody
looked closely.

Finance stopped using the warehouse in April. They keep their own spreadsheet now, and the reason
they gave was *"the numbers don't feel right."* Nobody has been able to turn that into a defect
report, which is why the number the warehouse reports for **FY2026 Q2 net revenue** is still the
number leadership sees.

Your job is to find out **what that number actually is**, and prove it.

## What you're given

```
data/                    9 landing files, straight from the source systems (read-only)
docs/REVENUE_POLICY.md   how Finance defines revenue. This is the spec.
docs/HANDOVER.md         the departing contractor's notes
models/*.sql             the pipeline as it stands today, runs in filename order
tests/*.sql              the checks the contractor wrote
bin/build.py             loads data/ and runs models/
bin/test.py              runs tests/
```

Run it before you change anything:

```bash
python3 bin/build.py
python3 bin/test.py
```

Write down what you see. That is your starting point.

> `data/` is read-only and checksum-verified. `bin/test.py` refuses to run if a landing file
> changed. Fix the pipeline, not the inputs.

## What to deliver

### 1. A pipeline that produces the right number

Rebuild or repair the models so the warehouse agrees with `docs/REVENUE_POLICY.md`. Someone else
must be able to reproduce your result by running **one command** on a clean checkout.

Design the model as you would for a team that will keep using it: grain, dimensions, and how it
would run tomorrow when the data is fifty times larger and lands hourly.

### 2. Tests that would have caught this

The checks you were given pass on a pipeline that reports revenue wrong. Add the ones that
wouldn't. A test that only fails on data nobody has is not a test — each one you add should be
tied to something that was actually broken here, or to something you decided is worth guarding.

### 3. `FINDINGS.md`

The centrepiece. For every defect you found:

| What was wrong | How you found it | What it was worth (FY2026 Q2, USD and %) | Fix |
|---|---|---|---|

Then, on one page:

- **FY2026 Q2 net revenue, by title, and the total.** The number, stated plainly.
- **How far off the delivered pipeline was**, and in which direction.
- One defect you found whose impact was **smaller than you expected**, and how you know.
- **What you did not fix**, and why that was the right call in three hours.

Numbers with no method behind them score zero. So do methods with no numbers.

**On the three hours.** There is more here than fits, and that is deliberate. Four defects found,
priced and explained beats seven fixed silently. Decide what is worth your time, do that, and use
the last section to say what you left and why — triage is part of what is being graded.

### 4. `AI_WORKFLOW.md`

How you used AI while doing this:

1. Which tool(s) and why.
2. 3–5 concrete prompts and what came back.
3. One moment where the AI was confidently wrong, and how you caught it.
4. If you used parallel agents, subagents or worktrees, how you split the work.

## Tooling

The scaffolding is Python + SQLite so it runs anywhere with no install. **You are not required to
stay on it.** DuckDB, Postgres, dbt, Spark, Fabric notebooks — use what you would actually use, and
say why. If you switch, the one-command rule still applies: a reviewer with a clean checkout and no
account on anything must be able to reproduce your numbers.

Use AI coding tools. This role is graded partly on how well you drive them.

## Out of scope

Orchestration and scheduling, CI, dashboards, auth, infrastructure. Describe what you would do;
don't build it.

## Evaluation

| Area | Weight |
|---|---|
| Correctness of the final revenue numbers, reproducible from a clean checkout | 30% |
| Defect discovery and quantification (`FINDINGS.md`) | 25% |
| Data model and engineering judgment (grain, dimensions, how it scales) | 15% |
| Tests you added, and what they actually protect | 15% |
| Use of AI tools (`AI_WORKFLOW.md`) | 10% |
| One-command reproducibility | 5% |

Two things that sink an otherwise strong submission:

- **A green test run with a wrong number.** Getting the checks to pass is not the task.
- **Edited landing files.** `data/` is the evidence. Changing it is the one unrecoverable mistake.

## How to submit

1. **Fork** this repo.
2. Create branch `submission/<your-name>`.
3. Implement.
4. Open a **Pull Request** to `main` of this repo.
5. In the PR: time spent, how to run it, your FY2026 Q2 number, and the trade-offs you made.

Expect to defend the number live.

## Reproduce the repaired pipeline

From the repository root, run:

```bash
python bin/run.py
```

This rebuilds `build/warehouse.db` from the checksum-verified landing files, runs the
models, and executes all SQL assertions. The revenue fact is one row per order; it
does not allocate order revenue to item lines.
