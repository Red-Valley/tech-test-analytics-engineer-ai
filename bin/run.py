#!/usr/bin/env python3
"""Rebuild, validate, and report FY2026 Q2 revenue from a clean checkout."""
import os
import sqlite3
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "build", "warehouse.db")


def run_script(filename):
    subprocess.run([sys.executable, os.path.join(ROOT, "bin", filename)], check=True)


def main():
    run_script("build.py")
    run_script("test.py")

    con = sqlite3.connect(DB)
    rows = con.execute("""
        SELECT t.title_name, ROUND(SUM(f.net_usd), 2) AS net_revenue_usd
        FROM fact_order f
        JOIN dim_date d ON d.date = f.order_date
        JOIN dim_title t ON t.title_id = f.title_id
        WHERE d.fiscal_year = 'FY2026'
          AND d.fiscal_quarter_no = 2
        GROUP BY t.title_name
        ORDER BY t.title_name
    """).fetchall()
    total = con.execute("""
        SELECT ROUND(SUM(f.net_usd), 2)
        FROM fact_order f
        JOIN dim_date d ON d.date = f.order_date
        WHERE d.fiscal_year = 'FY2026'
          AND d.fiscal_quarter_no = 2
    """).fetchone()[0]
    con.close()

    print("\nFY2026 Q2 net revenue (USD)")
    for title_name, net_revenue_usd in rows:
        print(f"  {title_name:<28} {net_revenue_usd:>12,.2f}")
    print(f"  {'TOTAL':<28} {total:>12,.2f}")


if __name__ == "__main__":
    main()
