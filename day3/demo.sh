#!/bin/bash
# Insert demo data so dashboard metrics show non-zero values. Run after MongoDB is started (./start.sh or setup.sh).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="mongodb-tcmalloc-instance"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_HOST="${MONGO_HOST:-localhost}"

run_shell() {
    local eval_arg="$1"
    if docker ps -f name="${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        # Container has mongosh (mongo:7.0+), not legacy mongo
        docker exec "${CONTAINER_NAME}" mongosh --port "${MONGO_PORT}" --quiet --eval "$eval_arg"
    elif command -v mongosh &>/dev/null; then
        mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "$eval_arg"
    elif command -v mongo &>/dev/null; then
        mongo --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "$eval_arg"
    else
        echo "[ERROR] MongoDB not reachable and neither mongosh nor mongo found. Run ./start.sh or setup.sh first."
        exit 1
    fi
}

# Allow a moment for MongoDB to accept connections after start
for try in 1 2 3 4 5; do
    if run_shell "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
        break
    fi
    if [ "$try" -eq 5 ]; then
        echo "[ERROR] MongoDB not reachable. Run ./start.sh or setup.sh first."
        exit 1
    fi
    sleep 2
done

echo "[INFO] Inserting demo data (testcollection) for TCMalloc dashboard..."
run_shell "
    db.testcollection.drop();
    for (let i = 0; i < 10000; i++) {
        db.testcollection.insertOne({ _id: i, data: 'demo_data_' + i, ts: new Date() });
    }
    const n = db.testcollection.countDocuments();
    print('[SUCCESS] Inserted ' + n + ' documents into testcollection.');
"

echo "[INFO] Current server metrics (for dashboard validation):"
run_shell "
    var s = db.serverStatus();
    if (s.tcmalloc) print('tcmalloc: present');
    if (s.opcounters) print('opcounters: ' + JSON.stringify(s.opcounters));
    if (s.connections) print('connections.current: ' + s.connections.current);
"

echo "[SUCCESS] Demo complete. Dashboard metrics should show non-zero values after refresh."
