-- Dimensions.
-- Conformed dimensions shared by every fact. All derived from landing tables; no hand-maintained rows.

DROP TABLE IF EXISTS dim_title;
CREATE TABLE dim_title AS
SELECT title_id, title_name, genre, launch_date, lead_studio_id,
       CAST(base_price_usd AS REAL) AS base_price_usd
FROM raw_titles;

DROP TABLE IF EXISTS dim_studio;
CREATE TABLE dim_studio AS
SELECT studio_id, studio_name, region, CAST(founded_year AS INTEGER) AS founded_year
FROM raw_studios;

DROP TABLE IF EXISTS bridge_title_studio;
CREATE TABLE bridge_title_studio AS
SELECT title_id, studio_id, credit_role FROM raw_title_studio_credits;

-- Policy: internal, test and QA accounts are excluded from every reported metric.
-- The only marker in the source is the email domain; staff/QA register with @twinhearth.*.
-- The flag lives on the dimension so every fact and report filters the same way.
DROP TABLE IF EXISTS dim_player;
CREATE TABLE dim_player AS
SELECT player_id, country_code, currency_code, signup_date, acquisition_channel, email_domain,
       CASE WHEN lower(email_domain) LIKE 'twinhearth.%' THEN 1 ELSE 0 END AS is_internal
FROM raw_players;

-- One row per store, from the fee schedule (the contract) unioned with what actually appears on orders.
DROP TABLE IF EXISTS dim_platform;
CREATE TABLE dim_platform AS
SELECT platform_code FROM raw_platform_fees
UNION
SELECT platform_code FROM raw_orders;

-- Platform fee schedule as a type-2 dimension: one row per (store, validity window).
-- effective_to is inclusive; an open-ended row runs to 9999-12-31.
DROP TABLE IF EXISTS dim_platform_fee;
CREATE TABLE dim_platform_fee AS
SELECT platform_code,
       effective_from,
       COALESCE(NULLIF(effective_to, ''), '9999-12-31') AS effective_to,
       CAST(fee_pct AS REAL)                            AS fee_pct
FROM raw_platform_fees;

-- Fiscal year starts on 1 October: FY2026 = 2025-10-01 .. 2026-09-30.
-- Fiscal month: Oct=1 .. Sep=12. Computed as ((m + 2) % 12) + 1 so the operand of % is never
-- negative (SQLite's % keeps the sign of the dividend, which broke the previous version).
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
WITH RECURSIVE d(dt) AS (
    SELECT '2024-09-01'
    UNION ALL
    SELECT date(dt, '+1 day') FROM d WHERE dt < '2027-12-31'
),
m AS (
    SELECT dt, CAST(strftime('%Y', dt) AS INTEGER) AS y, CAST(strftime('%m', dt) AS INTEGER) AS mo
    FROM d
)
SELECT dt                                                   AS date,
       y                                                    AS calendar_year,
       mo                                                   AS calendar_month,
       substr(dt, 1, 7)                                     AS year_month,
       (mo - 1) / 3 + 1                                     AS calendar_quarter,
       'FY' || CASE WHEN mo >= 10 THEN y + 1 ELSE y END     AS fiscal_year,
       ((mo + 2) % 12) / 3 + 1                              AS fiscal_quarter_no,
       ((mo + 2) % 12) + 1                                  AS fiscal_month_no,
       'FY' || CASE WHEN mo >= 10 THEN y + 1 ELSE y END
            || '-Q' || (((mo + 2) % 12) / 3 + 1)            AS fiscal_quarter,
       CASE WHEN strftime('%w', dt) IN ('0','6') THEN 1 ELSE 0 END AS is_weekend
FROM m;

CREATE UNIQUE INDEX ux_dim_date ON dim_date(date);
