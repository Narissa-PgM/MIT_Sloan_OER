-- 03_suppression.sql
-- Spring email appeal, FY26: from all alumni to the final list, one rule at a time.
-- Counts are what each rule removes AFTER the rules above it, which is the only
-- way a waterfall adds up. The same order must be used to explain the list.

DROP VIEW IF EXISTS suppression_waterfall;
CREATE VIEW suppression_waterfall AS
WITH base AS (
  SELECT * FROM donors WHERE program <> 'Friends and parents'
), c1 AS (  -- deceased
  SELECT * FROM base WHERE deceased = 'N'
), c2 AS (  -- do not contact
  SELECT * FROM c1 WHERE no_contact = 'N'
), c3 AS (  -- do not solicit
  SELECT * FROM c2 WHERE no_solicit = 'N'
), c4 AS (  -- open proposal: the gift officer asks
  SELECT * FROM c3 WHERE open_proposal = 'N'
), c5 AS (  -- reunion personal solicitation plan
  SELECT * FROM c4 WHERE reunion_plan = 'N'
), c6 AS (  -- bounced or invalid email
  SELECT * FROM c5 WHERE email_status = 'Valid'
), c7 AS (  -- consent where required
  SELECT * FROM c6 WHERE NOT (consent_required = 'Y' AND email_consent = 'N')
), c8 AS (  -- already gave this fiscal year
  SELECT * FROM c7
  WHERE constituent_id NOT IN (SELECT constituent_id FROM hard_credit_donors WHERE fiscal_year = 2026)
), c9 AS (  -- one per household
  SELECT * FROM c8 WHERE constituent_id IN (SELECT MIN(constituent_id) FROM c8 GROUP BY household_id)
)
SELECT 'All alumni' AS step, (SELECT COUNT(*) FROM base) AS remaining, 0 AS removed, 1 AS ord
UNION ALL SELECT 'Deceased',              (SELECT COUNT(*) FROM c1), (SELECT COUNT(*) FROM base) - (SELECT COUNT(*) FROM c1), 2
UNION ALL SELECT 'Do not contact',        (SELECT COUNT(*) FROM c2), (SELECT COUNT(*) FROM c1) - (SELECT COUNT(*) FROM c2), 3
UNION ALL SELECT 'Do not solicit',        (SELECT COUNT(*) FROM c3), (SELECT COUNT(*) FROM c2) - (SELECT COUNT(*) FROM c3), 4
UNION ALL SELECT 'Open proposal',         (SELECT COUNT(*) FROM c4), (SELECT COUNT(*) FROM c3) - (SELECT COUNT(*) FROM c4), 5
UNION ALL SELECT 'Reunion plan',          (SELECT COUNT(*) FROM c5), (SELECT COUNT(*) FROM c4) - (SELECT COUNT(*) FROM c5), 6
UNION ALL SELECT 'Bad email',             (SELECT COUNT(*) FROM c6), (SELECT COUNT(*) FROM c5) - (SELECT COUNT(*) FROM c6), 7
UNION ALL SELECT 'No consent where required', (SELECT COUNT(*) FROM c7), (SELECT COUNT(*) FROM c6) - (SELECT COUNT(*) FROM c7), 8
UNION ALL SELECT 'Already gave this year',(SELECT COUNT(*) FROM c8), (SELECT COUNT(*) FROM c7) - (SELECT COUNT(*) FROM c8), 9
UNION ALL SELECT 'One per household',     (SELECT COUNT(*) FROM c9), (SELECT COUNT(*) FROM c8) - (SELECT COUNT(*) FROM c9), 10;
