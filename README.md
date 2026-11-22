# MIT Sloan Annual Fund Analytics — reproducible sample

This is the runnable half of a work sample for the **Senior Data Analyst & Reporting Specialist** role in the MIT Sloan Office of External Relations. The interactive version is `../mit-sloan-work-sample.html`; this repo is where the numbers come from.

**Everything here is synthetic.** No MIT donor, gift or prospect data is used, and nothing here is affiliated with or endorsed by MIT.

## Why this exists

The work sample claims that every list is reproducible from one query. A claim like that should ship with the queries. This repo lets a reviewer rebuild the dataset, run the definitions, and check that the totals tie — in about a minute, with no warehouse access and no packages.

## Run it

```bash
python python/build_synthetic.py     # writes data/donors.csv and data/gifts.csv
python python/run_report.py          # loads SQLite, applies sql/, prints the exhibits
python python/validate.py            # asserts the invariants; exit 1 means do not publish
```

Python 3.9+, standard library only. `af.db` is generated and ignored by git.

## What it computes

| Question | Where |
| --- | --- |
| Participation on the CASE "legally contactable" denominator | `sql/01_definitions.sql` → `participation_fy26` |
| Retention, LYBUNT, Dean's Circle tiers, reunion years | `sql/01_definitions.sql` |
| Funds received vs new funds committed (CASE 2024) | `sql/01_definitions.sql` → `bridge_fy26` |
| Nine data quality checks, each with a tolerance and an owner | `sql/02_quality_checks.sql` |
| An eight-rule suppression waterfall that adds up | `sql/03_suppression.sql` |
| OER (gift date) vs central (posting date) reconciliation | `sql/04_reconciliation.sql` |
| Internal and external peer comparison | `sql/05_peer_benchmarks.sql` |

## Definitions follow CASE

The point of the exercise is that a donor means one thing everywhere. Each view names its basis:

| Code | Basis |
| --- | --- |
| FR | Funds received: cash, securities, pledge payments, matching gifts |
| NFC | New funds committed: receipts plus new pledges made in the year |
| HC | Hard credit: the only basis for a donor count |
| SC | Soft credit: reported as *additional* donors, never added in |
| LC | Legally contactable: not deceased, a means of contact, no total no-contact flag |
| LOCAL | A local definition agreed with central, and labelled as local |

Source: [CASE Global Reporting Standards](https://www.case.org/case-insights/case-global-reporting-standards) (2nd edition, 2024 update on pledges, 2026 addendum on alumni counts, engagement modes and soft credit) and the [CASE Insights VSE survey guidance](https://www.case.org/system/files/media/inline/VSE%20Survey%20Guidance%20Document%2010252023.pdf).

## Peers: what is public and what is not

- **Internal (within MIT).** MIT publishes Institute totals ($691M from almost 31,000 donors in FY25, [MIT facts](https://facts.mit.edu/resource-development/)) and Sloan publishes its Annual Fund result ($5.8M in FY26, [MIT Sloan](https://mitsloan.mit.edu/about/your-2025-2026-impact-deans-circle)). The school-level split in `sql/05_peer_benchmarks.sql` is illustrative and would come from Resource Development's warehouse. Treat it as a query shape, not a number.
- **External.** School-level peer giving is not public. The credible external anchor is institution-level [CASE Insights on VSE](https://www.case.org/research/surveys/voluntary-support-education-survey/VSE-2024) with a named comparison group; the bands in `peer_bands` are placeholders and are labelled as such. Sector context: the Fundraising Effectiveness Project reported dollars up about 3.6% and donors down about 1% in 2025, and the Lilly Report puts direct cost to raise a dollar between 8 and 16 cents for the middle quartiles.
- **Prospect research.** Capacity comes from screening and public asset records; inclination comes from our own engagement and giving history; public giving signals come from Form 990-PF grants, FEC filings and public announcements. An individual's gifts to other charities are not knowable: Form 990 withholds donor names on Schedule B and donor-advised fund grants are usually anonymous. Capacity and inclination are rated separately, every data point is sourced and dated, and the [Apra Principles of Ethics and Compliance](https://aprahome.org/Resources/Statement-of-Ethics) govern collection and use.

## The planted defects

`build_synthetic.py` inserts four deliberate faults so the checks have something to find: a duplicate gift ID, a missing fund code, a zero-dollar gift and a gift credited to an unknown constituent. `validate.py` proves each one is caught and that the rest of the definitions still tie.

## Limits

- A 2,800-constituent sample, not a population. Participation is computed on the sample's contactable base, so it runs below Sloan's published rate by construction.
- Fiscals, appeals and amounts are generated, not observed. The June/July posting split is simulated to exercise the reconciliation, not to describe MIT.
- Suppression uses flags that exist in this file. In the real system, solicitation codes, open proposals and reunion plans live in the CRM and central data.
- Peer bands are placeholders. Replace them before anything is quoted.

## What I would change with real data

1. Replace the fiscal-year literal with a date table and a parameter.
2. Swap the aggregate `af_receipts` view for the central warehouse's union of gift, pledge and matching-gift tables.
3. Add the address-presence test to `contactable_alumni`.
4. Run the reconciliation against the actual VSE extract, not a posting-date rebuild.
5. Add a row-level audit trail: who changed a definition, when, and why.
6. Keep the checks in the pipeline, not in a notebook.

## Author

Narissara Khomkhai · sawatdee@me.com · prepared November 2026.
