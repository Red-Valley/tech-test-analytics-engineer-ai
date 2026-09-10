-- fact_order must not contain the same order_id twice (the March re-ingest landed 2,957 orders a second time)
SELECT order_id, COUNT(*) AS n FROM fact_order GROUP BY order_id HAVING n > 1;
