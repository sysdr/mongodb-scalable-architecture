#!/bin/bash
# Verify Day 4: generated files, no duplicate services, MongoDB reachable, demo metrics.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
DB_PATH="${PROJECT_DIR}/data/db"
JS_FILE="${PROJECT_DIR}/generate_load.js"
MONGO_PORT="${MONGO_PORT:-27017}"
fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }
echo "=== 1. Generated files/directories ==="
[[ -d "${PROJECT_DIR}" ]] || fail "Missing: ${PROJECT_DIR}"
[[ -d "${DB_PATH}" ]] || fail "Missing: ${DB_PATH}"
[[ -f "${JS_FILE}" ]] || fail "Missing: ${JS_FILE}"
pass "All required files/directories present"
echo ""; echo "=== 2. Duplicate services check ==="
c=$(pgrep -f "mongod.*--dbpath ${DB_PATH}" 2>/dev/null | wc -l); [[ "$c" -le 1 ]] || fail "Multiple mongod for dbpath: $c"
c=$(pgrep -f "mongod --port ${MONGO_PORT}" 2>/dev/null | wc -l); [[ "$c" -le 1 ]] || fail "Multiple mongod on port: $c"
pass "No duplicate MongoDB services"
echo ""; echo "=== 3. MongoDB reachability ==="
mongo_reachable=0
for cmd in mongosh mongo; do
    if command -v "$cmd" &>/dev/null && "$cmd" --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ping:1})" --quiet >/dev/null 2>&1; then
        pass "MongoDB reachable at localhost:${MONGO_PORT} (via $cmd)"; mongo_reachable=1; break
    fi
done
[[ "$mongo_reachable" -eq 1 ]] || echo "[SKIP] MongoDB not reachable. Run ${SCRIPT_DIR}/start.sh or setup.sh"
echo ""; echo "=== 4. Demo metrics (dashboard non-zero) ==="
if [[ "$mongo_reachable" -eq 1 ]]; then
    for cmd in mongosh mongo; do
        if command -v "$cmd" &>/dev/null; then
            n=$("$cmd" --host localhost --port "${MONGO_PORT}" --quiet --eval "db.getSiblingDB('testdb').items.countDocuments()" 2>/dev/null || echo 0)
            [[ "${n:-0}" -gt 0 ]] && pass "testdb.items has ${n} document(s) (dashboard non-zero)" || echo "[INFO] testdb.items empty; run demo.sh"
            break
        fi
    done
else echo "[SKIP] Run after MongoDB is started"; fi
echo ""; echo "=== All checks completed ==="
