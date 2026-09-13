# Model design

## Reproducible run

From a clean checkout, run one command:

```bash
python bin/run.py
```

It rebuilds the SQLite warehouse, verifies landing-file checksums, runs all assertions, and prints FY2026 Q2 net revenue by title and in total.

## Grain and layers

`raw_*` tables preserve landing-file records. `stg_order` is one row per business `order_id`, retaining the latest ingested version so replayed extracts cannot duplicate revenue. `stg_order_priced` is one eligible, real-player order enriched with aggregated refunds, effective-dated platform fees, and the latest available FX rate. `fact_order` remains one row per eligible order; it is the only table used for order-level revenue reporting.

`dim_title`, `dim_player`, `dim_platform`, `dim_studio`, and `dim_date` provide reporting dimensions. Order items intentionally do not join `fact_order`: an item-level revenue fact would need an explicit allocation rule before it can carry money.

The source data does not provide the store-specific 30--60 day settlement schedule required for a cash-reporting date. `fact_order` therefore does not publish a fabricated `settlement_date`; revenue is reported solely on `order_date`, as required by Finance.

## Scaling path

The supplied harness remains a full rebuild for portability, but the raw loader now inserts in batches instead of retaining each CSV in memory. Raw indexes support the order-version, FX, refund, and fee lookups. At fifty times the volume with hourly delivery, I would retain immutable raw batches, watermark ingestion by source extract timestamp, merge the latest order version by `order_id`, and recompute only orders affected by late refunds or reference-data changes. Effective-dated FX and fee tables should be snapshotted and indexed by business key plus date. The published fact should be partitioned by `order_date` and rebuilt only for affected partitions.
