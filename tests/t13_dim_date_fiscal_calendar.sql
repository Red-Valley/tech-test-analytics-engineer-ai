-- dim_date fiscal fields follow the policy: FY starts 1 Oct, Q1=Oct-Dec, Q2=Jan-Mar (D9)
SELECT date, calendar_month, fiscal_year, fiscal_quarter_no, fiscal_month_no
FROM dim_date
WHERE fiscal_quarter_no <> CASE WHEN calendar_month >= 10 THEN 1
                                WHEN calendar_month <= 3  THEN 2
                                WHEN calendar_month <= 6  THEN 3
                                ELSE 4 END
   OR fiscal_month_no   <> (calendar_month + 2) % 12 + 1
   OR fiscal_year       <> 'FY' || (calendar_year + (calendar_month >= 10))
   -- the report filters on the text label, so check it too
   OR fiscal_quarter    <> fiscal_year || '-Q' || fiscal_quarter_no;
