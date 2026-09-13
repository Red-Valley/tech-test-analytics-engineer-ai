-- reported revenue must originate from completed orders; refunded orders were completed before refunding
SELECT order_id, order_status
FROM fact_order
WHERE order_status NOT IN ('completed', 'refunded');
