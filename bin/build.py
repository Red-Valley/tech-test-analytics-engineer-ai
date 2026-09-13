#!/usr/bin/env python3
"""Load data/*.csv into build/warehouse.db, then run every models/*.sql in filename order.

    python3 bin/build.py            # rebuild from scratch
    python3 bin/build.py --keep     # keep the loaded raw layer, re-run models only
"""
import csv, os, sqlite3, sys, time

ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA   = os.path.join(ROOT, "data")
MODELS = os.path.join(ROOT, "models")
BUILD  = os.path.join(ROOT, "build")
DB     = os.path.join(BUILD, "warehouse.db")

RAW_INDEXES = [
    "CREATE INDEX IF NOT EXISTS ix_raw_orders_id  ON raw_orders(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_players_id ON raw_players(player_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_items_id   ON raw_order_items(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_refunds_id ON raw_refunds(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_fx         ON raw_fx_rates(currency_code, rate_date)",
    "CREATE INDEX IF NOT EXISTS ix_raw_fees       ON raw_platform_fees(platform_code, effective_from)",
]

def load_raw(con):
    for fn in sorted(os.listdir(DATA)):
        if not fn.endswith(".csv"):
            continue
        table = "raw_" + fn[:-4]
        with open(os.path.join(DATA, fn)) as f:
            r = csv.reader(f); cols = next(r); rows = list(r)
        con.execute(f"DROP TABLE IF EXISTS {table}")
        con.execute(f"CREATE TABLE {table} ({', '.join(c + ' TEXT' for c in cols)})")
        con.executemany(f"INSERT INTO {table} VALUES ({', '.join('?' * len(cols))})", rows)
        print(f"  loaded {table:<28} {len(rows):>8,} rows")
    for ddl in RAW_INDEXES:
        con.execute(ddl)
    con.commit()

def run_models(con):
    files = sorted(f for f in os.listdir(MODELS) if f.endswith(".sql"))
    if not files:
        sys.exit("no models found in models/")
    for fn in files:
        t0 = time.time()
        with open(os.path.join(MODELS, fn)) as f:
            con.executescript(f.read())
        con.commit()
        print(f"  ran    {fn:<28} {time.time() - t0:>7.2f}s")

def validate_model_guards(con):
    """Fail the build if source duplicate keys disagree on business values."""
    checks = [
        ("orders", "stg_order_conflicts"),
        ("order items", "stg_order_item_conflicts"),
    ]
    conflicts = []
    for label, table in checks:
        count = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        if count:
            conflicts.append(f"{label}: {count:,} conflicting keys")
    if conflicts:
        raise RuntimeError("conflicting duplicate business keys: " + "; ".join(conflicts))

def main():
    os.makedirs(BUILD, exist_ok=True)
    # Reuse the SQLite file for a rebuild. This is portable on Windows, where
    # removing a database that another reader has open raises PermissionError.
    con = sqlite3.connect(DB)
    if "--keep" not in sys.argv:
        print("loading raw layer")
        load_raw(con)
    run_models(con)
    validate_model_guards(con)
    con.close()
    print(f"\nbuilt {os.path.relpath(DB, ROOT)}")

if __name__ == "__main__":
    main()
