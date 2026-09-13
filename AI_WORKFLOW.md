# AI workflow

## Tools and purpose

I used Codex as a pair-programming and analysis assistant. It accelerated repository inspection, SQL hypothesis generation, and the conversion of validated findings into focused tests and documentation. SQLite and the supplied Python harness remained the execution environment and source of truth.

## Representative prompts and outcomes

1. **Prompt:** “Inspect the revenue policy, handover notes, models, and tests. List likely violations of the policy.”  
   **Outcome:** Identified the likely grain, FX, fee, refund, account-scope, and fiscal-calendar risks to validate against the raw tables.
2. **Prompt:** “Profile order uniqueness by month, item cardinality, exact FX coverage, refund shape, and player email domains.”  
   **Outcome:** Found the March replay, multi-item order fanout, weekend FX gaps, partial refunds, and the test domain.
3. **Prompt:** “Write a reference SQL calculation at order grain that follows this revenue policy.”  
   **Outcome:** Produced a candidate query which I ran against SQLite and independently checked by title and total.
4. **Prompt:** “Propose regression assertions for duplicate order replays, effective-dated fees, prior-business-day FX, refunds, and test accounts.”  
   **Outcome:** Produced the basis for `t08` through `t13`; each assertion was then run against the repaired warehouse.
5. **Prompt:** “Draft a concise findings report that distinguishes overlapping defect impacts from the delivered-pipeline variance.”  
   **Outcome:** Provided the structure for `FINDINGS.md`; all numbers were calculated from the local warehouse before inclusion.

## A confident but wrong AI suggestion

The AI confidently proposed changing or restoring files under the source `data/` directory to address a Windows line-ending problem. That was inappropriate because the landing files are evidence and the assessment explicitly makes them read-only. I caught the issue when `bin/test.py` failed its checksum validation. From that point, I gave the AI an explicit constraint: **never modify `data/`; only change models, tests, executable code, and documentation.** The final validation passed the landing-file checksums without changing their source content.

The AI also initially summed title-level rounded values and returned $318,550.73. Recomputing from the unrounded order-level values produced $318,550.72, which is the reported total. This was caught by independently checking the aggregate with decimal arithmetic. It is a reminder that financial rollups need an explicit rounding policy and must not be inferred from displayed subtotals.

## Parallel work

No parallel agents or worktrees were used. The work was kept sequential so each suspected defect could be verified against the raw data before it informed the model or findings report.
