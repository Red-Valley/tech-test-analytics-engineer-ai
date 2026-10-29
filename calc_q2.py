import sqlite3

conn = sqlite3.connect("build/warehouse.db")
cursor = conn.cursor()

print("--- TRIMESTRES DISPONIBLES PARA FY2026 ---")
cursor.execute("SELECT DISTINCT fiscal_quarter_no, MIN(date), MAX(date) FROM dim_date WHERE fiscal_year = 'FY2026' GROUP BY fiscal_quarter_no")
for r in cursor.fetchall():
    print(f"Quarter No: {r[0]} | Desde: {r[1]} | Hasta: {r[2]}")

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

print("\n--- INGRESOS NETOS FY2026 Q2 (Quarter -2) POR TÍTULO ---")
results = cursor.execute(query_by_title).fetchall()
for row in results:
    print(f"{row[0]}: ${row[1]:,.2f}")

query_total = """
SELECT ROUND(SUM(f.net_usd), 2) AS total_net_revenue_usd
  FROM fact_order f
  JOIN dim_date d ON d.date = f.order_date
 WHERE d.fiscal_year = 'FY2026'
   AND d.fiscal_quarter_no = -2;
"""

row = cursor.execute(query_total).fetchone()
total = row[0] if row and row[0] is not None else 0.0
print(f"\nTOTAL GLOBAL NET REVENUE (FY2026 Q2): ${total:,.2f}")

conn.close()