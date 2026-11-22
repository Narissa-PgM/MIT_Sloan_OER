-- 01_definitions.sql
-- Annual Fund definitions, written the way I would hand them to a central partner.
-- CASE basis is named for every view so a reviewer can see which standard it follows:
--   FR   funds received          NFC  new funds committed
--   HC   hard credit             SC   soft credit (reported separately)
--   LC   legally contactable     LOCAL local definition agreed with central
--
-- Dialect: SQLite, so the whole repo runs from the CSVs in /data with no warehouse.
-- In the warehouse, swap the fiscal-year literal for a parameter and add a date table.

DROP VIEW IF EXISTS af_receipts;
CREATE VIEW af_receipts AS
-- FR: cash, securities, pledge payments and matching gifts. A new pledge is NOT cash.
SELECT gift_id, gift_date, posting_date, fiscal_year, gift_type, amount,
       appeal_code, hard_credit_id, soft_credit_id, pledge_id
FROM gifts
WHERE fund_group = 'SLOAN_AF'
  AND gift_type IN ('Cash', 'Stock', 'PledgePay', 'Match');

DROP VIEW IF EXISTS af_commitments;
CREATE VIEW af_commitments AS
-- NFC: receipts plus new pledges made in the year.
SELECT * FROM af_receipts
UNION ALL
SELECT gift_id, gift_date, posting_date, fiscal_year, gift_type, amount,
       appeal_code, hard_credit_id, soft_credit_id, pledge_id
FROM gifts
WHERE fund_group = 'SLOAN_AF' AND gift_type = 'Pledge';

DROP VIEW IF EXISTS hard_credit_donors;
CREATE VIEW hard_credit_donors AS
-- HC: one row per donor per fiscal year. Soft credit is never folded in here.
SELECT fiscal_year, hard_credit_id AS constituent_id, SUM(amount) AS dollars
FROM af_commitments
WHERE hard_credit_id IN (SELECT constituent_id FROM donors)
GROUP BY fiscal_year, hard_credit_id;

DROP VIEW IF EXISTS soft_credit_donors;
CREATE VIEW soft_credit_donors AS
-- SC: reported as "additional soft-credit donors", never added to the donor count.
SELECT fiscal_year, soft_credit_id AS constituent_id, SUM(amount) AS dollars
FROM af_commitments
WHERE soft_credit_id <> '' AND soft_credit_id IS NOT NULL
GROUP BY fiscal_year, soft_credit_id;

DROP VIEW IF EXISTS contactable_alumni;
CREATE VIEW contactable_alumni AS
-- LC: not deceased, not flagged no-contact, degree-holding (friends and parents excluded).
-- The warehouse version also requires a postal address, phone or email on file.
SELECT constituent_id, class_year, program, grad_year, household_id
FROM donors
WHERE deceased = 'N' AND no_contact = 'N' AND program <> 'Friends and parents';

DROP VIEW IF EXISTS participation_fy26;
CREATE VIEW participation_fy26 AS
SELECT ROUND(
  (SELECT COUNT(DISTINCT constituent_id) FROM hard_credit_donors WHERE fiscal_year = 2026) * 1.0
  / (SELECT COUNT(*) FROM contactable_alumni), 4) AS rate;

DROP VIEW IF EXISTS retention_fy26;
CREATE VIEW retention_fy26 AS
WITH prior AS (
  SELECT DISTINCT constituent_id FROM hard_credit_donors WHERE fiscal_year = 2025
), now AS (
  SELECT DISTINCT constituent_id FROM hard_credit_donors WHERE fiscal_year = 2026
)
SELECT ROUND((SELECT COUNT(*) FROM prior JOIN now USING (constituent_id)) * 1.0
             / (SELECT COUNT(*) FROM prior), 4) AS rate;

DROP VIEW IF EXISTS lybunt_fy26;
CREATE VIEW lybunt_fy26 AS
SELECT COUNT(*) AS donors FROM (
  SELECT constituent_id FROM hard_credit_donors WHERE fiscal_year = 2025
  EXCEPT
  SELECT constituent_id FROM hard_credit_donors WHERE fiscal_year = 2026
);

DROP VIEW IF EXISTS dean_circle_fy26;
CREATE VIEW dean_circle_fy26 AS
-- MIT Sloan's published Dean's Circle levels.
SELECT constituent_id, dollars,
  CASE
    WHEN dollars >= 100000 THEN 'Founders'
    WHEN dollars >=  50000 THEN 'Ambassadors'
    WHEN dollars >=  25000 THEN 'Leaders'
    WHEN dollars >=  10000 THEN 'Directors'
    WHEN dollars >=   5000 THEN 'Partners'
    WHEN dollars >=   2500 THEN 'Investors'
    WHEN dollars >=   1000 THEN 'Shareholders'
  END AS tier
FROM (
  SELECT constituent_id, SUM(dollars) AS dollars
  FROM hard_credit_donors WHERE fiscal_year = 2026
  GROUP BY constituent_id
)
WHERE dollars >= 1000;

DROP VIEW IF EXISTS reunion_fy26;
CREATE VIEW reunion_fy26 AS
-- LOCAL: Sloan's key reunions are the 1st, 5th, 20th, 25th and 35th.
SELECT d.grad_year, (2026 - d.grad_year) AS reunion_year,
       COUNT(DISTINCT h.constituent_id) AS donors, SUM(h.dollars) AS dollars
FROM hard_credit_donors h
JOIN donors d ON d.constituent_id = h.constituent_id
WHERE h.fiscal_year = 2026 AND (2026 - d.grad_year) IN (1, 5, 20, 25, 35)
GROUP BY d.grad_year;

DROP VIEW IF EXISTS bridge_fy26;
CREATE VIEW bridge_fy26 AS
-- FR and NFC are different numbers on purpose. Every leadership report names its basis.
SELECT
  (SELECT COALESCE(SUM(amount), 0) FROM af_receipts     WHERE fiscal_year = 2026) AS funds_received,
  (SELECT COALESCE(SUM(amount), 0) FROM af_commitments  WHERE fiscal_year = 2026) AS new_committed,
  (SELECT COALESCE(SUM(amount), 0) FROM gifts
     WHERE fund_group = 'SLOAN_AF' AND gift_type = 'Pledge' AND fiscal_year = 2026) AS new_pledges;
