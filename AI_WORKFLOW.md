# AI workflow

## Tools and why

I used codex in VS Code to inspect the SQL models and policy, explain the model
grain and policy rules, draft targeted model/test changes, and review the test
results. The local PowerShell/Python/SQLite tools were used to rebuild the
warehouse, inspect the source data, and independently calculate the delivered
and corrected FY2026 Q2 totals. Keeping calculations local avoided sending
assessment data to external services.

## Prompts and outcomes

1. **“First, establish the current state of the pipeline. Identify the existing data models, transformation dependencies, test coverage, and potential inconsistencies between the implementation and the documented business requirements.…”** — compared each rule with the
   models, existing SQL assertions, and the landing data; identified issues with
   grain, status scope, FX, fees, refunds, player exclusions, and settlement.

2. **“Using the actual SQLite schema, source data, and docs/REVENUE_POLICY.md, determine the formula to calculate the fiscal_quarter_no according with the business rules in the Revenue_Policy File”** — 
   The result allow to use the correct formula to calculate the correct fiscal quater according with the business rules --> 
   "(((CAST(strftime('%m', dt) AS INTEGER) + 2) % 12) / 3) + 1      AS fiscal_quarter_no,"

3. **“Refunds from the registration system”** — proposed aggregating
   refunds by order and applying the fee to the remaining amount; the resulting
   model and regression assertion were then run locally.


## Confidently wrong and verification

The first analysis treated 99 orders as over-refunded after comparing refunds
against gross. That conclusion was wrong: the comparison joined refunds to raw
orders before accounting for repeated ingestions, multiplying refund rows for
duplicated order IDs. I checked the refund IDs and recomputed at one row per order;
the apparent over-refunds were a join-multiplication artifact, not evidence that
the source refunds exceeded gross. I did not cap refunds or alter source data.

## Parallel work

No agents, subagents, or worktrees were used. The investigation, implementation,
and validation were performed sequentially against the local repository.
