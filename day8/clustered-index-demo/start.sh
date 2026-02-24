#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo-clustered-index-demo"
MONGO_PORT="${MONGO_PORT:-27017}"
DOCKER_IMAGE="mongo:8.0-rc-jammy"
DB_NAME="contentDB"

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
    echo "[INFO] Pulling ${DOCKER_IMAGE}..."
    docker pull "${DOCKER_IMAGE}" >/dev/null
    echo "[INFO] Starting MongoDB container '${MONGO_CONTAINER_NAME}' with replSet..."
    docker run -d --name "${MONGO_CONTAINER_NAME}" -p "${MONGO_PORT}:27017" "${DOCKER_IMAGE}" --replSet rs0 --bind_ip_all
    echo "[INFO] Waiting for MongoDB to become ready..."
    sleep 10
    echo "[INFO] Initializing replica set..."
    docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval "rs.initiate({ _id: 'rs0', members: [ { _id: 0, host: 'localhost:27017' } ] })" --quiet >/dev/null
    sleep 5
fi

for i in 1 2 3 4 5 6 7 8 9 10; do
    if docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval "db.adminCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
        echo "[SUCCESS] MongoDB is ready."
        break
    fi
    [ "$i" -eq 10 ] && { echo "[ERROR] MongoDB not reachable."; exit 1; }
    sleep 2
done

# Run seed script (idempotent: collections may already exist)
if [ -f "${SCRIPT_DIR}/mongo_commands.js" ]; then
    echo "[INFO] Seeding contentDB (clustered_content_feed, product_catalog)..."
    docker cp "${SCRIPT_DIR}/mongo_commands.js" "${MONGO_CONTAINER_NAME}:/tmp/mongo_commands.js"
    docker exec "${MONGO_CONTAINER_NAME}" mongosh "${DB_NAME}" --file /tmp/mongo_commands.js --quiet 2>/dev/null || true
fi

DASHBOARD_PID_FILE="${SCRIPT_DIR}/.dashboard.pid"
DASHBOARD_PORT="${DASHBOARD_PORT:-3000}"
dashboard_already_running=0
if [ -f "${DASHBOARD_PID_FILE}" ]; then
    pid=$(cat "${DASHBOARD_PID_FILE}" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        dashboard_already_running=1
    fi
fi
if [ "$dashboard_already_running" -eq 0 ] && (echo >/dev/tcp/127.0.0.1/${DASHBOARD_PORT}) 2>/dev/null; then
    dashboard_already_running=1
fi
if [ "$dashboard_already_running" -eq 1 ]; then
    echo "[INFO] Dashboard already running at http://localhost:${DASHBOARD_PORT} (skipping start)"
else
    echo "[INFO] Starting web dashboard..."
    node "${SCRIPT_DIR}/dashboard-server.js" &
    echo $! > "${DASHBOARD_PID_FILE}"
    echo "[SUCCESS] Web Dashboard: http://localhost:${DASHBOARD_PORT}"
fi
echo "[SUCCESS] To stop: ${SCRIPT_DIR}/stop.sh"
