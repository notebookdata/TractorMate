"""
Run once on the server to apply DB schema changes safely.
Usage:  python3 migrate_db.py
"""
import sqlite3
import os
import sys

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'tractormate.db')

def column_exists(cursor, table, column):
    cursor.execute(f"PRAGMA table_info({table})")
    return any(row[1] == column for row in cursor.fetchall())

def main():
    if not os.path.exists(DB_PATH):
        print(f"DB not found at {DB_PATH} — nothing to migrate.")
        sys.exit(0)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    migrations = [
        ("rentals",  "driver_name", "ALTER TABLE rentals ADD COLUMN driver_name TEXT"),
    ]

    for table, col, sql in migrations:
        if column_exists(cur, table, col):
            print(f"  ✓ {table}.{col} already exists — skipped")
        else:
            cur.execute(sql)
            print(f"  + Added {table}.{col}")

    conn.commit()
    conn.close()
    print("Migration complete.")

if __name__ == "__main__":
    main()
