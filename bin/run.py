#!/usr/bin/env python3
"""Build the warehouse, run SQL assertions, and print the FY2026 Q2 result."""
import os
import sqlite3
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "build", "warehouse.db")

subprocess.run([sys.executable, os.path.join(ROOT, "bin", "build.py")], check=True)
subprocess.run([sys.executable, os.path.join(ROOT, "bin", "test.py")], check=True)

with sqlite3.connect(DB) as con:
    rows = con.execute("""
        SELECT t.title_name, ROUND(SUM(f.net_usd), 2) AS net_usd
        FROM fact_order f
        JOIN dim_title t ON t.title_id = f.title_id
        WHERE f.order_date BETWEEN '2026-01-01' AND '2026-03-31'
        GROUP BY t.title_id, t.title_name
        ORDER BY t.title_id
    """).fetchall()
    total = con.execute("""
        SELECT ROUND(SUM(net_usd), 2)
        FROM fact_order
        WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
    """).fetchone()[0]

print("FY2026 Q2 net revenue (USD)")
for title, amount in rows:
    print(f"  {title}: {amount:,.2f}")
print(f"  TOTAL: {total:,.2f}")
