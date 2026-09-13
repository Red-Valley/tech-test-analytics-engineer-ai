-- no settlement date is published without a store-specific settlement schedule
SELECT name
FROM pragma_table_info('fact_order')
WHERE name = 'settlement_date';
