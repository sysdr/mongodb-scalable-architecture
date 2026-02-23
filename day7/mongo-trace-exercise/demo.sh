#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_DB="tracedb"
MONGO_USER="traceuser"
MONGO_PASS="tracepass"
for i in 1 2 3 4 5; do
    docker exec mongo8-trace-exercise mongosh --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1 && break
    [ "$i" -eq 5 ] && { echo "[ERROR] MongoDB not reachable. Run start.sh first."; exit 1; }
    sleep 2
done
export MONGO_URL="mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:${MONGO_PORT}/"
export DB_NAME="${MONGO_DB}"
export COLLECTION_NAME="testcollection"
export MONGO_USER="${MONGO_USER}"
export MONGO_PASS="${MONGO_PASS}"
export METRICS_FILE="${SCRIPT_DIR}/.client_metrics.json"
echo "[INFO] Running client to update dashboard metrics..."
node "${SCRIPT_DIR}/client/client.js"
if [ -f "${SCRIPT_DIR}/.client_metrics.json" ]; then
    cp "${SCRIPT_DIR}/.client_metrics.json" "${SCRIPT_DIR}/metrics.json"
    echo "[INFO] Trace metrics updated from client timings."
fi
echo "[SUCCESS] Demo complete. Dashboard metrics should be non-zero."
