# Data dictionary

Synthetic Annual Fund extract. Field names follow the convention an advancement
warehouse would use, not the vendor's.

## donors.csv (2,800 rows)

| Field | Type | Notes |
| --- | --- | --- |
| constituent_id | text | Primary key, `C######` |
| class_year | integer | Degree class year |
| program | text | MBA, Sloan Fellows MBA, Executive MBA, LGO, MFin, MBAn, PhD, other master's, friends and parents |
| grad_year | integer | Graduation year; reunion logic uses this, not class year |
| deceased | Y/N | Excluded from every mailing and from the participation denominator |
| no_contact | Y/N | Total no-contact flag, any purpose, any means |
| email_status | Valid/Bounced | Hard bounce or invalid format |
| consent_required | Y/N | Country requires consent |
| email_consent | Y/N | Consent on file |
| household_id | text | One mailing per household; used by the suppression rule |
| volunteer | Y/N | Engagement signal |
| event_attendee | Y/N | Engagement signal |
| no_solicit | Y/N | Do-not-solicit code, any channel |
| open_proposal | Y/N | Assigned to a gift officer with an open proposal |
| reunion_plan | Y/N | On a volunteer or staff personal solicitation list |

## gifts.csv (~1,200 rows)

| Field | Type | Notes |
| --- | --- | --- |
| gift_id | text | Not guaranteed unique; duplicates are a check |
| gift_date | date | The date the gift was made. OER reports on this date |
| posting_date | date | When the system posted it. Central extracts may use this date |
| fiscal_year | integer | July 1 to June 30, derived from gift date |
| fund_group | text | SLOAN_AF, RESTRICTED, OTHER; blank is a defect |
| gift_type | text | Cash, Stock, Pledge, PledgePay, Match |
| amount | real | Dollars. A Pledge row is a commitment, not cash |
| appeal_code | text | FALL, GT, CYE, 24HC, SPR, FYE |
| hard_credit_id | text | The donor who gets credit; must exist in donors.csv |
| soft_credit_id | text | Optional spouse or partner; never added to the donor count |
| pledge_id | text | Present on Pledge and PledgePay rows |

## Derived views

| View | Basis | Definition |
| --- | --- | --- |
| af_receipts | FR | Annual Fund cash, stock, pledge payments and matches |
| af_commitments | NFC | Receipts plus new pledges in the year |
| hard_credit_donors | HC | One row per donor per fiscal year |
| soft_credit_donors | SC | Additional soft-credit donors, reported separately |
| contactable_alumni | LC | Not deceased, not no-contact, degree-holding |
| participation_fy26 | LC | Hard-credit alumni donors divided by contactable alumni |
| retention_fy26 | LOCAL | FY25 donors who gave again in FY26, over FY25 donors |
| dean_circle_fy26 | LOCAL | MIT Sloan published tiers, $1,000 and above |
| reunion_fy26 | LOCAL | 1st, 5th, 20th, 25th and 35th reunions |
| bridge_fy26 | FR + NFC | Receipts, new pledges and the commitment total |
| dq_checks | — | Nine checks with tolerance and owner |
| suppression_waterfall | — | Eight rules in order, each removing what is left |
| oer_central_fy26 | — | Gift-date total against posting-date total |
| peer_comparison_fy26 | — | Sloan metrics against placeholder peer bands |
