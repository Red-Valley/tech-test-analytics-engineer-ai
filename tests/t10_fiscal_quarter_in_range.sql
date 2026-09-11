-- fiscal_quarter_no must always be 1-4; a value outside that range means the
-- fiscal calendar math is broken (regression test for the negative-modulo bug)
SELECT date, fiscal_quarter_no FROM dim_date
WHERE fiscal_quarter_no NOT IN (1, 2, 3, 4);
