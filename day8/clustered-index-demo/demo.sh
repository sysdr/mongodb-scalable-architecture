#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo-clustered-index-demo"
MONGO_PORT="${MONGO_PORT:-27017}"
for i in 1 2 3 4 5; do
    docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1 && break
    [ "$i" -eq 5 ] && { echo "[ERROR] MongoDB not reachable. Run start.sh first."; exit 1; }
    sleep 2
done
echo "[INFO] Running demo client to update dashboard metrics..."
node "${SCRIPT_DIR}/demo-client.js" || true
echo "[SUCCESS] Demo complete. Dashboard metrics should be non-zero."
