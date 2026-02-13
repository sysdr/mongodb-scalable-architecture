#!/bin/bash
# Stop MongoDB for Day 3 (host process and/or Docker container). Run from day3 or use full path.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_PORT="${MONGO_PORT:-27017}"
CONTAINER_NAME="mongodb-tcmalloc-instance"

# Stop Docker container if present
if command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        echo "[INFO] Stopping Docker container: ${CONTAINER_NAME}"
        docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        echo "[SUCCESS] Container stopped and removed."
    fi
fi

# Stop host mongod on MONGO_PORT
if pgrep -f "mongod --port ${MONGO_PORT}" >/dev/null 2>&1; then
    echo "[INFO] Stopping host mongod on port ${MONGO_PORT}..."
    pkill -f "mongod --port ${MONGO_PORT}" 2>/dev/null || true
    sleep 2
    if pgrep -f "mongod --port ${MONGO_PORT}" >/dev/null 2>&1; then
        echo "[WARN] mongod may still be running; try: pkill -f 'mongod --port ${MONGO_PORT}'"
    else
        echo "[SUCCESS] Host mongod stopped."
    fi
else
    echo "[INFO] No host mongod found on port ${MONGO_PORT}."
fi

echo "[DONE] Day 3 MongoDB stop complete."
