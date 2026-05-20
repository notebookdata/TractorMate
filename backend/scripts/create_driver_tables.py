#!/usr/bin/env python3
"""Create drivers and driver_attendances tables"""
import sqlite3
import sys

DB_PATH = "../tractormate.db"

def create_tables():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create drivers table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS drivers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        daily_salary REAL DEFAULT 0.0 NOT NULL,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        deleted_at TIMESTAMP
    )
    """)
    
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_drivers_name ON drivers(name)")
    
    # Create driver_attendances table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS driver_attendances (
        id TEXT PRIMARY KEY,
        driver_id TEXT NOT NULL,
        date TIMESTAMP NOT NULL,
        salary_amount REAL NOT NULL,
        amount_paid REAL DEFAULT 0.0 NOT NULL,
        payment_date TIMESTAMP,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        deleted_at TIMESTAMP,
        FOREIGN KEY (driver_id) REFERENCES drivers(id)
    )
    """)
    
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_driver_attendances_driver ON driver_attendances(driver_id)")
    
    conn.commit()
    conn.close()
    print("✓ Created drivers and driver_attendances tables")

if __name__ == "__main__":
    create_tables()
