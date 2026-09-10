#!/usr/bin/env python3
"""Print FY2026 Q2 net revenue by title and total from build/warehouse.db.

    python3 bin/build.py && python3 bin/report.py
"""
import os, sqlite3, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "build", "warehouse.db")

def main():
    if not os.path.exists(DB):
        sys.exit("no build/warehouse.db - run python3 bin/build.py first")
    con = sqlite3.connect(DB)
    rows = con.execute("""
        SELECT t.title_name, ROUND(SUM(f.net_usd), 2) AS net_usd
        FROM fact_order f
        JOIN dim_date d  ON d.date = f.order_date
        JOIN dim_title t ON t.title_id = f.title_id
        WHERE d.fiscal_year = 'FY2026' AND d.fiscal_quarter_no = 2
        GROUP BY t.title_name
        ORDER BY net_usd DESC
    """).fetchall()
    print("FY2026 Q2 net revenue, by title:\n")
    total = 0.0
    for title, net in rows:
        print(f"  {title:<28} ${net:>12,.2f}")
        total += net
    print(f"  {'-'*28} {'-'*13}")
    print(f"  {'TOTAL':<28} ${total:>12,.2f}")

if __name__ == "__main__":
    main()
