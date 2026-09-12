-- defends defect #2: fact_order must be exactly 1 row per order_id, never inflated by
-- item-level fan-out (t01 only checks fact isn't worse than the landing table, which a
-- duplicated landing row can satisfy trivially -- this checks the real invariant)
SELECT order_id, COUNT(*) AS n
FROM fact_order
GROUP BY order_id
HAVING COUNT(*) <> 1;
