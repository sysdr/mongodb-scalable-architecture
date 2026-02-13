#!/bin/bash
# Start MongoDB for Day 3 (host only; use setup.sh --docker for Docker). Run from day3 or use full path.
# Checks for duplicate services before starting.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

MONGO_VERSION="8.0.0-rc1"
MONGO_SOURCE_DIR="mongodb-${MONGO_VERSION}"
MONGO_BUILD_DIR="mongodb-build"
MONGO_INSTALL_DIR="${SCRIPT_DIR}/${MONGO_BUILD_DIR}/install"
MONGO_DATA_DIR="${SCRIPT_DIR}/data"
MONGO_LOG_FILE="${SCRIPT_DIR}/log/mongod.log"
MONGO_PORT="${MONGO_PORT:-27017}"
CONTAINER_NAME="mongodb-tcmalloc-instance"

# --- Check for duplicate: Docker container ---
if command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
            echo "[INFO] Docker container ${CONTAINER_NAME} already running on port ${MONGO_PORT}. Nothing to do."
            exit 0
        fi
        echo "[INFO] Starting existing container ${CONTAINER_NAME}..."
        docker start "${CONTAINER_NAME}"
        echo "[SUCCESS] Container started."
        exit 0
    fi
fi

# --- Check for duplicate: host mongod on same port ---
if pgrep -f "mongod --port ${MONGO_PORT}" >/dev/null 2>&1; then
    echo "[INFO] mongod already running on port ${MONGO_PORT}. Nothing to do."
    exit 0
fi

# --- Host binary exists: start host mongod ---
MONGOD_BIN="${MONGO_INSTALL_DIR}/bin/mongod"
if [[ -x "${MONGOD_BIN}" ]]; then
    mkdir -p "${MONGO_DATA_DIR}" "$(dirname "${MONGO_LOG_FILE}")"
    echo "[INFO] Starting mongod (full path: ${MONGOD_BIN})..."
    "${MONGOD_BIN}" \
        --port "${MONGO_PORT}" \
        --dbpath "${MONGO_DATA_DIR}" \
        --logpath "${MONGO_LOG_FILE}" \
        --fork \
        --wiredTigerCacheSizeGB 0.25
    sleep 3
    if ! pgrep -f "mongod --port ${MONGO_PORT}" >/dev/null 2>&1; then
        echo "[ERROR] Failed to start mongod. Check log: ${MONGO_LOG_FILE}"
        exit 1
    fi
    echo "[SUCCESS] mongod started on port ${MONGO_PORT}. Log: ${MONGO_LOG_FILE}"
    exit 0
fi

# --- No host binary: start MongoDB via Docker (official image, same as setup.sh --docker) ---
if command -v docker &>/dev/null; then
    echo "[INFO] No host build; starting MongoDB in Docker (official mongo:7.0 image)..."
    mkdir -p "${MONGO_DATA_DIR}"
    docker run -d \
        --name "${CONTAINER_NAME}" \
        -p "${MONGO_PORT}:${MONGO_PORT}" \
        -v "${MONGO_DATA_DIR}:/data/db" \
        mongo:7.0 \
        mongod --wiredTigerCacheSizeGB 0.25 --bind_ip_all
    sleep 5
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "[SUCCESS] mongod started in Docker on port ${MONGO_PORT}."
        exit 0
    fi
    echo "[ERROR] Docker container failed to start. Check: docker logs ${CONTAINER_NAME}"
    exit 1
fi

echo "[ERROR] MongoDB binary not found: ${MONGOD_BIN}"
echo "        Run setup.sh (host build) or setup.sh --docker (Docker), or ensure Docker is available."
exit 1
