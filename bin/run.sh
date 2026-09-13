#!/usr/bin/env bash
# One-command reproduction: build the warehouse, run the checks, print the
# headline number. Run from a clean checkout with:
#
#   bash bin/run.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Some environments expose Python as `python3`, others only as `python`
# (notably Windows installs from python.org). Use whichever exists.
if command -v python3 >/dev/null 2>&1; then
    PY=python3
else
    PY=python
fi

echo "== building warehouse =="
"$PY" bin/build.py

echo
echo "== running checks =="
"$PY" bin/test.py

echo
echo "== FY2026 Q2 net revenue, by title =="
"$PY" - <<'PYEOF'
import sqlite3
con = sqlite3.connect("build/warehouse.db")
cur = con.cursor()
cur.execute("""
    SELECT title_name, completed_orders, ROUND(gross_usd,2), ROUND(refund_usd,2),
           ROUND(platform_fee_usd,2), ROUND(net_revenue_usd,2)
    FROM mart_revenue_by_fiscal_period
    WHERE fiscal_year='FY2026' AND fiscal_quarter_no=2
    ORDER BY net_revenue_usd DESC
""")
rows = cur.fetchall()
print(f"{'title':<28}{'orders':>8}{'gross_usd':>14}{'refund_usd':>13}{'fee_usd':>12}{'net_usd':>14}")
for r in rows:
    print(f"{r[0]:<28}{r[1]:>8}{r[2]:>14,.2f}{r[3]:>13,.2f}{r[4]:>12,.2f}{r[5]:>14,.2f}")
cur.execute("""
    SELECT SUM(completed_orders), SUM(gross_usd), SUM(refund_usd), SUM(platform_fee_usd), SUM(net_revenue_usd)
    FROM mart_revenue_by_fiscal_period WHERE fiscal_year='FY2026' AND fiscal_quarter_no=2
""")
t = cur.fetchone()
print("-" * 89)
print(f"{'TOTAL':<28}{t[0]:>8}{t[1]:>14,.2f}{t[2]:>13,.2f}{t[3]:>12,.2f}{t[4]:>14,.2f}")
PYEOF
