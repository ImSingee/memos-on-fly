#!/bin/sh
set -e

DB_PATH=/var/opt/memos/memos_prod.db

# Restore the database if it does not already exist.
if [ -f "$DB_PATH" ]; then
  echo "Database exists, skipping restore."
else
  echo "No database found, attempt to restore from a replica."
  litestream restore -if-replica-exists "$DB_PATH"
  echo "Finished restoring the database."
fi

echo "Starting litestream & memos service."

# Run litestream with your app as the subprocess.
exec litestream replicate -exec "./memos --mode prod --port ${PORT:-5230}"