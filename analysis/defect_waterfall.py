#!/usr/bin/env python3
"""Independent re-implementation of FY2026 Q2 net revenue, straight from data/*.csv, plus a
defect-by-defect price list.

Deliberately shares NO code with models/*.sql: pure Python over the landing CSVs. If this and the
warehouse agree to the cent, the number is not an artefact of one implementation.

Two views of what each defect was worth:
  * waterfall  - start from the delivered pipeline's logic, fix one defect at a time in a fixed
                 order; each step's delta is that fix's contribution. Steps sum exactly to the gap.
  * isolated   - start from the CORRECT logic, re-introduce one defect alone; the delta is what
                 that defect would cost on its own. Isolated deltas need not sum to the gap,
                 because defects interact (e.g. fan-out multiplies every other error).

    python3 analysis/defect_waterfall.py          # prints both tables
"""
import bisect, csv, os, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
Q_START, Q_END = "2026-01-01", "2026-03-31"   # FY2026 Q2 (FY starts 1 Oct)


def rows(name):
    with open(os.path.join(DATA, name + ".csv"), newline="") as f:
        return list(csv.DictReader(f))


raw_orders = rows("orders")
items_per_order = defaultdict(int)          # raw line count, duplicates included (what the old join saw)
for it in rows("order_items"):
    items_per_order[it["order_id"]] += 1
refund_local = defaultdict(float)
for r in rows("refunds"):
    refund_local[r["order_id"]] += float(r["refund_amount_local"])
internal = {p["player_id"] for p in rows("players") if p["email_domain"].lower().startswith("twinhearth.")}

fx = defaultdict(dict)                      # currency -> {date: rate}
for r in rows("fx_rates"):
    fx[r["currency_code"]][r["rate_date"]] = float(r["rate_to_usd"])
fx_dates = {c: sorted(d) for c, d in fx.items()}

fees = defaultdict(list)                    # platform -> [(from, to, pct)]
for r in rows("platform_fees"):
    fees[r["platform_code"]].append((r["effective_from"], r["effective_to"] or "9999-12-31", float(r["fee_pct"])))


def fx_exact(ccy, d):                       # old: same-day join, USD row from the file
    return fx[ccy].get(d)


def fx_asof(ccy, d):                        # policy: last published rate on or before d
    ds = fx_dates[ccy]
    i = bisect.bisect_right(ds, d) - 1
    return fx[ccy][ds[i]] if i >= 0 else None


def fee_latest(p):                          # old: most recent effective_from, whatever the order date
    return max(fees[p])[2]


def fee_asof(p, d):                         # policy: rate in force on the order date
    return next(pct for f, t, pct in fees[p] if f <= d <= t)


DEFECTS = [
    ("D1", "fan-out: fact joined to order_items, gross repeated per line"),
    ("D2", "March 2026 re-land: duplicate orders counted twice"),
    ("D3", "pending (never completed) orders counted as revenue"),
    ("D4", "internal / QA accounts (@twinhearth.test) not excluded"),
    ("D5", "FX same-day join: weekend orders get NULL and silently drop out of SUM"),
    ("D6", "USD orders 'converted' with a USD->USD rate that is not 1"),
    ("D7", "platform fee: latest rate applied to all history, not rate on order date"),
    ("D8", "partial refunds on completed orders ignored"),
]


def net_revenue(fixed, by_title=False):
    """Net revenue for FY2026 Q2 with the given set of defects fixed (others left as delivered)."""
    seen, total = set(), defaultdict(float)
    for o in raw_orders:
        d = o["order_ts"][:10]
        if not (Q_START <= d <= Q_END):
            continue
        oid, status = o["order_id"], o["order_status"]
        if "D2" in fixed:
            if oid in seen:
                continue
            seen.add(oid)
        if "D3" in fixed and status == "pending":
            continue
        if "D4" in fixed and o["player_id"] in internal:
            continue
        ccy, g = o["currency_code"], float(o["gross_amount_local"])
        if ccy == "USD" and "D6" in fixed:
            rate = 1.0
        else:
            rate = fx_asof(ccy, d) if "D5" in fixed else fx_exact(ccy, d)
        if rate is None:                    # NULL * anything = NULL, and SUM() skips it
            continue
        fee = fee_asof(o["platform_code"], d) if "D7" in fixed else fee_latest(o["platform_code"])
        if "D8" in fixed:
            net = (g - refund_local.get(oid, 0.0)) * rate * (1 - fee)
        else:                               # old: status flag only
            net = 0.0 if status == "refunded" else g * rate * (1 - fee)
        if "D1" not in fixed:
            # the old join emitted one row per RAW line; a duplicated order's lines are duplicated
            # too, and each copy of the header joined to every copy of the lines.
            net *= items_per_order[oid]
        total[o["title_id"] if by_title else "ALL"] += net
    return total if by_title else total["ALL"]


def main():
    all_ids = {k for k, _ in DEFECTS}
    delivered = net_revenue(set())
    correct = net_revenue(all_ids)

    print(f"FY2026 Q2 net revenue (independent recompute from data/*.csv)\n")
    print(f"  delivered pipeline logic : {delivered:>14,.2f}")
    print(f"  policy-correct           : {correct:>14,.2f}")
    print(f"  gap                      : {delivered - correct:>+14,.2f}  ({(delivered - correct) / correct:+.1%} vs correct)\n")

    print("By title (policy-correct):")
    for t, v in sorted(net_revenue(all_ids, by_title=True).items()):
        print(f"  {t}  {v:>14,.2f}")
    print()

    print(f"{'':4}{'defect':<76}{'waterfall USD':>15}{'% of correct':>14}{'isolated USD':>15}{'% of correct':>14}")
    fixed, prev = set(), delivered
    for k, label in DEFECTS:
        fixed.add(k)
        cur = net_revenue(fixed)
        step = prev - cur                    # + means the defect overstated revenue
        iso = net_revenue(all_ids - {k}) - correct
        print(f"{k:<4}{label:<76}{step:>+15,.2f}{step / correct:>+14.2%}{iso:>+15,.2f}{iso / correct:>+14.2%}")
        prev = cur
    print(f"{'':4}{'sum of waterfall steps':<76}{delivered - prev:>+15,.2f}")
    assert abs(prev - correct) < 1e-6


if __name__ == "__main__":
    sys.exit(main())
