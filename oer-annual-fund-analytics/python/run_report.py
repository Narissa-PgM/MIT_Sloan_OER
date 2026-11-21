"""Load the CSVs into SQLite, run the SQL in /sql, and print the exhibits.

    python python/build_synthetic.py
    python python/run_report.py

No warehouse, no credentials, no external packages.
"""

import csv
import os
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
DATA = os.path.join(ROOT, "data")
SQL = os.path.join(ROOT, "sql")
DB = os.path.join(ROOT, "af.db")

TYPES = {
    "gifts": {"fiscal_year": "INTEGER", "amount": "REAL"},
    "donors": {"class_year": "INTEGER", "grad_year": "INTEGER"},
}


def load(con, table):
    path = os.path.join(DATA, table + ".csv")
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        cols = reader.fieldnames
        spec = ", ".join(f"{c} {TYPES.get(table, {}).get(c, 'TEXT')}" for c in cols)
        con.execute(f"DROP TABLE IF EXISTS {table}")
        con.execute(f"CREATE TABLE {table} ({spec})")
        rows = [[r[c] for c in cols] for r in reader]
        con.executemany(f"INSERT INTO {table} VALUES ({','.join('?' * len(cols))})", rows)
        return len(rows)


def build():
    con = sqlite3.connect(DB)
    for t in ("donors", "gifts"):
        load(con, t)
    for name in sorted(os.listdir(SQL)):
        if name.endswith(".sql"):
            con.executescript(open(os.path.join(SQL, name), encoding="utf-8").read())
    con.commit()
    return con


def show(con, title, query):
    print("\n" + title)
    print("-" * len(title))
    try:
        cur = con.execute(query)
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        widths = []
        for i, c in enumerate(cols):
            cells = []
            for r in rows:
                v = r[i]
                cells.append(f"{v:,.4f}" if isinstance(v, float) and abs(v) < 10 else f"{v:,.2f}" if isinstance(v, float) else str(v))
            widths.append(max([len(str(c))] + [len(x) for x in cells]))
        print("  " + "  ".join(str(c).ljust(widths[i]) for i, c in enumerate(cols)))
        for r in rows:
            cells = []
            for i, v in enumerate(r):
                if isinstance(v, float):
                    s = f"{v:,.4f}" if abs(v) < 10 else f"{v:,.2f}"
                else:
                    s = str(v)
                cells.append(s.ljust(widths[i]))
            print("  " + "  ".join(cells))
    except sqlite3.Error as e:
        print("  SQL error:", e)


def main():
    con = build()
    print("database:", DB)
    show(con, "Participation, FY26 (CASE: legally contactable denominator)", "SELECT * FROM participation_fy26")
    show(con, "Retention, FY26", "SELECT * FROM retention_fy26")
    show(con, "LYBUNT, FY26", "SELECT * FROM lybunt_fy26")
    show(con, "Dean's Circle tiers, FY26", """
        SELECT tier, COUNT(*) AS donors, ROUND(SUM(dollars)) AS dollars
        FROM dean_circle_fy26
        GROUP BY tier
        ORDER BY CASE tier WHEN 'Founders' THEN 1 WHEN 'Ambassadors' THEN 2 WHEN 'Leaders' THEN 3
                           WHEN 'Directors' THEN 4 WHEN 'Partners' THEN 5 WHEN 'Investors' THEN 6
                           ELSE 7 END""")
    show(con, "Funds received vs new funds committed, FY26",
         "SELECT ROUND(funds_received) AS received, ROUND(new_pledges) AS new_pledges, ROUND(new_committed) AS committed FROM bridge_fy26")
    show(con, "Quality checks", "SELECT * FROM dq_summary")
    show(con, "Checks above tolerance", "SELECT check_name, failing, tolerance, owner FROM dq_checks WHERE failing > tolerance")
    show(con, "Suppression waterfall", "SELECT step, remaining, removed FROM suppression_waterfall ORDER BY ord")
    show(con, "Reconciliation, FY26", "SELECT ROUND(oer) AS oer, ROUND(central) AS central, ROUND(difference) AS difference, boundary_gifts FROM reconciliation_fy26")
    show(con, "Peer comparison", "SELECT metric, value, low, high, position FROM peer_comparison_fy26")


if __name__ == "__main__":
    main()
