#!/usr/bin/env python3
"""One command, clean checkout -> verified FY2026 Q2 number.

    python3 bin/run.py

1. bin/build.py   load data/ and run models/
2. bin/test.py    data/ checksum + every tests/*.sql assertion
3. cross-check    warehouse vs. an independent pure-Python recompute from data/*.csv
                  (analysis/defect_waterfall.py), per title, to the cent
4. print          FY2026 Q2 net revenue by title and total

Exits non-zero if any step fails. Python 3.8+ standard library only.
"""
import os, sqlite3, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "analysis"))


def step(*args):
    r = subprocess.run([sys.executable, *args], cwd=ROOT)
    if r.returncode:
        sys.exit(f"\nFAILED: {' '.join(args)}")


def main():
    step("bin/build.py")
    print()
    step("bin/test.py")

    import defect_waterfall as ind
    independent = ind.net_revenue({k for k, _ in ind.DEFECTS}, by_title=True)

    con = sqlite3.connect(os.path.join(ROOT, "build", "warehouse.db"))
    rows = con.execute("""
        SELECT title_id, title_name, orders, gross_usd, refund_usd, platform_fee_usd, net_revenue_usd
        FROM rpt_revenue_fiscal_quarter_title
        WHERE fiscal_quarter = 'FY2026-Q2' ORDER BY title_id""").fetchall()

    print("\ncross-check: warehouse vs independent recompute from data/*.csv")
    bad = 0
    for t, _, _, _, _, _, net in rows:
        diff = net - round(independent[t], 2)
        bad += abs(diff) > 0.01
        print(f"  {'OK  ' if abs(diff) <= 0.01 else 'DIFF'} {t}  warehouse {net:>12,.2f}  independent {independent[t]:>12,.2f}")
    if bad or len(rows) != len(independent):
        sys.exit("\nFAILED: warehouse and independent recompute disagree")

    print("\nFY2026 Q2 (2026-01-01 .. 2026-03-31) net revenue, USD")
    print(f"  {'title':<32}{'orders':>8}{'gross':>14}{'refunds':>12}{'platform fee':>14}{'net revenue':>14}")
    tot = [0, 0.0, 0.0, 0.0, 0.0]
    for t, name, n, g, r, f, net in rows:
        print(f"  {t + ' ' + name:<32}{n:>8,}{g:>14,.2f}{r:>12,.2f}{f:>14,.2f}{net:>14,.2f}")
        for i, v in enumerate((n, g, r, f, net)):
            tot[i] += v
    print(f"  {'TOTAL':<32}{tot[0]:>8,}{tot[1]:>14,.2f}{tot[2]:>12,.2f}{tot[3]:>14,.2f}{tot[4]:>14,.2f}")


if __name__ == "__main__":
    main()
