# AI workflow

## Tools and why

- Repository file reads and anchored edits were used to inspect the existing Python/SQLite conventions and make narrow model/test changes without touching `data/`.
- Python's standard-library `sqlite3` and short shell commands were used to profile duplicate keys, reproduce the delivered result, calculate isolated defect deltas, and query the rebuilt warehouse. This kept the result deterministic and independently checkable.
- The existing `bin/build.py` and `bin/test.py` were retained. No LLM or external service is called at runtime.

## Concrete prompts and outcomes

1. **"Inspect the repository models, runners, policy, and existing tests; identify the defects that can change FY2026 Q2 net revenue."** The inspection found the raw order/item duplicate keys, item-grain fact join, exact-date FX join, globally latest fee lookup, status-only refunds, pending rows, test-player domain, and broken fiscal modulo.
2. **"Design a deterministic SQLite staging model that canonicalizes duplicate orders/items and fails closed on conflicting business attributes."** This produced `stg_order`/`stg_order_item` with windowed canonical selection, conflict tables, unique indexes, and a build-time conflict guard.
3. **"Apply the revenue policy to the fact grain: completed real players, refund-table aggregation, order-date FX as-of, effective-dated fees, and one row per order."** The resulting SQL keeps item detail in `fact_order_item` and computes `net_usd = gross_usd - refund_usd - platform_fee_usd` on the residual after refunds.
4. **"Recompute the Q2 result and attribute each defect sequentially, using SQLite queries rather than guesses."** The delivered total was 727,922.09 and the repaired total was 318,550.72; the sequential defect deltas are recorded in `FINDINGS.md`.
5. **"Add regression SQL for every observed failure mode and a one-command build/test/report entrypoint."** Tests `t08`–`t16` and `bin/run.py` were added while preserving the original build/test commands.

## A confidently wrong AI moment

An early generated edit to `04_fact_order.sql` added `gross_local` but accidentally dropped `title_id` from the final projection and duplicated another projection expression. The change looked syntactically plausible, but the first targeted Q2-by-title query failed with `no such column: title_id`. Inspecting the generated SQL and querying `PRAGMA table_info(fact_order)` exposed the mistake; the projection was corrected, the model was rebuilt, and the title totals then reconciled to the independently verified five-title target. This is why the workflow used targeted warehouse queries instead of treating a successful SQL script as proof.

## Agent split

The main coding session assigned this worker the revenue-model, regression-test, runner, and findings/workflow deliverables. The work stayed in the shared checkout; no external service, worktree, or runtime agent dependency was introduced. The parent agent is responsible for final integration and independent verification.
