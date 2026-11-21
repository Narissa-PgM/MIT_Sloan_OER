-- 05_peer_benchmarks.sql
-- Internal and external benchmarks, built as a repeatable query rather than a slide.
-- The peer bands are ILLUSTRATIVE placeholders. Replace them with a CASE Insights on
-- VSE extract and a named comparison group before anyone quotes them.

DROP VIEW IF EXISTS sloan_metrics_fy26;
CREATE VIEW sloan_metrics_fy26 AS
SELECT 'Alumni participation' AS metric,
       (SELECT rate FROM participation_fy26) AS value, 'rate' AS unit
UNION ALL
SELECT 'Donor retention',
       (SELECT rate FROM retention_fy26), 'rate'
UNION ALL
SELECT 'Leadership share, $1,000 and above',
       ROUND((SELECT SUM(dollars) FROM dean_circle_fy26) * 1.0
             / (SELECT SUM(dollars) FROM hard_credit_donors WHERE fiscal_year = 2026), 4), 'rate'
UNION ALL
SELECT 'Average Annual Fund gift',
       (SELECT ROUND(AVG(dollars), 2) FROM hard_credit_donors WHERE fiscal_year = 2026), 'usd'
UNION ALL
SELECT 'Donors',
       (SELECT COUNT(*) FROM hard_credit_donors WHERE fiscal_year = 2026), 'count';

DROP VIEW IF EXISTS peer_bands;
CREATE VIEW peer_bands AS
SELECT 'Alumni participation' AS metric, 0.06 AS low, 0.12 AS high,
       'CASE Insights on VSE, peer band (illustrative)' AS source
UNION ALL SELECT 'Donor retention', 0.38, 0.48, 'CASE Insights on VSE (illustrative)'
UNION ALL SELECT 'Leadership share, $1,000 and above', 0.75, 0.95, 'CASE Insights on VSE (illustrative)'
UNION ALL SELECT 'Average Annual Fund gift', 1600, 3000, 'CASE Insights on VSE (illustrative)';

DROP VIEW IF EXISTS peer_comparison_fy26;
CREATE VIEW peer_comparison_fy26 AS
SELECT m.metric, m.unit, m.value, b.low, b.high, b.source,
       CASE
         WHEN b.low IS NULL THEN 'no band yet'
         WHEN m.value < b.low  THEN 'below band'
         WHEN m.value > b.high THEN 'above band'
         ELSE 'inside band'
       END AS position
FROM sloan_metrics_fy26 m
LEFT JOIN peer_bands b ON b.metric = m.metric;

-- Internal peers: the shape of the query, not a number anyone should quote.
-- The unit split comes from Resource Development's warehouse in a real run.
DROP VIEW IF EXISTS internal_units;
CREATE VIEW internal_units AS
SELECT 'MIT Sloan' AS unit, 9.0 AS share_of_mit_giving, 42 AS leadership_share, 1 AS is_sloan
UNION ALL SELECT 'School of Engineering', 24.0, 31, 0
UNION ALL SELECT 'School of Science', 21.0, 29, 0
UNION ALL SELECT 'Schwarzman College of Computing', 12.0, 38, 0
UNION ALL SELECT 'Architecture and Planning', 5.0, 22, 0
UNION ALL SELECT 'Humanities, Arts and Social Sciences', 4.0, 19, 0
UNION ALL SELECT 'Other units and Institute programs', 25.0, 26, 0;
