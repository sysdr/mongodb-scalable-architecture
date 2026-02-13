#!/bin/bash
# Start MongoDB for Day 1 (Docker or local). Run from day1 or use full path to day1.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CONTAINER_NAME="mongo-fcv-day1"
MONGO_PORT="27017"
CONFIG_DIR="./config"
MONGO_CONF_FILE="${CONFIG_DIR}/mongod.conf"

# Check for duplicate: existing container
if command -v docker &>/dev/null 2>&1; then
    if docker ps -a -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        echo "[INFO] Container ${CONTAINER_NAME} already exists. Starting if stopped..."
        docker start "${CONTAINER_NAME}" 2>/dev/null || true
        if docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
            echo "[SUCCESS] MongoDB container already running on port ${MONGO_PORT}."
            exit 0
        fi
    fi
fi

# Check for duplicate: local mongod using our config
if [[ -f "${MONGO_CONF_FILE}" ]] && pgrep -f "mongod.*${MONGO_CONF_FILE}" >/dev/null 2>&1; then
    echo "[INFO] Local mongod already running with config ${MONGO_CONF_FILE}."
    exit 0
fi

# Ensure project files exist (run generate-only via parent's setup.sh)
if [[ ! -f "${MONGO_CONF_FILE}" ]]; then
    echo "[INFO] Generating config and directories..."
    GENERATE_ONLY=1 bash "${SCRIPT_DIR}/../setup.sh"
fi

# Prefer Docker if available and working
if command -v docker &>/dev/null 2>&1; then
    if docker info &>/dev/null 2>&1; then
        echo "[INFO] Starting MongoDB via Docker..."
        export DEPLOY_METHOD=1
        bash "${SCRIPT_DIR}/../setup.sh"
        exit 0
    fi
fi

# Fallback: local mongod
if command -v mongod &>/dev/null 2>&1; then
    echo "[INFO] Docker not available. Starting local mongod..."
    export DEPLOY_METHOD=2
    bash "${SCRIPT_DIR}/../setup.sh"
    exit 0
fi

echo "[WARN] Neither Docker nor local mongod is available. Project files have been created."
echo "       Enable Docker Desktop WSL integration, or install MongoDB locally, then run:"
echo "       ${SCRIPT_DIR}/start.sh"
exit 1
