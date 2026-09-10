-- Dimensions. These were the last thing I got working and I think they're fine. -- R.C.

DROP TABLE IF EXISTS dim_title;
CREATE TABLE dim_title AS
SELECT title_id, title_name, genre, launch_date, lead_studio_id, base_price_usd
FROM raw_titles;

DROP TABLE IF EXISTS dim_studio;
CREATE TABLE dim_studio AS
SELECT studio_id, studio_name, region, founded_year FROM raw_studios;

DROP TABLE IF EXISTS bridge_title_studio;
CREATE TABLE bridge_title_studio AS
SELECT title_id, studio_id, credit_role FROM raw_title_studio_credits;

-- Internal/test/QA accounts must be excluded from every reported metric (REVENUE_POLICY.md,
-- "Scope"). twinhearth.test is the only signal available in the landing data: it's the
-- publisher's own domain on the .test TLD (RFC 2606 - reserved for testing, never a real
-- player inbox). Surfaced as a flag here so every downstream model/report can filter on it
-- without re-deriving the rule.
DROP TABLE IF EXISTS dim_player;
CREATE TABLE dim_player AS
SELECT player_id, country_code, currency_code, signup_date, acquisition_channel, email_domain,
       CASE WHEN email_domain = 'twinhearth.test' THEN 1 ELSE 0 END AS is_internal
FROM raw_players;

-- Stub, as the outgoing contractor flagged in HANDOVER.md. No platform attributes beyond the
-- code exist anywhere in the landing data, and nothing in the revenue calc needs one - left
-- alone. See FINDINGS.md ("what I did not fix").
DROP TABLE IF EXISTS dim_platform;
CREATE TABLE dim_platform AS
SELECT DISTINCT platform_code FROM raw_orders;

-- Fiscal year starts on 1 October: FY2026 = 2025-10-01 .. 2026-09-30.
-- fiscal_month_no counts Oct=1 .. Sep=12, and fiscal_quarter_no groups it in 3s: both computed
-- with a CASE instead of "(month - 10) % 12" - SQLite's % keeps the dividend's sign, so for any
-- calendar month before October that expression evaluates negative (e.g. January -> -9 % 12 ->
-- -9), which fed a negative fiscal_quarter_no for every month Jan-Sep. See FINDINGS.md.
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
WITH RECURSIVE d(dt) AS (
    SELECT '2024-10-01'
    UNION ALL
    SELECT date(dt, '+1 day') FROM d WHERE dt < '2026-12-31'
),
months(dt, calendar_month, fiscal_month_no) AS (
    SELECT dt,
           CAST(strftime('%m', dt) AS INTEGER),
           CASE WHEN CAST(strftime('%m', dt) AS INTEGER) >= 10
                THEN CAST(strftime('%m', dt) AS INTEGER) - 9
                ELSE CAST(strftime('%m', dt) AS INTEGER) + 3 END
    FROM d
)
SELECT dt                                                              AS date,
       CAST(strftime('%Y', dt) AS INTEGER)                             AS calendar_year,
       calendar_month                                                  AS calendar_month,
       substr(dt, 1, 7)                                                AS year_month,
       (calendar_month - 1) / 3 + 1                                    AS calendar_quarter,
       'FY' || CASE WHEN calendar_month >= 10
                    THEN CAST(strftime('%Y', dt) AS INTEGER) + 1
                    ELSE CAST(strftime('%Y', dt) AS INTEGER) END       AS fiscal_year,
       (fiscal_month_no - 1) / 3 + 1                                   AS fiscal_quarter_no,
       fiscal_month_no                                                 AS fiscal_month_no,
       CASE WHEN strftime('%w', dt) IN ('0','6') THEN 1 ELSE 0 END     AS is_weekend
FROM months;
