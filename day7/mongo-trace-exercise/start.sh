#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
MONGO_CONTAINER_NAME="mongo8-trace-exercise"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_DB="tracedb"
MONGO_USER="traceuser"
MONGO_PASS="tracepass"
CLIENT_DIR="${SCRIPT_DIR}/client"
PCAP_FILE="${SCRIPT_DIR}/capture.pcap"
METRICS_FILE="${SCRIPT_DIR}/metrics.json"

# Avoid duplicate container
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${MONGO_CONTAINER_NAME}$"; then
        echo "[INFO] MongoDB container '${MONGO_CONTAINER_NAME}' already running."
    else
        echo "[INFO] Starting existing container '${MONGO_CONTAINER_NAME}'..."
        docker start "${MONGO_CONTAINER_NAME}"
        sleep 5
    fi
else
    if ! docker info >/dev/null 2>&1; then
        echo "[ERROR] Docker is not running. Start Docker and run again."
        exit 1
    fi
    echo "[INFO] Starting MongoDB container '${MONGO_CONTAINER_NAME}'..."
    docker run -d --name "${MONGO_CONTAINER_NAME}" -p "${MONGO_PORT}:27017" \
        -e MONGO_INITDB_ROOT_USERNAME="${MONGO_USER}" -e MONGO_INITDB_ROOT_PASSWORD="${MONGO_PASS}" \
        mongo:8.0
    echo "[INFO] Waiting for MongoDB to be ready..."
    sleep 5
fi

for i in 1 2 3 4 5 6 7 8 9 10; do
    if docker exec "${MONGO_CONTAINER_NAME}" mongosh --eval "db.adminCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
        echo "[SUCCESS] MongoDB is ready."
        break
    fi
    [ "$i" -eq 10 ] && { echo "[ERROR] MongoDB not reachable."; exit 1; }
    sleep 2
done

# Run trace: tcpdump + client + tshark -> metrics.json (so dashboard has non-zero trace metrics)
echo "[INFO] Running trace (tcpdump + client + tshark) to populate metrics..."
MONGO_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${MONGO_CONTAINER_NAME}")
IFACE=$(docker network inspect bridge --format '{{(index .Options "com.docker.network.bridge.name")}}' 2>/dev/null || echo "docker0")
TCPDUMP_PID=""
if [ -n "${MONGO_IP}" ] && command -v tcpdump &>/dev/null; then
    sudo tcpdump -i "${IFACE}" -s 0 -w "${PCAP_FILE}" "port ${MONGO_PORT} and host ${MONGO_IP}" &
    TCPDUMP_PID=$!
    sleep 2
fi

export MONGO_URL="mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:${MONGO_PORT}/"
export DB_NAME="${MONGO_DB}"
export COLLECTION_NAME="testcollection"
export MONGO_USER="${MONGO_USER}"
export MONGO_PASS="${MONGO_PASS}"
export METRICS_FILE="${SCRIPT_DIR}/.client_metrics.json"
node "${CLIENT_DIR}/client.js" || true

if [ -n "${TCPDUMP_PID}" ]; then
    sudo kill "${TCPDUMP_PID}" 2>/dev/null || true
    wait "${TCPDUMP_PID}" 2>/dev/null || true
fi

# Analyze pcap and write metrics.json (fall back to client timings when tshark/pcap unavailable)
METRICS_FILE="${SCRIPT_DIR}/metrics.json"
CLIENT_METRICS="${SCRIPT_DIR}/.client_metrics.json"
if [ -f "${PCAP_FILE}" ] && command -v tshark &>/dev/null; then
    TS=$(tshark -r "${PCAP_FILE}" -Y "tcp.port == ${MONGO_PORT} and mongodb.opcode == 2014" -T fields -e frame.time_relative -e _ws.col.Info 2>/dev/null)
    COLD_AUTH_S=$(echo "${TS}" | grep "saslStart" | head -n 1 | awk '{print $1}')
    COLD_AUTH_E=$(echo "${TS}" | grep "saslContinue" | grep "OK" | head -n 1 | awk '{print $1}')
    COLD_Q_R=$(echo "${TS}" | grep "find" | head -n 1 | awk '{print $1}')
    COLD_Q_S=$(echo "${TS}" | grep "commandReply" | grep "find" | head -n 1 | awk '{print $1}')
    WARM_Q_R=$(echo "${TS}" | grep "find" | sed -n 2p | awk '{print $1}')
    WARM_Q_S=$(echo "${TS}" | grep "commandReply" | grep "find" | sed -n 2p | awk '{print $1}')
    COLD_AUTH_D=""; COLD_LAT=""; WARM_LAT=""
    [ -n "${COLD_AUTH_S}" ] && [ -n "${COLD_AUTH_E}" ] && COLD_AUTH_D=$(echo "${COLD_AUTH_E} - ${COLD_AUTH_S}" | bc -l 2>/dev/null)
    [ -n "${COLD_Q_R}" ] && [ -n "${COLD_Q_S}" ] && COLD_LAT=$(echo "${COLD_Q_S} - ${COLD_Q_R}" | bc -l 2>/dev/null)
    [ -n "${WARM_Q_R}" ] && [ -n "${WARM_Q_S}" ] && WARM_LAT=$(echo "${WARM_Q_S} - ${WARM_Q_R}" | bc -l 2>/dev/null)
    if [ -n "${COLD_LAT}" ] || [ -n "${WARM_LAT}" ] || [ -n "${COLD_AUTH_D}" ]; then
        cat > "${METRICS_FILE}" << MET
{"coldAuthDurationSec":"${COLD_AUTH_D:-0}","coldQueryLatencySec":"${COLD_LAT:-0}","warmQueryLatencySec":"${WARM_LAT:-0}","lastUpdated":"$(date -Iseconds)"}
MET
        echo "[INFO] Trace metrics written from pcap to metrics.json"
    else
        if [ -f "${CLIENT_METRICS}" ]; then
            cp "${CLIENT_METRICS}" "${METRICS_FILE}"
            echo "[INFO] Trace metrics written from client timings to metrics.json"
        else
            echo "{\"coldAuthDurationSec\":0,\"coldQueryLatencySec\":0,\"warmQueryLatencySec\":0,\"lastUpdated\":\"$(date -Iseconds)\"}" > "${METRICS_FILE}"
        fi
    fi
else
    if [ -f "${CLIENT_METRICS}" ]; then
        cp "${CLIENT_METRICS}" "${METRICS_FILE}"
        echo "[INFO] Trace metrics written from client timings to metrics.json"
    else
        echo "{\"coldAuthDurationSec\":0,\"coldQueryLatencySec\":0,\"warmQueryLatencySec\":0,\"lastUpdated\":\"$(date -Iseconds)\"}" > "${METRICS_FILE}"
    fi
fi

DASHBOARD_PID_FILE="${SCRIPT_DIR}/.dashboard.pid"
DASHBOARD_PORT="${DASHBOARD_PORT:-3000}"
dashboard_already_running=0
if [ -f "${DASHBOARD_PID_FILE}" ]; then
    pid=$(cat "${DASHBOARD_PID_FILE}" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        dashboard_already_running=1
    fi
fi
if [ "$dashboard_already_running" -eq 0 ] && (echo >/dev/tcp/127.0.0.1/${DASHBOARD_PORT}) 2>/dev/null; then
    dashboard_already_running=1
fi
if [ "$dashboard_already_running" -eq 1 ]; then
    echo "[INFO] Dashboard already running at http://localhost:${DASHBOARD_PORT} (skipping start)"
else
    echo "[INFO] Starting web dashboard..."
    node "${SCRIPT_DIR}/dashboard-server.js" &
    echo $! > "${DASHBOARD_PID_FILE}"
    echo "[SUCCESS] Web Dashboard: http://localhost:${DASHBOARD_PORT}"
fi
echo "[SUCCESS] To stop: ${SCRIPT_DIR}/stop.sh"
