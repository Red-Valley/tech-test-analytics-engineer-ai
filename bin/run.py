#!/usr/bin/env python3
"""Rebuild the warehouse, run all tests, and print FY2026 Q2 corrected net revenue."""

import os
import sqlite3
import subprocess
import sys


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "build", "warehouse.db")


def run(command):
    subprocess.run(
        command,
        cwd=ROOT,
        check=True,
    )


def print_q2_revenue():
    con = sqlite3.connect(DB)

    rows = con.execute(
        """
        SELECT
            t.title_id,
            t.title_name,
            COUNT(*) AS orders,
            ROUND(SUM(f.net_usd), 2) AS net_usd
        FROM fact_order f
        JOIN dim_title t
          ON t.title_id = f.title_id
        JOIN dim_date d
          ON d.date = f.order_date
        WHERE d.fiscal_year = 'FY2026'
          AND d.fiscal_quarter_no = 2
        GROUP BY
            t.title_id,
            t.title_name
        ORDER BY t.title_id
        """
    ).fetchall()

    total = con.execute(
        """
        SELECT
            COUNT(*) AS orders,
            ROUND(SUM(f.net_usd), 2) AS net_usd
        FROM fact_order f
        JOIN dim_date d
          ON d.date = f.order_date
        WHERE d.fiscal_year = 'FY2026'
          AND d.fiscal_quarter_no = 2
        """
    ).fetchone()

    con.close()

    print("\nFY2026 Q2 net revenue")
    print("-" * 60)

    for title_id, title_name, orders, net_usd in rows:
        print(
            f"{title_id:<5} "
            f"{title_name:<30} "
            f"{orders:>6,} orders  "
            f"${net_usd:>12,.2f}"
        )

    print("-" * 60)
    print(
        f"{'TOTAL':<36} "
        f"{total[0]:>6,} orders  "
        f"${total[1]:>12,.2f}"
    )


def main():
    print("=== Building warehouse ===")
    run([sys.executable, "bin/build.py"])

    print("\n=== Running tests ===")
    run([sys.executable, "bin/test.py"])

    print_q2_revenue()


if __name__ == "__main__":
    main()