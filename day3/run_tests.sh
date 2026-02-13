#!/bin/bash
# Verify Day 3 setup: generated files, no duplicate services, MongoDB reachable, tcmalloc and demo metrics.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

MONGO_BUILD_DIR="mongodb-build"
MONGO_INSTALL_DIR="${SCRIPT_DIR}/${MONGO_BUILD_DIR}/install"
MONGO_DATA_DIR="${SCRIPT_DIR}/data"
MONGO_LOG_DIR="${SCRIPT_DIR}/log"
MONGO_PORT="${MONGO_PORT:-27017}"
CONTAINER_NAME="mongodb-tcmalloc-instance"

fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[PASS] $1"; }

echo "=== 1. Generated files/directories ==="
[[ -d "${MONGO_DATA_DIR}" ]] || fail "Missing directory: ${MONGO_DATA_DIR}"
[[ -d "${MONGO_LOG_DIR}" ]] || fail "Missing directory: ${MONGO_LOG_DIR}"
# Host build: require install dir; Docker: container has binary, so skip install check if container running
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    pass "Required dirs present (MongoDB running in Docker)"
else
    [[ -d "${MONGO_INSTALL_DIR}" ]] || fail "Missing directory: ${MONGO_INSTALL_DIR} (run setup.sh first)"
    [[ -x "${MONGO_INSTALL_DIR}/bin/mongod" ]] || fail "Missing executable: ${MONGO_INSTALL_DIR}/bin/mongod"
    pass "All required generated files/directories present"
fi

echo ""
echo "=== 2. Duplicate services check ==="
container_count=0
if command -v docker &>/dev/null 2>&1; then
    container_count=$(docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -c "^${CONTAINER_NAME}$" 2>/dev/null || echo 0)
fi
container_count=$((container_count + 0))
if [[ "${container_count}" -gt 1 ]]; then
    fail "Multiple containers named ${CONTAINER_NAME} running: ${container_count}"
fi
mongod_count=$(pgrep -f "mongod --port ${MONGO_PORT}" 2>/dev/null | wc -l)
mongod_count=$((mongod_count + 0))
if [[ "${mongod_count}" -gt 1 ]]; then
    fail "Multiple mongod processes on port ${MONGO_PORT}: ${mongod_count}"
fi
pass "No duplicate MongoDB services detected"

echo ""
echo "=== 3. MongoDB reachability ==="
mongo_reachable=0
if command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    if docker exec "${CONTAINER_NAME}" mongosh --quiet --eval "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
        pass "MongoDB reachable (Docker container ${CONTAINER_NAME})"
        mongo_reachable=1
    fi
fi
if [[ "${mongo_reachable}" -eq 0 ]]; then
    for cmd in mongosh mongo; do
        if command -v "$cmd" &>/dev/null; then
            if "$cmd" --host localhost --port "${MONGO_PORT}" --eval "db.adminCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
                pass "MongoDB reachable at localhost:${MONGO_PORT} (via $cmd)"
                mongo_reachable=1
                break
            fi
        fi
    done
fi
if [[ "${mongo_reachable}" -eq 0 ]]; then
    echo "[SKIP] MongoDB not reachable. Start with: ${SCRIPT_DIR}/start.sh or run setup.sh"
fi

echo ""
echo "=== 4. TCMalloc and demo metrics (optional) ==="
if [[ "${mongo_reachable}" -eq 1 ]]; then
    for cmd in mongosh mongo; do
        if command -v "$cmd" &>/dev/null; then
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
                out=$(docker exec "${CONTAINER_NAME}" "$cmd" --port "${MONGO_PORT}" --quiet --eval "
                    var s = db.serverStatus();
                    var hasTcmalloc = (s.tcmalloc != null);
                    var ops = (s.opcounters || {});
                    var conn = (s.connections && s.connections.current) || 0;
                    print(hasTcmalloc ? 'tcmalloc_ok' : 'tcmalloc_missing');
                    print('opcounters:' + JSON.stringify(ops));
                    print('connections:' + conn);
                " 2>/dev/null || true)
            else
                out=$("$cmd" --host localhost --port "${MONGO_PORT}" --quiet --eval "
                    var s = db.serverStatus();
                    var hasTcmalloc = (s.tcmalloc != null);
                    var ops = (s.opcounters || {});
                    var conn = (s.connections && s.connections.current) || 0;
                    print(hasTcmalloc ? 'tcmalloc_ok' : 'tcmalloc_missing');
                    print('opcounters:' + JSON.stringify(ops));
                    print('connections:' + conn);
                " 2>/dev/null || true)
            fi
            if echo "${out}" | grep -q "tcmalloc_ok"; then
                pass "TCMalloc active (serverStatus().tcmalloc present)"
            else
                echo "[WARN] TCMalloc not found in serverStatus (build may not use tcmalloc)"
            fi
            if echo "${out}" | grep -q "opcounters:"; then
                echo "  Sample metrics: ${out}"
            fi
            break
        fi
    done
    # Demo collection count (from setup workload)
    for cmd in mongosh mongo; do
        if command -v "$cmd" &>/dev/null; then
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
                n=$(docker exec "${CONTAINER_NAME}" "$cmd" --port "${MONGO_PORT}" --quiet --eval "db.testcollection.countDocuments()" 2>/dev/null || echo 0)
            else
                n=$("$cmd" --host localhost --port "${MONGO_PORT}" --quiet --eval "db.testcollection.countDocuments()" 2>/dev/null || echo 0)
            fi
            n=$((n + 0))
            if [[ "${n}" -gt 0 ]]; then
                pass "Demo data present: testcollection has ${n} document(s) (dashboard values non-zero)"
            else
                echo "[INFO] testcollection empty; run setup.sh or demo to populate (dashboard will show zero until then)"
            fi
            break
        fi
    done
else
    echo "[SKIP] Run after MongoDB is started"
fi

echo ""
echo "=== All checks completed ==="
