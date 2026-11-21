"""Assert the invariants the exhibits depend on. Exit code 1 means do not publish.

    python python/validate.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_report import build  # noqa: E402

FAILS = []


def check(name, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + name + (("  (" + detail + ")") if detail else ""))
    if not ok:
        FAILS.append(name)


def one(con, q):
    return con.execute(q).fetchone()[0]


def main():
    con = build()

    check("donors loaded", one(con, "SELECT COUNT(*) FROM donors") > 500)
    check("gifts loaded", one(con, "SELECT COUNT(*) FROM gifts") > 1000)

    check("duplicate gift IDs are the one planted defect",
          one(con, "SELECT COUNT(*) FROM (SELECT gift_id FROM gifts GROUP BY gift_id HAVING COUNT(*)>1)") == 1)
    check("orphan credit is the one planted defect",
          one(con, "SELECT COUNT(*) FROM gifts WHERE hard_credit_id NOT IN (SELECT constituent_id FROM donors)") == 1)

    rec = one(con, "SELECT funds_received FROM bridge_fy26")
    com = one(con, "SELECT new_committed FROM bridge_fy26")
    pl = one(con, "SELECT new_pledges FROM bridge_fy26")
    check("commitments equal receipts plus new pledges", abs((rec + pl) - com) < 0.01,
          f"received {rec:,.2f} + pledges {pl:,.2f} = committed {com:,.2f}")

    part = one(con, "SELECT rate FROM participation_fy26")
    ret = one(con, "SELECT rate FROM retention_fy26")
    check("participation is a rate", 0 < part < 1, f"{part:.4f}")
    check("retention is a rate", 0 < ret < 1, f"{ret:.4f}")

    start = one(con, "SELECT remaining FROM suppression_waterfall ORDER BY ord LIMIT 1")
    final = one(con, "SELECT remaining FROM suppression_waterfall ORDER BY ord DESC LIMIT 1")
    removed = one(con, "SELECT SUM(removed) FROM suppression_waterfall")
    check("suppression waterfall adds up", start - removed == final,
          f"{start} - {removed} = {final}")
    check("final list is positive and smaller than the base", 0 < final < start, f"{final} of {start}")

    oer = one(con, "SELECT oer FROM reconciliation_fy26")
    central = one(con, "SELECT central FROM reconciliation_fy26")
    diff = one(con, "SELECT difference FROM reconciliation_fy26")
    check("reconciliation difference is arithmetic", abs((oer - central) - diff) < 0.01,
          f"OER {oer:,.2f} - central {central:,.2f} = {diff:,.2f}")
    boundary = one(con, """SELECT COALESCE(SUM(CASE WHEN direction = 'In OER, not central' THEN amount ELSE -amount END), 0)
                        FROM boundary_gifts_fy26""")
    check("every dollar of the difference is in the boundary list", abs(diff - boundary) < 0.01,
          f"difference {diff:,.2f}, net boundary {boundary:,.2f}")

    dq = con.execute("SELECT checks, passing FROM dq_summary").fetchone()
    check("quality checks defined", dq[0] >= 8, f"{dq[0]} checks, {dq[1]} passing")

    check("every hard-credit donor exists in the constituent file",
          one(con, "SELECT COUNT(*) FROM hard_credit_donors WHERE constituent_id NOT IN (SELECT constituent_id FROM donors)") == 0)

    print()
    if FAILS:
        print("FAILED:", ", ".join(FAILS))
        sys.exit(1)
    print("All invariants hold.")


if __name__ == "__main__":
    main()
