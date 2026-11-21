"""Build a small, deterministic synthetic Annual Fund dataset.

Nothing here is real donor data. The point is a dataset with the same
shape as an advancement extract: constituents, gifts, soft credits,
pledges, fiscal-year boundaries and a handful of deliberate defects that
the quality checks are supposed to catch.
"""

import csv
import datetime as dt
import math
import os
import random

SEED = 20261120
R = random.Random(SEED)
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")

PROGRAMS = [
    ("MBA", 0.50),
    ("Sloan Fellows MBA", 0.10),
    ("Executive MBA", 0.07),
    ("Leaders for Global Operations", 0.05),
    ("Master of Finance", 0.08),
    ("Master of Business Analytics", 0.05),
    ("PhD", 0.04),
    ("Other master's", 0.06),
    ("Friends and parents", 0.05),
]
FY_START, FY_END = 2019, 2026
APPEALS = ["FALL", "GT", "CYE", "24HC", "SPR", "FYE"]


def fiscal_year(d):
    return d.year + 1 if d.month >= 7 else d.year


def weighted(items):
    u, acc = R.random(), 0.0
    for name, w in items:
        acc += w
        if u <= acc:
            return name
    return items[-1][0]


def main():
    os.makedirs(DATA, exist_ok=True)
    donors, gifts = [], []
    gid = 500000
    hid = 1

    next_id = 100000
    for _ in range(900):
        program = weighted(PROGRAMS)
        grad = R.randint(1962, 2024)
        deceased = R.random() < 0.025
        no_contact = (not deceased) and R.random() < 0.07
        consent_required = R.random() < 0.06
        email_valid = R.random() < 0.93
        email_consent = email_valid and not deceased and (not consent_required or R.random() < 0.82)
        spouse = R.random() < 0.18
        household = f"H{hid:05d}"
        if not spouse:
            hid += 1
        donors.append({
            "constituent_id": f"C{next_id}",
            "class_year": grad,
            "program": program,
            "grad_year": grad,
            "deceased": "Y" if deceased else "N",
            "no_contact": "Y" if no_contact else "N",
            "email_status": "Valid" if email_valid else "Bounced",
            "consent_required": "Y" if consent_required else "N",
            "email_consent": "Y" if email_consent else "N",
            "household_id": household,
            "volunteer": "Y" if R.random() < 0.12 else "N",
            "event_attendee": "Y" if R.random() < 0.22 else "N",
            "no_solicit": "Y" if R.random() < 0.05 else "N",
            "open_proposal": "Y" if R.random() < 0.03 else "N",
            "reunion_plan": "Y" if R.random() < 0.04 else "N",
        })
        next_id += 1

    living = [d for d in donors if d["deceased"] == "N"]
    by_household = {}
    for d in donors:
        by_household.setdefault(d["household_id"], []).append(d)

    for d in living:
        last = None
        run = 0
        base = math.exp(5.9 + 1.1 * R.gauss(0, 1))
        for fy in range(FY_START, FY_END + 1):
            reunion = (fy - d["grad_year"]) in (1, 5, 20, 25, 35)
            if last == fy - 1:
                p = 0.45 + 0.03 * min(run, 4) + (0.12 if reunion else 0) + (0.04 if d["volunteer"] == "Y" else 0)
            else:
                p = 0.08 + (0.20 if reunion else 0) + (0.04 if d["event_attendee"] == "Y" else 0) + (0.03 if d["volunteer"] == "Y" else 0)
            if R.random() > min(p, 0.92):
                run = 0
                continue
            run = run + 1 if last == fy - 1 else 1
            last = fy
            month = R.choices([7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6],
                              weights=[7, 6, 7, 9, 10, 22, 7, 6, 14, 8, 9, 18])[0]
            day = R.randint(1, 28) if month != 6 else R.randint(1, 30)
            gift_date = dt.date(fy - 1 if month >= 7 else fy, month, day)
            amount = round(base * math.exp(0.35 * R.gauss(0, 1)) * (1.4 if reunion else 1.0), 2)
            amount = max(10.0, min(amount, 250000.0))
            gift_type = R.choices(["Cash", "Stock", "Pledge", "PledgePay", "Match"], [72, 5, 6, 12, 5])[0]
            if gift_type == "Pledge":
                amount = round(amount * R.choice([3, 4, 5]), 2)   # a commitment, not cash
            # deliberate: a few June gifts post in July, moving across the fiscal year
            # a June gift dated near month end can post in July: the classic fiscal-year break
            posting = gift_date + dt.timedelta(days=(R.randint(1, 4) if (month == 6 and day >= 28) else R.randint(0, 2)))
            appeal = R.choices(APPEALS, [16, 10, 26, 12, 18, 18])[0]
            soft = None
            partner = [p for p in by_household.get(d["household_id"], []) if p["constituent_id"] != d["constituent_id"]]
            if partner and R.random() < 0.10:
                soft = partner[0]["constituent_id"]
            pledge = f"P{gid}" if gift_type in ("Pledge", "PledgePay") else ""
            gifts.append({
                "gift_id": f"G{gid}",
                "gift_date": gift_date.isoformat(),
                "posting_date": posting.isoformat(),
                "fiscal_year": fiscal_year(gift_date),
                "fund_group": R.choices(["SLOAN_AF", "RESTRICTED", "OTHER"], [88, 9, 3])[0],
                "gift_type": gift_type,
                "amount": f"{amount:.2f}",
                "appeal_code": appeal,
                "hard_credit_id": d["constituent_id"],
                "soft_credit_id": soft or "",
                "pledge_id": pledge,
            })
            gid += 1

    # alumni who have never given. A participation rate needs a denominator bigger
    # than the donor file, otherwise it flatters itself.
    for _ in range(1900):
        program = weighted(PROGRAMS)
        grad = R.randint(1962, 2024)
        donors.append({
            "constituent_id": f"C{next_id}",
            "class_year": grad,
            "program": program,
            "grad_year": grad,
            "deceased": "N",
            "no_contact": "Y" if R.random() < 0.09 else "N",
            "email_status": "Valid" if R.random() < 0.88 else "Bounced",
            "consent_required": "Y" if R.random() < 0.06 else "N",
            "email_consent": "Y" if R.random() < 0.75 else "N",
            "household_id": f"H{hid:05d}",
            "volunteer": "N",
            "event_attendee": "Y" if R.random() < 0.08 else "N",
            "no_solicit": "Y" if R.random() < 0.04 else "N",
            "open_proposal": "N",
            "reunion_plan": "N",
        })
        next_id += 1
        hid += 1

    # a handful of deliberate defects for the checks to find
    gifts.append(dict(gifts[10]))                       # duplicate gift ID, caught by the check
    gifts[20]["fund_group"] = ""                        # missing fund code
    gifts[21]["amount"] = "0.00"                        # zero amount
    gifts[22]["hard_credit_id"] = "C999999"             # orphan constituent

    # scale to a plausible Annual Fund year so the numbers read like money
    fy26 = sum(float(g["amount"]) for g in gifts
               if g["fiscal_year"] == FY_END and g["gift_type"] != "Pledge" and g["fund_group"] == "SLOAN_AF")
    factor = 3.8e5 / fy26 if fy26 else 1.0
    for g in gifts:
        g["amount"] = f"{float(g['amount']) * factor:.2f}"

    with open(os.path.join(DATA, "donors.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(donors[0].keys()))
        w.writeheader()
        w.writerows(donors)
    with open(os.path.join(DATA, "gifts.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(gifts[0].keys()))
        w.writeheader()
        w.writerows(gifts)

    print(f"donors: {len(donors)}  gifts: {len(gifts)}")
    print(f"FY{ FY_END } gifts: {sum(1 for g in gifts if g['fiscal_year'] == FY_END)}")
    print(f"FY{ FY_END } dollars: {sum(float(g['amount']) for g in gifts if g['fiscal_year'] == FY_END):,.2f}")


if __name__ == "__main__":
    main()
