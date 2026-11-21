-- 02_quality_checks.sql
-- The checks that run before the dashboard refresh. A failure above tolerance
-- holds the refresh and goes to the owner named here.

DROP VIEW IF EXISTS dq_checks;
CREATE VIEW dq_checks AS
SELECT 'Gifts with no fund code' AS check_name,
       (SELECT COUNT(*) FROM gifts WHERE fund_group IS NULL OR fund_group = '') AS failing,
       0 AS tolerance, 'OER' AS owner
UNION ALL
SELECT 'Gifts with zero or negative amount',
       (SELECT COUNT(*) FROM gifts WHERE amount <= 0), 0, 'OER'
UNION ALL
SELECT 'Gifts credited to an unknown constituent',
       (SELECT COUNT(*) FROM gifts
        WHERE hard_credit_id NOT IN (SELECT constituent_id FROM donors)), 0, 'Central data partner'
UNION ALL
SELECT 'Duplicate gift IDs',
       (SELECT COUNT(*) FROM (SELECT gift_id FROM gifts GROUP BY gift_id HAVING COUNT(*) > 1)), 0, 'Central data partner'
UNION ALL
SELECT 'Fiscal year disagrees with gift date',
       (SELECT COUNT(*) FROM gifts
        WHERE fiscal_year <> (CASE WHEN CAST(strftime('%m', gift_date) AS INTEGER) >= 7
                                   THEN CAST(strftime('%Y', gift_date) AS INTEGER) + 1
                                   ELSE CAST(strftime('%Y', gift_date) AS INTEGER) END)), 0, 'OER'
UNION ALL
SELECT 'June gifts posted in July',
       (SELECT COUNT(*) FROM gifts
        WHERE strftime('%m', gift_date) = '06' AND strftime('%m', posting_date) = '07'), 25, 'Central data partner'
UNION ALL
SELECT 'Pledge payments with no pledge ID',
       (SELECT COUNT(*) FROM gifts WHERE gift_type = 'PledgePay' AND (pledge_id IS NULL OR pledge_id = '')), 0, 'OER'
UNION ALL
SELECT 'Soft credit not matched to a constituent',
       (SELECT COUNT(*) FROM gifts
        WHERE soft_credit_id <> '' AND soft_credit_id IS NOT NULL
          AND soft_credit_id NOT IN (SELECT constituent_id FROM donors)), 0, 'Central data partner'
UNION ALL
SELECT 'Deceased records with active email consent',
       (SELECT COUNT(*) FROM donors WHERE deceased = 'Y' AND email_consent = 'Y'), 0, 'Alumni Association';

DROP VIEW IF EXISTS dq_summary;
CREATE VIEW dq_summary AS
SELECT COUNT(*) AS checks, SUM(CASE WHEN failing <= tolerance THEN 1 ELSE 0 END) AS passing
FROM dq_checks;
