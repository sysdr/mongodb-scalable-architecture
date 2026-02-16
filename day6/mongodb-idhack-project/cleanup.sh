#!/bin/bash
# Stop project containers and dashboard, remove unused Docker resources.
# Removes node_modules, venv, .pytest_cache, .pyc, vendor, Istio, .rr from this project.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo_day6_idhack"
DASHBOARD_PID_FILE="${SCRIPT_DIR}/.dashboard.pid"

echo "[INFO] Stopping dashboard server (if running)..."
if [ -f "${DASHBOARD_PID_FILE}" ]; then
  pid=$(cat "${DASHBOARD_PID_FILE}" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "[INFO] Dashboard stopped."
  fi
  rm -f "${DASHBOARD_PID_FILE}"
fi

echo "[INFO] Stopping container '${MONGO_CONTAINER_NAME}' (if running)..."
docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
docker rm "${MONGO_CONTAINER_NAME}" 2>/dev/null || true

echo "[INFO] Pruning unused Docker resources (containers, images, volumes, networks)..."
docker system prune -af --volumes 2>/dev/null || true

echo "[INFO] Removing node_modules, venv, .pytest_cache, .pyc, vendor, Istio, .rr from project..."
rm -rf "${SCRIPT_DIR}/node_modules"
rm -rf "${SCRIPT_DIR}/venv"
rm -rf "${SCRIPT_DIR}/.venv"
rm -rf "${SCRIPT_DIR}/.pytest_cache"
find "${SCRIPT_DIR}" -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
find "${SCRIPT_DIR}" -type f -name '*.pyc' -delete 2>/dev/null || true
find "${SCRIPT_DIR}" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
rm -rf "${SCRIPT_DIR}/vendor"
find "${SCRIPT_DIR}" -type d -iname 'istio' -exec rm -rf {} + 2>/dev/null || true
find "${SCRIPT_DIR}" -type f -name '*.rr' -delete 2>/dev/null || true

echo "[SUCCESS] Cleanup complete."
