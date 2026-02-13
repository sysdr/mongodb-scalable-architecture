#!/bin/bash
# Stop project containers and remove unused Docker resources (containers, volumes, images).
# Run from the project directory (day2-ingress-admin-control).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_CONTAINER_NAME="mongo_admission_test"

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_ok()   { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }

# 1. Stop project container
log_info "Stopping project container: ${MONGO_CONTAINER_NAME}..."
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    docker stop "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
    docker rm -f "${MONGO_CONTAINER_NAME}" 2>/dev/null || true
    log_ok "Container ${MONGO_CONTAINER_NAME} stopped and removed."
else
    log_warn "Container ${MONGO_CONTAINER_NAME} not found."
fi

# 2. Stop any other running containers (optional, project-specific)
# Uncomment to stop all: docker stop $(docker ps -q) 2>/dev/null || true

# 3. Remove unused Docker resources
log_info "Removing unused Docker containers..."
docker container prune -f

log_info "Removing unused Docker volumes..."
docker volume prune -f

log_info "Removing unused Docker images (dangling only)..."
docker image prune -f

log_info "Removing unused Docker networks..."
docker network prune -f

# Optional: full system prune (removes all unused data, not just dangling)
# Uncomment to aggressively free space:
# log_info "Running docker system prune (all unused resources)..."
# docker system prune -af --volumes

log_ok "Cleanup complete."
