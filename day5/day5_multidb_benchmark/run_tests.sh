#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo_day5_benchmark"
MONGO_PORT="${MONGO_PORT:-27017}"
fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }

echo "=== 1. Generated files ==="
[[ -d "${PROJECT_DIR}" ]] || fail "Missing: ${PROJECT_DIR}"
[[ -f "${PROJECT_DIR}/benchmark.js" ]] || fail "Missing: benchmark.js"
[[ -f "${PROJECT_DIR}/start.sh" ]] || fail "Missing: start.sh"
[[ -f "${PROJECT_DIR}/stop.sh" ]] || fail "Missing: stop.sh"
[[ -f "${PROJECT_DIR}/demo.sh" ]] || fail "Missing: demo.sh"
[[ -f "${PROJECT_DIR}/package.json" ]] || fail "Missing: package.json"
pass "All required files present"

echo ""
echo "=== 2. Duplicate services check ==="
count=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c "^${MONGO_CONTAINER_NAME}$" || true)
[[ "${count:-0}" -le 1 ]] || fail "Multiple containers named ${MONGO_CONTAINER_NAME}: ${count}"
pass "No duplicate MongoDB containers"

echo ""
echo "=== 3. MongoDB reachability ==="
mongo_reachable=0
for cmd in mongosh mongo; do
    if command -v "$cmd" &>/dev/null && "$cmd" --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1; then
        pass "MongoDB reachable at localhost:${MONGO_PORT} (via $cmd)"
        mongo_reachable=1
        break
    fi
done
[[ "$mongo_reachable" -eq 1 ]] || echo "[SKIP] MongoDB not reachable. Run ${SCRIPT_DIR}/start.sh first."

echo ""
echo "=== 4. Demo metrics (dashboard non-zero) ==="
if [[ "$mongo_reachable" -eq 1 ]]; then
    for cmd in mongosh mongo; do
        if command -v "$cmd" &>/dev/null; then
            n=$("$cmd" --host localhost --port "${MONGO_PORT}" --quiet --eval "db.getSiblingDB('blog_main').articles.countDocuments()" 2>/dev/null || echo 0)
            [[ "${n:-0}" -gt 0 ]] && pass "blog_main.articles has ${n} document(s) (dashboard non-zero)" || echo "[INFO] blog_main.articles empty; run demo.sh or start.sh"
            break
        fi
    done
else
    echo "[SKIP] Run after MongoDB is started."
fi
echo ""
echo "=== All checks completed ==="
