#!/bin/bash
# Start MongoDB for Day 4 (host with TCMalloc + MALLOCSTATS). Run from project dir or use full path.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
DB_PATH="${PROJECT_DIR}/data/db"
LOG_PATH="${PROJECT_DIR}/data/mongod.log"
MONGO_PORT="${MONGO_PORT:-27017}"
TCMALLOC_LIB="/usr/lib/x86_64-linux-gnu/libtcmalloc.so"
if pgrep -f "mongod.*--dbpath ${DB_PATH}" >/dev/null 2>&1; then echo "[INFO] mongod already running for Day 4. Nothing to do."; exit 0; fi
if pgrep -f "mongod --port ${MONGO_PORT}" >/dev/null 2>&1; then echo "[INFO] mongod already on port ${MONGO_PORT}. Nothing to do."; exit 0; fi
[[ -d "${PROJECT_DIR}" && -d "${DB_PATH}" ]] || { echo "[ERROR] Run setup.sh first: $(dirname "${SCRIPT_DIR}")/setup.sh"; exit 1; }
[[ -f "${TCMALLOC_LIB}" ]] || { echo "[ERROR] TCMalloc not found. Run setup.sh first."; exit 1; }
MONGOD_BIN=$(command -v mongod)
[[ -n "${MONGOD_BIN}" ]] || { echo "[ERROR] mongod not found. Run setup.sh first."; exit 1; }
mkdir -p "$(dirname "${LOG_PATH}")"
export LD_PRELOAD="${TCMALLOC_LIB}"
export MALLOCSTATS=1
echo "[INFO] Starting mongod (full path: ${MONGOD_BIN})..."
"${MONGOD_BIN}" --dbpath "${DB_PATH}" --logpath "${LOG_PATH}" --port "${MONGO_PORT}" --fork --bind_ip 127.0.0.1
sleep 5
pgrep -f "mongod.*--dbpath ${DB_PATH}" >/dev/null 2>&1 || { echo "[ERROR] mongod failed to start. Check: ${LOG_PATH}"; exit 1; }
echo "[SUCCESS] mongod started on port ${MONGO_PORT}. Log: ${LOG_PATH}"
