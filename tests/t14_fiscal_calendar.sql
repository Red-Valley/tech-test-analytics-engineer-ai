-- fiscal calendar must follow an October-start fiscal year

WITH expected AS (
    SELECT
        date,
        fiscal_year,
        fiscal_quarter_no,
        fiscal_month_no,

        'FY' ||
        CASE
            WHEN calendar_month >= 10
                THEN calendar_year + 1
            ELSE calendar_year
        END AS expected_fiscal_year,

        CASE
            WHEN calendar_month BETWEEN 10 AND 12 THEN 1
            WHEN calendar_month BETWEEN 1 AND 3 THEN 2
            WHEN calendar_month BETWEEN 4 AND 6 THEN 3
            WHEN calendar_month BETWEEN 7 AND 9 THEN 4
        END AS expected_fiscal_quarter_no,

        CASE
            WHEN calendar_month >= 10
                THEN calendar_month - 9
            ELSE calendar_month + 3
        END AS expected_fiscal_month_no

    FROM dim_date
)

SELECT
    date,
    fiscal_year,
    fiscal_quarter_no,
    fiscal_month_no
FROM expected
WHERE fiscal_year <> expected_fiscal_year
   OR fiscal_quarter_no <> expected_fiscal_quarter_no
   OR fiscal_month_no <> expected_fiscal_month_no;