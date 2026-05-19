#!/bin/bash
# Daily backup of TractorMate SQLite database
# Add to cron: 0 2 * * * /home/ubuntu/tractormate/scripts/backup.sh

set -e

DB_PATH="/home/ubuntu/tractormate/tractormate.db"
BACKUP_DIR="/var/backups/tractormate"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="${BACKUP_DIR}/tractormate_${DATE}.db"
KEEP_DAYS=30
LOG="/var/log/tractormate_backup.log"

mkdir -p "$BACKUP_DIR"

if [ ! -f "$DB_PATH" ]; then
    echo "[$(date)] ERROR: Database not found at $DB_PATH" | tee -a "$LOG"
    exit 1
fi

# Use SQLite's online backup so the running server is not interrupted
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "[$(date)] Backup OK: $BACKUP_FILE ($SIZE)" | tee -a "$LOG"
else
    echo "[$(date)] ERROR: Backup failed!" | tee -a "$LOG"
    exit 1
fi

# Remove backups older than KEEP_DAYS days
find "$BACKUP_DIR" -name "tractormate_*.db" -mtime +${KEEP_DAYS} -delete
echo "[$(date)] Cleanup: removed backups older than ${KEEP_DAYS} days" | tee -a "$LOG"
