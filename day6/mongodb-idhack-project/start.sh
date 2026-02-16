#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo_day6_idhack"
MONGO_PORT="${MONGO_PORT:-27017}"
DASHBOARD_DURATION_SEC="${DASHBOARD_DURATION_SEC:-15}"
NODE_APP_FILE="index.js"

# Avoid duplicate container
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
        echo "[INFO] MongoDB container '${MONGO_CONTAINER_NAME}' already running."
    else
        echo "[INFO] Starting existing container '${MONGO_CONTAINER_NAME}'..."
        docker start "${MONGO_CONTAINER_NAME}"
        sleep 5
    fi
else
    if ! docker info >/dev/null 2>&1; then
        echo "[ERROR] Docker is not running. Start Docker and run again."
        exit 1
    fi
    echo "[INFO] Starting MongoDB container '${MONGO_CONTAINER_NAME}'..."
    docker run -d --name "${MONGO_CONTAINER_NAME}" -p "${MONGO_PORT}:27017" mongo:8.0
    echo "[INFO] Waiting for MongoDB to be ready..."
    sleep 10
fi

# Wait for MongoDB to accept connections
for i in 1 2 3 4 5 6 7 8 9 10; do
    if command -v mongosh &>/dev/null; then
        mongosh --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1 && break
    elif command -v mongo &>/dev/null; then
        mongo --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1 && break
    fi
    [ "$i" -eq 10 ] && { echo "[ERROR] MongoDB not reachable."; exit 1; }
    sleep 2
done
echo "[SUCCESS] MongoDB is ready."

# Run demo so dashboard metrics are non-zero
echo "[INFO] Running demo (IDHACK insert + point lookups) to populate metrics..."
node "${NODE_APP_FILE}" || { echo "[WARN] Demo had errors; continuing with dashboard."; }

# Dashboard: serverStatus (opcounters, connections) so values are non-zero
mongo_cmd() {
    if command -v mongosh &>/dev/null; then
        mongosh --host localhost --port "${MONGO_PORT}" --quiet "$@"
    else
        mongo --host localhost --port "${MONGO_PORT}" --quiet "$@"
    fi
}
echo ""
echo "=== Dashboard: metrics for ${DASHBOARD_DURATION_SEC}s (values from demo; should not be zero) ==="
intervals=$(( DASHBOARD_DURATION_SEC / 5 ))
for _ in $(seq 1 "$intervals"); do
    echo ""
    echo "--- serverStatus (opcounters, connections) ---"
    mongo_cmd --eval "var s=db.serverStatus(); printjson({ opcounters: s.opcounters || {}, connections: s.connections });" 2>/dev/null || true
    sleep 5
done
echo ""
echo "[INFO] Starting web dashboard server..."
DASHBOARD_PID_FILE="${SCRIPT_DIR}/.dashboard.pid"
node "${SCRIPT_DIR}/dashboard-server.js" &
echo $! > "${DASHBOARD_PID_FILE}"
echo "[SUCCESS] Web Dashboard: http://localhost:3000"
echo "[SUCCESS] Start complete. To stop MongoDB and dashboard, run: ${SCRIPT_DIR}/stop.sh"
