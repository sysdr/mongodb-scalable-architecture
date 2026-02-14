#!/bin/bash
# Stop MongoDB for Day 4. Run from project dir or use full path.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
DB_PATH="${PROJECT_DIR}/data/db"
MONGO_PORT="${MONGO_PORT:-27017}"
if pgrep -f "mongod.*--dbpath ${DB_PATH}" >/dev/null 2>&1; then
    echo "[INFO] Stopping mongod (dbpath ${DB_PATH})..."; pkill -f "mongod.*--dbpath ${DB_PATH}" 2>/dev/null || true; sleep 2
elif pgrep -f "mongod --port ${MONGO_PORT}" >/dev/null 2>&1; then
    echo "[INFO] Stopping mongod on port ${MONGO_PORT}..."; pkill -f "mongod --port ${MONGO_PORT}" 2>/dev/null || true; sleep 2
else
    echo "[INFO] No mongod found for Day 4."
fi
pgrep -x mongod >/dev/null 2>&1 && echo "[WARN] Some mongod may still be running." || echo "[SUCCESS] Day 4 MongoDB stop complete."
