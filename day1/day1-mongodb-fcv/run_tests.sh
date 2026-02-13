#!/bin/bash
# Verify setup: generated files, no duplicate services, optional demo and metrics.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

DATA_DIR="./data/db"
LOG_DIR="./data/log"
CONFIG_DIR="./config"
MONGO_CONF_FILE="${CONFIG_DIR}/mongod.conf"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_HOST="${MONGO_HOST:-localhost}"

fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }

echo "=== 1. Generated files ==="
[[ -d "${DATA_DIR}" ]] || fail "Missing directory: ${DATA_DIR}"
[[ -d "${LOG_DIR}" ]] || fail "Missing directory: ${LOG_DIR}"
[[ -d "${CONFIG_DIR}" ]] || fail "Missing directory: ${CONFIG_DIR}"
[[ -f "${MONGO_CONF_FILE}" ]] || fail "Missing file: ${MONGO_CONF_FILE}"
pass "All generated files/directories present"

echo ""
echo "=== 2. Duplicate services check ==="
CONTAINER_NAME="mongo-fcv-day1"
container_count=0
if command -v docker &>/dev/null 2>&1; then
    container_count=$(docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -c "^${CONTAINER_NAME}$" 2>/dev/null || true)
fi
container_count=$(echo "${container_count}" | tr -d '\n' | head -1)
container_count=$((container_count + 0))
if [[ "${container_count}" -gt 1 ]]; then
    fail "Multiple containers named ${CONTAINER_NAME} running: ${container_count}"
fi
mongod_count=$(pgrep -f "mongod.*${MONGO_CONF_FILE}" 2>/dev/null | wc -l)
mongod_count=$(echo "${mongod_count}" | tr -d ' \n')
mongod_count=$((mongod_count + 0))
if [[ "${mongod_count}" -gt 1 ]]; then
    fail "Multiple mongod processes using config: ${mongod_count}"
fi
pass "No duplicate MongoDB services detected"

echo ""
echo "=== 3. MongoDB reachability (optional) ==="
mongo_reachable=0
if docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    if docker exec "${CONTAINER_NAME}" mongosh --quiet --eval "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
        pass "MongoDB is reachable (container ${CONTAINER_NAME})"
        mongo_reachable=1
    fi
fi
if [[ "${mongo_reachable}" -eq 0 ]] && command -v mongosh &>/dev/null; then
    if mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" --eval "db.adminCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
        pass "MongoDB is reachable at ${MONGO_HOST}:${MONGO_PORT}"
        mongo_reachable=1
    fi
fi
if [[ "${mongo_reachable}" -eq 0 ]]; then
    echo "[SKIP] MongoDB not reachable (start with ./start.sh or setup.sh)"
fi

echo ""
echo "=== 4. Demo data and metrics (optional) ==="
if [[ "${mongo_reachable}" -eq 1 ]]; then
    if docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        docker exec "${CONTAINER_NAME}" mongosh --quiet --eval "
            const db = db.getSiblingDB('day1_demo');
            db.metrics.insertOne({ ts: new Date(), type: 'demo', value: 1 });
            const n = db.metrics.countDocuments();
            print('[PASS] Demo collection day1_demo.metrics has ' + n + ' document(s)');
        "
        echo "Server status (ops/sec and connections):"
        docker exec "${CONTAINER_NAME}" mongosh --quiet --eval "
            const s = db.serverStatus();
            print('  connections: ' + (s.connections && s.connections.current));
            print('  opcounters: ' + JSON.stringify(s.opcounters || {}));
        " 2>/dev/null || true
    elif command -v mongosh &>/dev/null; then
        mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "
            const db = db.getSiblingDB('day1_demo');
            db.metrics.insertOne({ ts: new Date(), type: 'demo', value: 1 });
            const n = db.metrics.countDocuments();
            print('[PASS] Demo collection day1_demo.metrics has ' + n + ' document(s)');
        "
        echo "Server status (ops/sec and connections):"
        mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "
            const s = db.serverStatus();
            print('  connections: ' + (s.connections && s.connections.current));
            print('  opcounters: ' + JSON.stringify(s.opcounters || {}));
        " 2>/dev/null || true
    fi
else
    echo "[SKIP] Run demo after starting MongoDB"
fi

echo ""
echo "=== All checks completed ==="
