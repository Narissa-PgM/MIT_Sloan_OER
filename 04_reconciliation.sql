-- 04_reconciliation.sql
-- OER reports on gift date; the central extract that fed VSE used posting date.
-- This is the single most common reason two "correct" numbers disagree.

DROP VIEW IF EXISTS oer_central_fy26;
CREATE VIEW oer_central_fy26 AS
WITH oer AS (
  SELECT SUM(amount) AS dollars, COUNT(*) AS gifts
  FROM af_receipts WHERE fiscal_year = 2026
), central AS (
  SELECT SUM(amount) AS dollars, COUNT(*) AS gifts
  FROM af_receipts
  WHERE (CASE WHEN CAST(strftime('%m', posting_date) AS INTEGER) >= 7
              THEN CAST(strftime('%Y', posting_date) AS INTEGER) + 1
              ELSE CAST(strftime('%Y', posting_date) AS INTEGER) END) = 2026
)
SELECT 'OER, gift date' AS source, dollars, gifts FROM oer
UNION ALL
SELECT 'Central, posting date', dollars, gifts FROM central;

DROP VIEW IF EXISTS boundary_gifts_fy26;
CREATE VIEW boundary_gifts_fy26 AS
SELECT gift_id, gift_date, posting_date, amount,
       CASE WHEN fiscal_year = 2026 THEN 'In OER, not central' ELSE 'In central, not OER' END AS direction
FROM af_receipts
WHERE (fiscal_year = 2026 AND
       (CASE WHEN CAST(strftime('%m', posting_date) AS INTEGER) >= 7
             THEN CAST(strftime('%Y', posting_date) AS INTEGER) + 1
             ELSE CAST(strftime('%Y', posting_date) AS INTEGER) END) <> 2026)
   OR (fiscal_year <> 2026 AND
       (CASE WHEN CAST(strftime('%m', posting_date) AS INTEGER) >= 7
             THEN CAST(strftime('%Y', posting_date) AS INTEGER) + 1
             ELSE CAST(strftime('%Y', posting_date) AS INTEGER) END) = 2026)
ORDER BY gift_date;

DROP VIEW IF EXISTS reconciliation_fy26;
CREATE VIEW reconciliation_fy26 AS
SELECT
  (SELECT dollars FROM oer_central_fy26 WHERE source = 'OER, gift date') AS oer,
  (SELECT dollars FROM oer_central_fy26 WHERE source = 'Central, posting date') AS central,
  (SELECT dollars FROM oer_central_fy26 WHERE source = 'OER, gift date')
  - (SELECT dollars FROM oer_central_fy26 WHERE source = 'Central, posting date') AS difference,
  (SELECT COUNT(*) FROM boundary_gifts_fy26) AS boundary_gifts;
