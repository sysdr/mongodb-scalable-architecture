#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_PORT="${MONGO_PORT:-27017}"
for i in 1 2 3 4 5; do
    if command -v mongosh &>/dev/null; then
        mongosh --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1 && break
    elif command -v mongo &>/dev/null; then
        mongo --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1 && break
    fi
    [ "$i" -eq 5 ] && { echo "[ERROR] MongoDB not reachable. Run start.sh first."; exit 1; }
    sleep 2
done
echo "[INFO] Running demo to update dashboard metrics..."
node index.js
echo "[SUCCESS] Demo complete. Dashboard metrics should be non-zero."
