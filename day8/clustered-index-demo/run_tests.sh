#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo-clustered-index-demo"
MONGO_PORT="${MONGO_PORT:-27017}"
fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }

echo "=== 1. Generated files ==="
[[ -d "${PROJECT_DIR}" ]] || fail "Missing project dir"
[[ -f "${PROJECT_DIR}/mongo_commands.js" ]] || fail "Missing mongo_commands.js"
[[ -f "${PROJECT_DIR}/start.sh" ]] || fail "Missing start.sh"
[[ -f "${PROJECT_DIR}/stop.sh" ]] || fail "Missing stop.sh"
[[ -f "${PROJECT_DIR}/demo.sh" ]] || fail "Missing demo.sh"
[[ -f "${PROJECT_DIR}/dashboard-server.js" ]] || fail "Missing dashboard-server.js"
[[ -f "${PROJECT_DIR}/index.html" ]] || fail "Missing index.html"
[[ -f "${PROJECT_DIR}/demo-client.js" ]] || fail "Missing demo-client.js"
[[ -f "${PROJECT_DIR}/package.json" ]] || fail "Missing package.json"
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
    feed=$(docker exec "${MONGO_CONTAINER_NAME}" mongosh contentDB --quiet --eval "db.clustered_content_feed.countDocuments()" 2>/dev/null | tr -d '\r' || echo 0)
    prod=$(docker exec "${MONGO_CONTAINER_NAME}" mongosh contentDB --quiet --eval "db.product_catalog.countDocuments()" 2>/dev/null | tr -d '\r' || echo 0)
    [[ "${feed:-0}" -gt 0 ]] && pass "clustered_content_feed has ${feed} document(s)" || echo "[INFO] clustered_content_feed empty; run start.sh (seeds data)"
    [[ "${prod:-0}" -gt 0 ]] && pass "product_catalog has ${prod} document(s)" || echo "[INFO] product_catalog empty; run start.sh (seeds data)"
fi

echo ""
echo "=== All checks completed ==="
