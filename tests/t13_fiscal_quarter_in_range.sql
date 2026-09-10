-- fiscal_quarter_no must always be 1-4 (the old negative-modulo math produced negative quarters for every calendar month Jan-Sep)
SELECT date, fiscal_quarter_no FROM dim_date WHERE fiscal_quarter_no NOT BETWEEN 1 AND 4;
