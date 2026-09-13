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
    "CREATE INDEX IF NOT EXISTS ix_raw_orders_id  ON raw_orders(order_id, ingested_at DESC)",
    "CREATE INDEX IF NOT EXISTS ix_raw_players_id ON raw_players(player_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_items_id   ON raw_order_items(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_refunds_id ON raw_refunds(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_raw_fx         ON raw_fx_rates(currency_code, rate_date)",
    "CREATE INDEX IF NOT EXISTS ix_raw_fees       ON raw_platform_fees(platform_code, effective_from)",
]

def batches(rows, batch_size=10_000):
    while True:
        batch = []
        for _ in range(batch_size):
            try:
                batch.append(next(rows))
            except StopIteration:
                break
        if not batch:
            return
        yield batch


def load_raw(con):
    for fn in sorted(os.listdir(DATA)):
        if not fn.endswith(".csv"):
            continue
        table = "raw_" + fn[:-4]
        with open(os.path.join(DATA, fn), newline="") as f:
            r = csv.reader(f)
            cols = next(r)
            con.execute(f"DROP TABLE IF EXISTS {table}")
            con.execute(f"CREATE TABLE {table} ({', '.join(c + ' TEXT' for c in cols)})")
            row_count = 0
            for batch in batches(r):
                con.executemany(f"INSERT INTO {table} VALUES ({', '.join('?' * len(cols))})", batch)
                row_count += len(batch)
        print(f"  loaded {table:<28} {row_count:>8,} rows")
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

def main():
    os.makedirs(BUILD, exist_ok=True)
    if "--keep" not in sys.argv and os.path.exists(DB):
        os.remove(DB)
    con = sqlite3.connect(DB)
    if "--keep" not in sys.argv:
        print("loading raw layer")
        load_raw(con)
    print("running models")
    run_models(con)
    con.close()
    print(f"\nbuilt {os.path.relpath(DB, ROOT)}")

if __name__ == "__main__":
    main()
