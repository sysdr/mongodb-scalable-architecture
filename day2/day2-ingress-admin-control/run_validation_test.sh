#!/bin/bash
# Quick validation: start MongoDB, run load gen briefly, check serverStatus has non-zero metrics, stop.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_CONTAINER_NAME="mongo_admission_test"
echo "[TEST] Checking for duplicate containers..."
docker ps -a --format '{{.Names}}' | grep -q "^${MONGO_CONTAINER_NAME}$" && docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
echo "[TEST] Starting MongoDB..."
mkdir -p "${SCRIPT_DIR}/data/mongodb" "${SCRIPT_DIR}/logs/mongodb"
printf 'storage:\n  dbPath: /data/db\n  wiredTiger:\n    engineConfig:\n      cacheSizeGB: 0.5\nsystemLog:\n  destination: file\n  path: /data/db/mongod.log\nnet:\n  port: 27017\n  bindIpAll: true\n' > "${SCRIPT_DIR}/data/mongodb/mongod.conf"
docker run -d --rm --name "${MONGO_CONTAINER_NAME}" -p 27017:27017 \
  -v "${SCRIPT_DIR}/data/mongodb:/data/db" -v "${SCRIPT_DIR}/data/mongodb/mongod.conf:/etc/mongod.conf" \
  mongo:6.0 mongod --config /etc/mongod.conf
sleep 8
echo "[TEST] Running load generator (5s)..."
(cd "${SCRIPT_DIR}/app" && timeout 5 node load_generator.js 0.5 || true) &
sleep 5
echo "[TEST] Checking serverStatus (wiredTiger.cache)..."
OUT=$(docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval 'JSON.stringify(db.serverStatus().wiredTiger.cache["bytes currently in the cache"])' --quiet 2>/dev/null || echo "0")
docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
if [[ "${OUT}" != "0" && -n "${OUT}" ]]; then
  echo "[TEST] PASS: Cache bytes non-zero (value: ${OUT})"
  exit 0
else
  echo "[TEST] FAIL: Cache bytes zero or missing"
  exit 1
fi
