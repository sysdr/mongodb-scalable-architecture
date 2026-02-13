#!/bin/bash
# Start the Admission Control demo: MongoDB + load generator + monitoring dashboard.
# Run from the project directory (day2-ingress-admin-control). Stop with Ctrl+C.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_VERSION="6.0"
DOCKER_IMAGE="mongo:${MONGO_VERSION}"
MONGO_CONTAINER_NAME="mongo_admission_test"
MONGO_DATA_DIR="${SCRIPT_DIR}/data/mongodb"
MONGO_LOG_DIR="${SCRIPT_DIR}/logs/mongodb"
NODE_APP_DIR="${SCRIPT_DIR}/app"
LOAD_SCRIPT_PATH="${NODE_APP_DIR}/load_generator.js"
MONGO_PORT=27017
CACHE_SIZE_GB="${1:-0.256}"
DASHBOARD_DURATION_SEC="${DASHBOARD_DURATION_SEC:-30}"

log_info()  { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_ok()    { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warn()  { echo -e "\033[0;33m[WARN]\033[0m $1"; }
log_err()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

cleanup() {
    log_info "Stopping load generator, dashboard, and MongoDB..."
    kill $LOAD_GEN_PID 2>/dev/null || true
    kill $STATUS_PID 2>/dev/null || true
    kill $MONGOSTAT_PID 2>/dev/null || true
    if docker ps -a --format '{{.Names}}' | grep -q "^${MONGO_CONTAINER_NAME}$"; then
        docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
        log_ok "MongoDB stopped."
    fi
    exit 0
}
trap cleanup INT TERM

# Pre-checks
if ! command -v docker &>/dev/null; then
    log_err "Docker is required. Install Docker and try again."
    exit 1
fi
if [[ ! -f "${LOAD_SCRIPT_PATH}" ]]; then
    log_err "Load generator not found: ${LOAD_SCRIPT_PATH}. Install dependencies: cd app && npm install"
    exit 1
fi

# Avoid duplicate container
if docker ps -a --format '{{.Names}}' | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    log_warn "Stopping existing container: ${MONGO_CONTAINER_NAME}"
    docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
    docker rm -f "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
fi

mkdir -p "${MONGO_DATA_DIR}" "${MONGO_LOG_DIR}"
CONFIG_FILE="${MONGO_DATA_DIR}/mongod.conf"

log_info "Creating MongoDB config (cacheSizeGB: ${CACHE_SIZE_GB})..."
cat << EOF > "${CONFIG_FILE}"
storage:
  dbPath: /data/db
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: ${CACHE_SIZE_GB}
systemLog:
  destination: file
  path: /data/db/mongod.log
  logAppend: true
processManagement:
  fork: false
net:
  port: ${MONGO_PORT}
  bindIpAll: true
EOF

log_info "Starting MongoDB on port ${MONGO_PORT}..."
docker run -d --rm \
    --name "${MONGO_CONTAINER_NAME}" \
    -p "${MONGO_PORT}:${MONGO_PORT}" \
    -v "${MONGO_DATA_DIR}:/data/db" \
    -v "${CONFIG_FILE}:/etc/mongod.conf" \
    "${DOCKER_IMAGE}" \
    mongod --config /etc/mongod.conf > /dev/null

log_info "Waiting for MongoDB to be ready..."
for i in $(seq 1 15); do
    if docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval "db.adminCommand({ ping: 1 })" &>/dev/null; then
        log_ok "MongoDB is ready."
        break
    fi
    if [[ $i -eq 15 ]]; then
        log_err "MongoDB did not start in time."
        docker logs "${MONGO_CONTAINER_NAME}" 2>&1 | tail -20
        exit 1
    fi
    sleep 2
done

log_info "Starting load generator (cache size ${CACHE_SIZE_GB} GB)..."
(cd "${NODE_APP_DIR}" && node "${LOAD_SCRIPT_PATH}" "${CACHE_SIZE_GB}") &
LOAD_GEN_PID=$!
STATUS_PID=""
MONGOSTAT_PID=""
sleep 3

echo ""
echo -e "\033[1;36m--- MongoDB Admission Control Dashboard ---\033[0m"
echo "  Watch: qw (queued writes), dirty (cache %), write.out (active write tickets)"
echo "  Press Ctrl+C to stop MongoDB and the load generator."
echo "--------------------------------------------------------"
echo ""

# Dashboard: mongostat + serverStatus loop (runs until Ctrl+C)
(
    while true; do
        echo -e "\n\033[0;35m--- serverStatus (wiredTiger.cache & concurrentTransactions) ---\033[0m"
        docker exec "${MONGO_CONTAINER_NAME}" mongosh --port "${MONGO_PORT}" --eval '
            var s = db.serverStatus();
            printjson({
                wiredTigerCache: s.wiredTiger.cache,
                concurrentTransactions: s.wiredTiger.concurrentTransactions
            });
        ' 2>/dev/null || true
        sleep 5
    done
) &
STATUS_PID=$!

docker exec "${MONGO_CONTAINER_NAME}" mongostat --port "${MONGO_PORT}" 5 2>&1 &
MONGOSTAT_PID=$!

# Block until Ctrl+C (trap runs cleanup)
wait $MONGOSTAT_PID 2>/dev/null || true
cleanup
