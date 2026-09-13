# Revenue findings

## Corrected result

FY2026 Q2 is 2026-01-01 through 2026-03-31 (the fiscal year starts on 1 October).
The corrected **net revenue is USD 318,550.72**:

| Title | FY2026 Q2 net revenue (USD) |
|---|---:|
| T-01 | 143,903.20 |
| T-02 | 46,743.25 |
| T-03 | 27,041.07 |
| T-04 | 44,306.21 |
| T-05 | 56,557.00 |
| **Total** | **318,550.72** |

The delivered pipeline produced USD 727,922.09, so it was **USD 409,371.36 (128.51%) too high** relative to the corrected result. The delivered number was high even though the exact-date FX defect omitted weekend conversions: order/item multiplication and duplicate source rows dominated that omission.

## Defect table

The amounts below are FY2026 Q2 USD. To avoid double-counting, each row is the sequential change from a SQL variant that includes the preceding fixes. The first three rows intentionally use the old current business rules (exact-date FX, globally latest fee, status-only refund handling, and pending/test orders included), so they isolate the source duplication and fact-grain defects before the remaining fixes are applied. Percentages are impact divided by corrected Q2 revenue; positive and negative impacts therefore may offset.

| What was wrong | How found it | What it was worth (USD and %) | Fix |
|---|---|---:|---|
| The March outage created 2,957 duplicate `order_id` rows. | Starting with old raw orders + raw item lines and item-grain revenue produced **USD 727,922.0871083513**. Deduplicating orders only (leaving raw item lines and item-grain revenue) produced **USD 547,233.4582313113**, a sequential delta of **-USD 180,688.6288770403** (rounded **-180,688.63; -56.72%**). | **-180,688.63 (-56.72%)** | Deterministic order staging deduplication and conflict handling. |
| The March outage created 4,392 duplicate `(order_id,line_no)` item rows. | From the order-deduplicated variant, deduplicating item lines (while retaining item-grain revenue) produced **USD 456,889.1437927913**, a sequential delta of **-USD 90,344.3144385203** (rounded **-90,344.31; -28.36%**). | **-90,344.31 (-28.36%)** | Deterministic item staging deduplication and conflict handling. |
| The fact joined order measures at item grain, multiplying each order's financial measures by its item count. | From the order- and item-deduplicated item-grain variant, changing the fact to one row per order produced **USD 236,197.3452986397**, a sequential delta of **-USD 220,691.7984941517** (rounded **-220,691.80; -69.28%**). | **-220,691.80 (-69.28%)** | Keep item detail separate and build a one-row-per-order financial fact. |
| Pending orders were included by the old net expression. | Compared Q2 variants with and without `order_status IN ('completed','refunded')`. | **-3,268.48 (-1.03%)** | Exclude pending orders from `fact_order`. |
| Internal/test accounts (`twinhearth.test`) were reported. | Joined fact players to the player dimension; 10 source players matched the domain. | **-18,936.48 (-5.94%)** | Exclude the domain from the reportable financial fact. |
| Partial refunds in `raw_refunds` were ignored; full refunds were inferred from status. | Aggregated refund rows by canonical order and compared with the old status-only result. Q2 has 1,231 refund orders (465 fully refunded). | **-4,064.76 (-1.28%)** | Aggregate the refund system of record by order, convert at the original order-date rate, and calculate the residual once. |
| Non-USD weekend orders had no exact-date FX row. | Compared exact-date and latest-`rate_date <= order_date` conversions; business-day rates have 528 rows per currency. | **+122,770.92 (+38.54%)** | Use an as-of FX lookup. |
| The old fee lookup chose the globally latest rate instead of the rate effective on the order date. | Checked the STEAM and XBOX contract boundaries against order dates. | **-14,147.82 (-4.44%)** | Join effective-dated fee rows (`effective_from <= order_date` and open/end-inclusive `effective_to`). |
| `dim_date` used SQLite's negative remainder for October-based fiscal months. | Tested FY2026 Q2 and the Dec/Apr boundaries. | **0.00 (0.00%)** | Use a non-negative month offset before calculating fiscal quarter/month. |
These three sequential impacts are intentionally not additive as independent effects: the duplicate order and duplicate item extracts overlap, and the item-grain multiplication acts on whichever rows remain after each deduplication. Their ordered changes nevertheless reconcile the old raw/item-grain total to the pre-scope/pre-policy one-row-per-order variant.


The rounded sequential impacts sum to USD -409,371.36, matching delivered less corrected (unrounded totals were used for the calculation).

## Smaller-than-expected impact

Refund handling looked likely to be a major Q2 swing because the source contains both partial and full refunds. Once duplicate orders/items were removed and the refund table was aggregated, fixing refunds changed Q2 by only **USD 4,064.76 (1.28% of corrected revenue)**. This is measured from the canonical, scoped, status-filtered variant: the old logic already captured the full-refund population, while the Q2 partial-refund residual was comparatively small. The regression test still protects it because omitting partial refunds is a policy violation regardless of this quarter's size.

## Not fixed and triage rationale

Settlement timing remains intentionally unresolved. The handover says delays vary by store (30–60 days), but no schedule or source field supplies those delays. Revenue is recognised on order date under the policy, so settlement cannot affect `net_usd`; `fact_order.settlement_date` is retained as `NULL` for compatibility rather than presenting a fabricated `+30 day` value. In a three-hour repair, inventing a schedule would make cash reporting less trustworthy than explicitly leaving it unavailable. Incremental loading and orchestration also remain out of scope per the assessment; the full rebuild is deterministic and the landing files remain untouched.

## Reproduction method

From a clean checkout, run:

```bash
python3 bin/run.py
```

This rebuilds `build/warehouse.db`, verifies the SQL assertions (including money and grain regressions), and prints the title rows and total above. Existing `python3 bin/build.py` followed by `python3 bin/test.py` commands remain supported.
