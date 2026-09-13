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

-- FIX: internal/test/QA accounts must be excluded from every reported metric
-- (REVENUE_POLICY.md, "Scope"). They were not flagged anywhere before. The only
-- account-level signal that separates them from real players is the email
-- domain: 5 real consumer-mailbox domains vs. exactly one reserved-for-testing
-- domain (twinhearth.test, RFC 2606), used by 10 of 45,000 players. Flagging it
-- here means every downstream model can filter on one column instead of
-- re-deriving this rule.
DROP TABLE IF EXISTS dim_player;
CREATE TABLE dim_player AS
SELECT player_id, country_code, currency_code, signup_date, acquisition_channel, email_domain,
       CASE WHEN email_domain = 'twinhearth.test' THEN 1 ELSE 0 END AS is_internal
FROM raw_players;

DROP TABLE IF EXISTS dim_platform;
CREATE TABLE dim_platform AS
SELECT DISTINCT platform_code FROM raw_orders;

-- Fiscal year starts on 1 October: FY2026 = 2025-10-01 .. 2026-09-30.
--
-- FIX: fiscal_quarter_no / fiscal_month_no used to be computed as
-- `(calendar_month - 10) % 12`. SQLite's % keeps the sign of the dividend, so
-- for any month before October that expression is NEGATIVE (month=1 ->
-- -9 % 12 = -9, not 3), and dividing a negative number truncates toward zero
-- instead of flooring. Net effect: every month from January to September
-- came out as fiscal_quarter_no = 1 (or negative) instead of 2, 3 or 4 -
-- FY2026 Q2 (Jan-Mar) could not be selected through this column at all.
-- Shifting by +12 before the modulo keeps the operand non-negative.
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
WITH RECURSIVE d(dt) AS (
    SELECT '2024-10-01'
    UNION ALL
    SELECT date(dt, '+1 day') FROM d WHERE dt < '2026-12-31'
)
SELECT dt                                                              AS date,
       CAST(strftime('%Y', dt) AS INTEGER)                             AS calendar_year,
       CAST(strftime('%m', dt) AS INTEGER)                             AS calendar_month,
       substr(dt, 1, 7)                                                AS year_month,
       (CAST(strftime('%m', dt) AS INTEGER) - 1) / 3 + 1               AS calendar_quarter,
       'FY' || CASE WHEN CAST(strftime('%m', dt) AS INTEGER) >= 10
                    THEN CAST(strftime('%Y', dt) AS INTEGER) + 1
                    ELSE CAST(strftime('%Y', dt) AS INTEGER) END       AS fiscal_year,
       ((CAST(strftime('%m', dt) AS INTEGER) - 10 + 12) % 12) / 3 + 1  AS fiscal_quarter_no,
       ((CAST(strftime('%m', dt) AS INTEGER) - 10 + 12) % 12) + 1      AS fiscal_month_no,
       CASE WHEN strftime('%w', dt) IN ('0','6') THEN 1 ELSE 0 END     AS is_weekend
FROM d;
