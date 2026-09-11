# AI Workflow

## 1. Tools used and why

I used **ChatGPT** as the primary AI assistant throughout the assessment.

I used it for five main purposes:

* understanding the repository, Finance policy, existing models, and tests;
* generating investigative SQL and Python queries to test specific hypotheses;
* reviewing model-design decisions and proposing replacement SQL;
* helping structure the defect quantification, reconciliation, and documentation.
* since the repository was public I used it to verify the data and generate the hypotheses for this investigation.

I then deliberately used AI as an investigative partner rather than asking it to rewrite the entire pipeline immediately.

The workflow was:

```text
business rule
→ AI hypothesis
→ query raw data
→ validate or reject hypothesis
→ quantify impact
→ implement fix
→ regression test
```

PowerShell, Python, SQLite, and Git were then used to execute and independently verify the proposed work.

I kept the supplied Python + SQLite stack rather than introducing a heavier tool because it was sufficient for the problem and preserved zero-dependency reproducibility. In case we need to migrate the solution to any other tool AI would also be helpful translating between softwares.

---

## 2. Concrete prompts and outcomes

### Prompt 1 — Understand the assessment before changing anything

> Check this repository [Repository link] and study the whole situation. This is a technical test and they want me to do it with AI; review the README.md and REVENUE_POLICY.md, handover, models, test, data and identify issues in the middle of the process such as but not limited to: FX conversion and treatment, business rules, order exclusions, revenue calculation, item-level duplication.

I then optimized the prompt with Gemini for ChatGPT:
```text
### Role & Context
You are a Lead Data Engineer and Analytics Auditor specializing in revenue accounting, data pipeline integrity, and technical test evaluation. 

I am completing a technical assessment that explicitly encourages the use of AI. Your task is to perform an end-to-end audit of the provided repository to identify logic bugs, policy violations, and pipeline discrepancies.

### Input Material
Repository Link: [Insert Repository Link Here]

### Analysis Scope
Thoroughly inspect the entire codebase and documentation, with primary focus on:
1. Core Documentation: `README.md`, `REVENUE_POLICY.md`, and any handover notes.
2. Implementation Code: All files within `models/`, `tests/`, and pipeline configuration files.
3. Data Artifacts: Sample or target datasets in `data/`.

### Key Areas to Audit
Actively search for subtle and high-impact issues, including but not limited to:
- FX Conversion & Treatment: Misaligned exchange rate dates, missing fallback rates, or improper multi-currency aggregation.
- Business Rule Compliance: Logic that violates explicit requirements in `REVENUE_POLICY.md`.
- Order Exclusions: Incorrect filtering of pending, cancelled, refunded, or test orders.
- Revenue Calculation: Misapplication of net vs. gross revenue, tax handling, shipping fee inclusion, or discount timing.
- Item-Level Duplication: Fan-out issues caused by improper SQL joins (e.g., `1:N` line-item joins) or double-counted adjustments.

### Expected Deliverables
Please structure your analysis into the following distinct sections:

1. Executive Summary: A high-level overview of the repository's health and readiness.
2. Critical Issues Identified: A prioritized list of discovered bugs/discrepancies. For each issue, provide:
   - **Location:** File path and line number(s) or logic block.
   - **Impact:** Why this creates incorrect revenue or policy non-compliance.
   - **Root Cause:** Explanation of why the current implementation fails.
   - **Recommended Fix:** Code or logic remediation.
3. Edge Cases & Risks: Oversights that might not break tests today but pose risks for production data.
4. Next Steps Checklist: Actionable bullet points to resolve all issues before submission.

```
The AI reviewed the repository structure, `README.md`, `REVENUE_POLICY.md`, contractor handover, models, and tests.

It identified several policy/model mismatches before implementation, including:

* exact-date FX instead of last published rate;
* latest platform fee applied historically;
* refunds inferred from order status rather than the refunds table;
* pending orders included;
* internal/test players not excluded;
* order-level revenue joined to item-level rows.

This gave me a prioritized investigation plan instead of immediately changing code.

---

### Prompt 2 — Establish a milestone-based workflow

> Let's tackle it in milestones. Define a workflow before starting and let me know where to check for mistakes.

The AI proposed separating the work into:

1. baseline capture;
2. business-rule audit;
3. raw-data profiling;
4. independent reference calculation;
5. defect-by-defect quantification;
6. model repair;
7. regression testing;
8. clean-checkout reproduction;
9. final documentation.

A useful rule from this phase was that every defect needed the chain:

```text
Finance rule
→ raw evidence
→ failing behavior
→ affected rows
→ dollar impact
→ fix
→ regression test
```

This prevented implementation from getting ahead of evidence.

---

### Prompt 3 — Investigate unexpected fact-row multiplication

After the original tests showed 43,680 fact-grain violations, I asked the AI to help investigate why the revenue fact contained far more rows than business orders.

The first hypothesis was that joining `raw_orders` to `raw_order_items` was multiplying whole-order revenue.

The generated profiling queries then revealed something additional:

* FY2026 Q2 contained 19,480 physical order rows but only 16,523 distinct order IDs;
* exactly 2,957 March order IDs appeared twice;
* all duplicate order versions agreed on business fields;
* their ingestion timestamps showed an initial load and a later replay;
* 4,392 unique item rows for those orders had also been loaded exactly twice.

This established two separate defects:

1. replayed source extraction;
2. legitimate multi-item orders multiplying whole-order revenue.

Each could then be priced separately.

---

### Prompt 4 — Price each defect against the original warehouse

> We need to understand the effect versus the initial revenue, so we shouldn't effect any changes before getting to that to have something to compare with.

This changed the analysis method.

Instead of measuring only sequential fixes, I kept the original delivered FY2026 Q2 result of **$727,922.09** as a frozen baseline.

For each defect I created a counterfactual calculation where only that defect was corrected and all other broken behavior remained unchanged.

Examples:

* wrong fact grain: **$445,484.11 standalone overstatement**;
* missing non-USD as-of FX: **$212,586.04 standalone understatement**;
* test/internal accounts: **$124,264.88 standalone overstatement**;
* historical platform fee: **$33,126.17 standalone overstatement**.

Because these defects interact, I did not add the standalone impacts together.

I separately built a sequential reconciliation that moved exactly from:

```text
$727,922.09
→ $328,697.94
```

and reconciled the full **$399,224.15** difference.

---

### Prompt 5 — Build an independent Finance reference calculation

After the defects had been profiled, I asked the AI to build a read-only calculation directly from the raw tables using the Finance policy rather than the existing models.

The resulting calculation:

* deduplicated replayed orders;
* excluded pending orders;
* excluded `twinhearth.test` accounts;
* used the refunds table;
* treated USD as USD;
* used last-published non-USD FX rates;
* used historical platform fees;
* calculated revenue at one row per order.

Before accepting the number, it checked:

```text
duplicate eligible order IDs = 0
missing FX rates             = 0
missing platform fee rates   = 0
refund amounts > gross       = 0
```

All checks returned zero.

The independent result was:

```text
FY2026 Q2 net revenue = $328,697.94
```

The repaired production models later reproduced exactly the same result.

---

## 3. A moment where the AI was confidently wrong

The clearest example occurred during the initial fact-grain investigation.

After seeing the original grain test fail on 43,680 order IDs, the AI initially attributed the problem primarily to this join:

```sql
JOIN raw_order_items i
  ON i.order_id = p.order_id
```

That explanation was directionally correct but incomplete.

Profiling the raw tables showed that the March extract itself had been replayed:

```text
19,480 Q2 raw order rows
16,523 distinct Q2 order IDs
2,957 duplicate rows
```

All 2,957 duplicated order IDs were March orders, appeared exactly twice, had identical business fields, and had different ingestion timestamps.

The item table had also been replayed:

```text
4,392 unique item rows
8,784 physical item rows
exactly 2 copies of every affected item row
```

This meant the delivered fact could contain both:

```text
source replay multiplication
×
legitimate order-item multiplication
```

For some orders, two replayed order rows joined to duplicated item rows and created four times the row count before even considering legitimate multi-item purchases.

I caught the AI's incomplete diagnosis by checking raw row counts, distinct business keys, ingestion timestamps, and duplicate item groups rather than accepting the first explanation.

That changed both the fix and the defect quantification.

---

## 4. Parallel agents / subagents

I did not use parallel agents, subagents, or worktrees.

I intentionally kept the investigation sequential because many of the defects interacted financially.

The workflow was:

```text
identify one hypothesis
→ inspect raw evidence
→ quantify it
→ freeze the finding
→ move to the next rule
```

This made it easier to distinguish standalone defect impacts from sequential reconciliation effects and reduced the risk of two agents silently correcting the same defect in different ways.

---

## 5. How AI output was validated

I did not treat generated SQL or explanations as authoritative.

Important claims were checked against one or more of:

* distinct key counts;
* source row counts;
* ingestion timestamps;
* exact duplicate comparisons;
* order-level spot checks;
* Finance policy language;
* counterfactual revenue calculations;
* additive reconciliation;
* rebuilt model outputs;
* regression tests.

The strongest control was an independent reference calculation built directly from the raw landing tables.

After repairing the models, I deleted the generated warehouse and ran:

```bash
python bin/run.py
```

from scratch.

The result was:

```text
14/14 checks passing

FY2026 Q2 net revenue = $328,697.94
```

matching the independent Finance reference exactly.

---

## 6. Where AI was most useful

AI was most valuable for accelerating hypothesis generation and producing focused investigative queries.

The highest-value use was not code generation itself. It was shortening the loop between:

```text
"this looks suspicious"
```

and:

```text
"here is the raw-data evidence, affected population, dollar impact, fix, and regression test."
```

Note: This was possible due to the AI having access to the repository data, if the data was private (Like HIPPA secured) I wouldn't be able to follow this flow or would have to add extra steps for manual verification - I also had to work with AI and show how I did it so I tried to rely on it as much as I could double checking the code/hypotheses/outputs that it provided.

The assessment also demonstrated why AI output still requires verification: the initial grain diagnosis was plausible but incomplete until raw-data profiling exposed the replayed extract.
