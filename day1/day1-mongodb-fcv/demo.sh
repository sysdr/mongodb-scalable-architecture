#!/bin/bash
# Insert demo data so dashboard/metrics show non-zero values. Run after MongoDB is started.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CONTAINER_NAME="mongo-fcv-day1"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_HOST="${MONGO_HOST:-localhost}"

run_mongosh() {
    if docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        docker exec "${CONTAINER_NAME}" mongosh --quiet --eval "$1"
    elif command -v mongosh &>/dev/null; then
        mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "$1"
    else
        echo "[ERROR] MongoDB not reachable and mongosh not installed. Run ./start.sh first (Docker) or install mongosh."
        exit 1
    fi
}

if ! run_mongosh "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
    echo "[ERROR] MongoDB not reachable. Run ./start.sh or setup.sh first."
    exit 1
fi

echo "[INFO] Inserting demo data into day1_demo.metrics..."
run_mongosh "
    const db = db.getSiblingDB('day1_demo');
    for (let i = 0; i < 10; i++) {
        db.metrics.insertOne({
            ts: new Date(),
            type: 'demo',
            value: Math.floor(Math.random() * 100),
            label: 'metric_' + i
        });
    }
    const n = db.metrics.countDocuments();
    print('[SUCCESS] Inserted demo documents. Total in day1_demo.metrics: ' + n);
"

echo "[INFO] Current server metrics (for dashboard validation):"
run_mongosh "
    const s = db.serverStatus();
    if (s.connections) print('connections.current: ' + s.connections.current);
    if (s.opcounters) print('opcounters: ' + JSON.stringify(s.opcounters));
    if (s.metrics && s.metrics.document) print('documents: inserted=' + (s.metrics.document.inserted || 0) + ', updated=' + (s.metrics.document.updated || 0));
"

echo "[SUCCESS] Demo complete. Dashboard metrics should reflect non-zero values after refresh."
