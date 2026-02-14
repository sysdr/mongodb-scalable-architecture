#!/bin/bash
set -e
MONGO_CONTAINER_NAME="mongo_day5_benchmark"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    echo "[INFO] Stopping container '${MONGO_CONTAINER_NAME}'..."
    docker stop "${MONGO_CONTAINER_NAME}"
    echo "[SUCCESS] Container stopped."
else
    echo "[INFO] Container '${MONGO_CONTAINER_NAME}' is not running."
fi
