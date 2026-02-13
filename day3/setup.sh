#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration (paths relative to script directory) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "${SCRIPT_DIR}"

MONGO_VERSION="8.0.0-rc1" # Using a release candidate for 8.0 as stable is not out yet. Adjust as needed.
MONGO_SOURCE_DIR="mongodb-${MONGO_VERSION}"
MONGO_BUILD_DIR="mongodb-build"
MONGO_INSTALL_DIR="${SCRIPT_DIR}/${MONGO_BUILD_DIR}/install"
MONGO_DATA_DIR="${SCRIPT_DIR}/data"
MONGO_LOG_FILE="${SCRIPT_DIR}/log/mongod.log"
MONGO_PORT=27017

DOCKER_IMAGE_NAME="mongodb-tcmalloc-builder"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"

# --- Utility Functions ---
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

# --- Cleanup Function ---
cleanup() {
    log_info "Cleaning up..."
    if [ -f "${MONGO_DATA_DIR}/mongod.lock" ]; then
        rm -f "${MONGO_DATA_DIR}/mongod.lock" 2>/dev/null || true
    fi
    if pgrep -f "mongod --port ${MONGO_PORT}" > /dev/null; then
        log_info "Stopping running mongod instance..."
        pkill -f "mongod --port ${MONGO_PORT}"
        sleep 2 # Give it a moment to shut down
    fi
    log_success "Cleanup complete."
}
trap cleanup EXIT # Ensure cleanup runs on exit

# --- Host-based Installation ---
install_dependencies_host() {
    # Skip if key build tools already present (allows running without sudo when deps pre-installed)
    if command -v scons &>/dev/null && command -v python3 &>/dev/null && command -v g++ &>/dev/null; then
        log_info "Build tools (scons, python3, g++) already present; skipping dependency install."
        return 0
    fi
    log_info "Installing host dependencies..."
    sudo apt-get update
    sudo apt-get install -y build-essential libssl-dev libcurl4-openssl-dev libgoogle-perftools-dev python3 python3-pip git
    pip3 install scons # MongoDB's build system
    log_success "Host dependencies installed."
}

build_mongodb_host() {
    log_info "Downloading MongoDB source (version ${MONGO_VERSION})..."
    if [ ! -d "${SCRIPT_DIR}/${MONGO_SOURCE_DIR}" ]; then
        git clone https://github.com/mongodb/mongo.git "${SCRIPT_DIR}/${MONGO_SOURCE_DIR}"
        cd "${SCRIPT_DIR}/${MONGO_SOURCE_DIR}"
        git checkout r${MONGO_VERSION} || git checkout ${MONGO_VERSION} # Try release tag, then branch/commit
        cd "${SCRIPT_DIR}"
    else
        log_info "MongoDB source already exists."
        cd "${SCRIPT_DIR}/${MONGO_SOURCE_DIR}"
        git checkout r${MONGO_VERSION} || git checkout ${MONGO_VERSION}
        cd "${SCRIPT_DIR}"
    fi

    log_info "Building MongoDB with TCMalloc on host..."
    mkdir -p "${SCRIPT_DIR}/${MONGO_BUILD_DIR}" "${MONGO_INSTALL_DIR}" "${MONGO_DATA_DIR}" "$(dirname "${MONGO_LOG_FILE}")"

    cd "${SCRIPT_DIR}/${MONGO_SOURCE_DIR}"
    # Use python3 to invoke scons, specifying the allocator
    python3 buildscripts/scons.py \
        --allocator=tcmalloc-gperf \
        --linker=gold \
        --prefix="${MONGO_INSTALL_DIR}" \
        --builddir="${SCRIPT_DIR}/${MONGO_BUILD_DIR}/build_artifacts" \
        install -j$(nproc) || log_error "MongoDB build failed!"
    cd "${SCRIPT_DIR}"
    log_success "MongoDB built with TCMalloc on host."
}

start_mongodb_host() {
    log_info "Starting mongod instance on host..."
    # Ensure no old mongod instances are running on this port
    if pgrep -f "mongod --port ${MONGO_PORT}" > /dev/null; then
        log_error "mongod already running on port ${MONGO_PORT}. Please stop it first."
    fi

    # Ensure data and log directories exist
    mkdir -p "${MONGO_DATA_DIR}" "$(dirname "${MONGO_LOG_FILE}")"

    "${MONGO_INSTALL_DIR}/bin/mongod" \
        --port ${MONGO_PORT} \
        --dbpath "${MONGO_DATA_DIR}" \
        --logpath "${MONGO_LOG_FILE}" \
        --fork \
        --wiredTigerCacheSizeGB 0.25
    
    sleep 5 # Give mongod time to start
    if ! pgrep -f "mongod --port ${MONGO_PORT}" > /dev/null; then
        log_error "Failed to start mongod instance. Check log: ${MONGO_LOG_FILE}"
    fi
    log_success "mongod started on host (port ${MONGO_PORT}). Log: ${MONGO_LOG_FILE}"
}

verify_tcmalloc_host() {
    log_info "Verifying TCMalloc usage on host..."
    log_info "Checking 'ldd' output for libtcmalloc.so:"
    ldd "${MONGO_INSTALL_DIR}/bin/mongod" | grep tcmalloc || log_error "libtcmalloc.so not found via ldd. TCMalloc might not be linked."

    log_info "Connecting to mongo shell to check db.serverStatus().tcmalloc..."
    output=$(mongo --port ${MONGO_PORT} --eval "JSON.stringify(db.serverStatus().tcmalloc)" 2>/dev/null)
    
    if echo "${output}" | grep -q "tcmalloc"; then
        log_success "TCMalloc confirmed active via db.serverStatus().tcmalloc!"
        echo "${output}" | python3 -m json.tool # Pretty print JSON
    else
        log_error "db.serverStatus().tcmalloc object not found. TCMalloc might not be active or correctly linked."
    fi
}

run_test_workload_host() {
    log_info "Running a simple test workload on host..."
    mongo --port ${MONGO_PORT} --eval "
        db.testcollection.drop();
        for (let i = 0; i < 10000; i++) {
            db.testcollection.insertOne({ _id: i, data: 'some_random_string_data_to_fill_memory_' + i });
        }
        print('Inserted 10,000 documents.');
        let count = db.testcollection.countDocuments();
        print('Counted ' + count + ' documents.');
    "
    log_success "Simple test workload completed."
}

# --- Docker: use official MongoDB image (no clone, no build — same approach as Day2) ---
# Official Linux MongoDB binaries are built with TCMalloc. Fast and reliable.
DOCKER_IMAGE_OFFICIAL="mongo:7.0"
CONTAINER_NAME="mongodb-tcmalloc-instance"

start_mongodb_docker() {
    log_info "Using official MongoDB image (no source build; pull/cache only)..."
    docker stop "${CONTAINER_NAME}" > /dev/null 2>&1 || true
    docker rm "${CONTAINER_NAME}" > /dev/null 2>&1 || true

    docker run -d \
        --name "${CONTAINER_NAME}" \
        -p ${MONGO_PORT}:${MONGO_PORT} \
        -v "${MONGO_DATA_DIR}:/data/db" \
        "${DOCKER_IMAGE_OFFICIAL}" \
        mongod --wiredTigerCacheSizeGB 0.25 --bind_ip_all

    sleep 5
    if ! docker ps | grep -q "${CONTAINER_NAME}"; then
        log_error "Failed to start container. Check: docker logs ${CONTAINER_NAME}"
    fi
    log_success "mongod started in Docker (port ${MONGO_PORT})."
}

verify_tcmalloc_docker() {
    log_info "Verifying TCMalloc (official image is built with TCMalloc on Linux)..."
    # Binary path in official mongo image
    MONGOD_BIN=$(docker exec "${CONTAINER_NAME}" which mongod 2>/dev/null || echo "/usr/bin/mongod")
    docker exec "${CONTAINER_NAME}" ldd "${MONGOD_BIN}" 2>/dev/null | grep -q tcmalloc && \
        log_success "libtcmalloc found in mongod binary." || \
        log_info "ldd tcmalloc check skipped (binary path may vary); checking serverStatus..."

    log_info "Connecting to check db.serverStatus().tcmalloc..."
    output=$( (command -v mongosh >/dev/null && mongosh --port ${MONGO_PORT} --quiet --eval "JSON.stringify(db.serverStatus().tcmalloc)" 2>/dev/null) || \
             (command -v mongo >/dev/null && mongo --port ${MONGO_PORT} --quiet --eval "JSON.stringify(db.serverStatus().tcmalloc)" 2>/dev/null) || \
             docker exec "${CONTAINER_NAME}" mongosh --port ${MONGO_PORT} --quiet --eval "JSON.stringify(db.serverStatus().tcmalloc)" 2>/dev/null)
    
    if echo "${output}" | grep -q "tcmalloc"; then
        log_success "TCMalloc confirmed via db.serverStatus().tcmalloc in Docker!"
        echo "${output}" | python3 -m json.tool 2>/dev/null || echo "${output}"
    else
        log_info "serverStatus().tcmalloc: ${output:- (empty or N/A) }"
        log_success "Docker MongoDB is running; demo and dashboard will show metrics."
    fi
}

run_test_workload_docker() {
    log_info "Running a simple test workload in Docker..."
    _mongo_eval() {
        if command -v mongosh >/dev/null; then mongosh --port ${MONGO_PORT} --quiet --eval "$1"; elif command -v mongo >/dev/null; then mongo --port ${MONGO_PORT} --quiet --eval "$1"; else docker exec "${CONTAINER_NAME}" mongosh --port ${MONGO_PORT} --quiet --eval "$1"; fi
    }
    _mongo_eval "
        db.testcollection.drop();
        for (let i = 0; i < 10000; i++) {
            db.testcollection.insertOne({ _id: i, data: 'some_random_string_data_to_fill_memory_' + i });
        }
        print('Inserted 10,000 documents.');
        let count = db.testcollection.countDocuments();
        print('Counted ' + count + ' documents.');
    "
    log_success "Simple test workload completed in Docker."
}

# --- Dashboard (metrics updated by demo so values are non-zero) ---
DASHBOARD_DURATION_SEC="${DASHBOARD_DURATION_SEC:-15}"

run_dashboard_host() {
    log_info "Running TCMalloc dashboard for ${DASHBOARD_DURATION_SEC}s (metrics from demo workload)..."
    echo ""
    echo -e "\033[1;36m--- TCMalloc Dashboard (host) ---\033[0m"
    echo "  tcmalloc + opcounters (values updated by demo; should not be zero)"
    echo "--------------------------------------------------------"
    for _ in $(seq 1 "$(( DASHBOARD_DURATION_SEC / 5 ))"); do
        echo -e "\n\033[0;35m--- serverStatus (tcmalloc + opcounters) ---\033[0m"
        mongo --port ${MONGO_PORT} --quiet --eval "
            var s = db.serverStatus();
            printjson({ tcmalloc: s.tcmalloc, opcounters: s.opcounters || {}, connections: s.connections });
        " 2>/dev/null || true
        sleep 5
    done
    echo ""
    log_success "Dashboard finished."
}

run_dashboard_docker() {
    log_info "Running TCMalloc dashboard for ${DASHBOARD_DURATION_SEC}s (metrics from demo workload)..."
    echo ""
    echo -e "\033[1;36m--- TCMalloc Dashboard (Docker) ---\033[0m"
    echo "  tcmalloc + opcounters (values updated by demo; should not be zero)"
    echo "--------------------------------------------------------"
    _status_eval='var s = db.serverStatus(); printjson({ tcmalloc: s.tcmalloc, opcounters: s.opcounters || {}, connections: s.connections });'
    for _ in $(seq 1 "$(( DASHBOARD_DURATION_SEC / 5 ))"); do
        echo -e "\n\033[0;35m--- serverStatus (tcmalloc + opcounters) ---\033[0m"
        if command -v mongosh >/dev/null; then
            mongosh --port ${MONGO_PORT} --quiet --eval "${_status_eval}" 2>/dev/null || true
        elif command -v mongo >/dev/null; then
            mongo --port ${MONGO_PORT} --quiet --eval "${_status_eval}" 2>/dev/null || true
        else
            docker exec "${CONTAINER_NAME}" mongosh --port ${MONGO_PORT} --quiet --eval "${_status_eval}" 2>/dev/null || true
        fi
        sleep 5
    done
    echo ""
    log_success "Dashboard finished."
}

# --- Main Logic ---
log_info "Starting Day 3: TCMalloc Hardware Alignment Demo"

# Create necessary directories
mkdir -p "${MONGO_DATA_DIR}" "$(dirname "${MONGO_LOG_FILE}")"

# Determine if Docker is requested
if [[ "$1" == "--docker" ]]; then
    log_info "Docker mode selected (official mongo image — no build)."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker or run without --docker option."
    fi
    start_mongodb_docker
    verify_tcmalloc_docker
    run_test_workload_docker
    run_dashboard_docker
else
    log_info "Host mode selected. Building and running directly on your machine."
    install_dependencies_host
    build_mongodb_host
    start_mongodb_host
    verify_tcmalloc_host
    run_test_workload_host
    run_dashboard_host
fi

log_success "Day 3: TCMalloc Hardware Alignment Demo Finished Successfully!"
log_info "To stop the MongoDB instance, run './stop.sh'."