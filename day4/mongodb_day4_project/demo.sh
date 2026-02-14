#!/bin/bash
# Insert demo data so dashboard metrics show non-zero values.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_HOST="${MONGO_HOST:-localhost}"
run_shell() {
    if command -v mongosh &>/dev/null; then mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "$1"
    elif command -v mongo &>/dev/null; then mongo --host "${MONGO_HOST}" --port "${MONGO_PORT}" --quiet --eval "$1"
    else echo "[ERROR] Neither mongosh nor mongo found. Run setup.sh or start.sh first."; exit 1; fi
}
for try in 1 2 3 4 5; do
    run_shell "db.adminCommand({ ping: 1 })" >/dev/null 2>&1 && break
    [ "$try" -eq 5 ] && { echo "[ERROR] MongoDB not reachable. Run ${SCRIPT_DIR}/start.sh or setup.sh first."; exit 1; }
    sleep 2
done
echo "[INFO] Inserting demo data (testdb.items)..."
run_shell "const db=db.getSiblingDB('testdb'); const ids=[]; for(let i=0;i<5000;i++) ids.push('demo_'+i); db.items.deleteMany({_id:{\$in:ids}}); for(let i=0;i<5000;i++) db.items.insertOne({_id:'demo_'+i,name:'Demo_'+i,value:Math.random()*100,ts:new Date()}); const n=db.items.countDocuments(); print('[SUCCESS] testdb.items has '+n+' document(s).');"
echo "[INFO] Current metrics:"; run_shell "var s=db.serverStatus(); if(s.opcounters) print('opcounters: '+JSON.stringify(s.opcounters)); if(s.connections) print('connections: '+s.connections.current);"
echo "[SUCCESS] Demo complete. Dashboard metrics should be non-zero."
