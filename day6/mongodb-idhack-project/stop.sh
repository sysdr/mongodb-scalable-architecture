#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_CONTAINER_NAME="mongo_day6_idhack"
DASHBOARD_PID_FILE="${SCRIPT_DIR}/.dashboard.pid"
if [ -f "${DASHBOARD_PID_FILE}" ]; then
    pid=$(cat "${DASHBOARD_PID_FILE}")
    if kill -0 "$pid" 2>/dev/null; then
        echo "[INFO] Stopping dashboard server (PID $pid)..."
        kill "$pid" 2>/dev/null || true
        echo "[SUCCESS] Dashboard stopped."
    fi
    rm -f "${DASHBOARD_PID_FILE}"
fi
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    echo "[INFO] Stopping container '${MONGO_CONTAINER_NAME}'..."
    docker stop "${MONGO_CONTAINER_NAME}"
    echo "[SUCCESS] Container stopped."
else
    echo "[INFO] Container '${MONGO_CONTAINER_NAME}' is not running."
fi
