#!/bin/bash
# Stop project containers and remove unused Docker resources.
# Also removes node_modules, venv, .pytest_cache, .pyc, vendor, Istio, .rr from this project.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo_day5_benchmark"

echo "[INFO] Stopping container '${MONGO_CONTAINER_NAME}' (if running)..."
docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
docker rm "${MONGO_CONTAINER_NAME}" 2>/dev/null || true

echo "[INFO] Pruning unused Docker resources (containers, images, volumes, networks)..."
docker system prune -af --volumes 2>/dev/null || true

echo "[INFO] Removing node_modules, venv, .pytest_cache, .pyc, vendor, Istio, .rr from project..."
rm -rf "${SCRIPT_DIR}/node_modules"
rm -rf "${SCRIPT_DIR}/venv"
rm -rf "${SCRIPT_DIR}/.pytest_cache"
find "${SCRIPT_DIR}" -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
find "${SCRIPT_DIR}" -type f -name '*.pyc' -delete 2>/dev/null || true
find "${SCRIPT_DIR}" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
rm -rf "${SCRIPT_DIR}/vendor"
find "${SCRIPT_DIR}" -type d -iname 'istio' -exec rm -rf {} + 2>/dev/null || true
find "${SCRIPT_DIR}" -type f -name '*.rr' -delete 2>/dev/null || true

echo "[SUCCESS] Cleanup complete."
