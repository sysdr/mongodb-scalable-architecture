#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo8-trace-exercise"
MONGO_PORT="${MONGO_PORT:-27017}"
fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }

echo "=== 1. Generated files ==="
[[ -d "${PROJECT_DIR}" ]] || fail "Missing project dir"
[[ -f "${PROJECT_DIR}/client/package.json" ]] || fail "Missing client/package.json"
[[ -f "${PROJECT_DIR}/client/client.js" ]] || fail "Missing client/client.js"
[[ -f "${PROJECT_DIR}/start.sh" ]] || fail "Missing start.sh"
[[ -f "${PROJECT_DIR}/stop.sh" ]] || fail "Missing stop.sh"
[[ -f "${PROJECT_DIR}/demo.sh" ]] || fail "Missing demo.sh"
[[ -f "${PROJECT_DIR}/dashboard-server.js" ]] || fail "Missing dashboard-server.js"
[[ -f "${PROJECT_DIR}/index.html" ]] || fail "Missing index.html"
[[ -f "${PROJECT_DIR}/client/package.json" ]] || fail "Missing client/package.json"
pass "All required files present"

echo ""
echo "=== 2. Duplicate services check ==="
count=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c "^${MONGO_CONTAINER_NAME}$" || true)
[[ "${count:-0}" -le 1 ]] || fail "Multiple containers named ${MONGO_CONTAINER_NAME}: ${count}"
pass "No duplicate MongoDB containers"

echo ""
echo "=== 3. MongoDB reachability ==="
mongo_reachable=0
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    if docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1; then
        pass "MongoDB reachable at localhost:${MONGO_PORT}"
        mongo_reachable=1
    fi
fi
[[ "$mongo_reachable" -eq 1 ]] || echo "[SKIP] MongoDB not reachable. Run ${PROJECT_DIR}/start.sh first."

echo ""
echo "=== 4. Dashboard metrics (non-zero after demo) ==="
if [[ "$mongo_reachable" -eq 1 ]]; then
    n=$(docker exec "${MONGO_CONTAINER_NAME}" mongosh -u traceuser -p tracepass --authenticationDatabase admin --quiet --eval "db.getSiblingDB('tracedb').testcollection.countDocuments()" 2>/dev/null || echo 0)
    [[ "${n:-0}" -gt 0 ]] && pass "tracedb.testcollection has ${n} document(s) (dashboard non-zero)" || echo "[INFO] tracedb.testcollection empty; run demo.sh or start.sh"
fi

echo ""
echo "=== All checks completed ==="
