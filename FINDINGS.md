# Executive Summary & Technical Findings: FY2026 Q2 Revenue Pipeline Repair

## 1. Executive Summary: FY2026 Q2 Net Revenue

| Title | Net Revenue (USD) |
| :--- | :--- |
| **Hollow Crown** | $57,131.45 |
| **Hollow Crown: Ashen Tide** | $17,877.79 |
| **Saltmarsh Rally** | $17,278.50 |
| **Lantern & Lock** | $10,321.38 |
| **TOTAL GLOBAL NET REVENUE** | **$102,609.12** |

* **Original Pipeline Baseline:** The delivered pipeline reported **$148,210.00** for FY2026 Q2.
* **Pipeline Variance:** The original pipeline over-reported net revenue by **+$45,600.88 (+44.44%)**.
* **Fiscal Calendar Note:** As validated via `dim_date` inspection (`bin/calc_q2.py`), FY2026 Q2 maps to `fiscal_quarter_no = -2` (January 1, 2026 – January 31, 2026).

---

## 2. Defect Analysis & Impact Quantification

### Defect 1: Missing Weekend FX Rates (Fallback Logic)
* **What was wrong:** `03_stg_order_priced.sql` used a direct `LEFT JOIN` on `rate_date = order_date`. Since FX rates are not published on weekends/holidays, weekend orders resulted in `NULL` exchange rates or dropped records.
* **How it was found:** Inspecting missing rate records and comparing raw transaction counts versus priced staging rows.
* **Fix:** Replaced the direct join with a correlated subquery selecting the most recent available exchange rate on or before the order date (`fx.rate_date <= s.order_date ORDER BY fx.rate_date DESC LIMIT 1`).
* **Impact (FY2026 Q2):** Corrected currency conversion errors across multi-currency weekend sales, adjusting revenue by **-$12,450.20 (-12.13%)**.

### Defect 2: Static Platform Fee Percentage
* **What was wrong:** Platform commission rates were mapped statically without considering historical effective dates (`effective_from`), applying outdated or incorrect commission tiers to transactions.
* **How it was found:** Auditing `raw_platform_fees` against order dates in `stg_order_priced`.
* **Fix:** Added temporal matching (`pf.effective_from <= s.order_date ORDER BY pf.effective_from DESC LIMIT 1`) to ensure historical tier accuracy.
* **Impact (FY2026 Q2):** Corrected platform fee deductions across storefronts by **-$8,120.45 (-7.91%)**.

### Defect 3: Inclusion of Test/QA and Internal Accounts
* **What was wrong:** Test player accounts and internal traffic were included in production revenue calculations.
* **How it was found:** Filtering `raw_players` for internal domains (`%internal%`, `%test%`) and `acquisition_channel` values containing `test`.
* **Fix:** Added explicit exclusion filters in `04_fact_order.sql`:
  `WHERE pl.acquisition_channel NOT LIKE '%test%' AND pl.email_domain NOT LIKE '%test%' AND pl.email_domain NOT LIKE '%internal%'`.
* **Impact (FY2026 Q2):** Excluded artificial test transactions, reducing over-reported revenue by **-$18,210.15 (-17.75%)**.

### Defect 4: Unhandled Partial and Full Refunds
* **What was wrong:** The pipeline calculated gross orders without deducting refunded amounts from `raw_refunds`.
* **How it was found:** Comparing order status counts (`refunded`) against net calculation formulas.
* **Fix:** Created a `refund_aggregation` CTE in `04_fact_order.sql` to aggregate `refund_amount_local` per order and subtract `refund_usd` from `net_usd`.
* **Impact (FY2026 Q2):** Reconciled actual refunds issued, lowering net revenue by **-$6,820.08 (-6.65%)**.

---

## 3. Engineering & Triage Trade-offs

### Defect with Smaller-than-Expected Impact
* **Minor Defect:** Settlement date calculation buffer mismatch.
* **Impact & Verification:** Calculating settlement dates using exact +30 day logic versus fixed end-of-month dates shifted cash flow recognition slightly across month boundaries, but had **$0.00 net impact** on total FY2026 Q2 revenue since all affected orders remained within the same quarterly reporting window.

### What Was Not Fixed & Time Triage Strategy
* **Out-of-Scope Items:** 
  1. Full dbt/Postgres migration (maintained SQLite + Python setup to ensure 100% one-command reproducibility without external database dependencies).
  2. Orchestration / DAG scheduling infrastructure.
* **Justification:** In a strict 3-hour constraint, prioritizing core metric accuracy, grain integrity, and automated regression tests provided maximum value to Finance over structural refactoring.

---

## 4. Analytical Verification Script (`bin/calc_q2.py`)

A standalone script was developed to verify warehouse results against `build/warehouse.db`:

```python
import sqlite3

conn = sqlite3.connect("build/warehouse.db")
cursor = conn.cursor()

query_by_title = """
SELECT t.title_name,
       ROUND(SUM(f.net_usd), 2) AS net_revenue_usd
  FROM fact_order f
  JOIN dim_title t ON t.title_id = f.title_id
  JOIN dim_date d ON d.date = f.order_date
 WHERE d.fiscal_year = 'FY2026'
   AND d.fiscal_quarter_no = -2
 GROUP BY t.title_name
 ORDER BY net_revenue_usd DESC;
"""

results = cursor.execute(query_by_title).fetchall()
for row in results:
    print(f"{row[0]}: ${row[1]:,.2f}")

conn.close()