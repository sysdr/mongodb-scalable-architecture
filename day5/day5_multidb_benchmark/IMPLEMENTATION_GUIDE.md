# Day 5: Multi-Database BulkWrite Benchmark — Implementation Guide

Step-by-step guide to run the MongoDB multi-database benchmark and dashboard. All steps assume you are inside this project directory or use full paths to the scripts.

---

## Prerequisites

- **Docker** — running (for MongoDB container).
- **Node.js** — for running the benchmark (`benchmark.js`).
- **mongosh** or **mongo** — optional; used by scripts for readiness checks and the metrics dashboard.

---

## Step 1: Install dependencies

From the project directory:

```bash
npm install
```

This installs the `mongodb` driver required by `benchmark.js`.

---

## Step 2: Start MongoDB and run the benchmark

Start the MongoDB container (if not already running), run the benchmark to populate data, then show the metrics dashboard:

```bash
./start.sh
```

- Starts a Docker container `mongo_day5_benchmark` on port 27017 (or reuses it if it exists).
- Runs `node benchmark.js` (bulkWrite on `blog_main`, `blog_meta`, `blog_audit`).
- Prints a dashboard (opcounters, connections) for about 15 seconds so metrics are non-zero.

To shorten the dashboard duration, for example to 5 seconds:

```bash
DASHBOARD_DURATION_SEC=5 ./start.sh
```

---

## Step 3: (Optional) Refresh demo data and metrics

To run the benchmark again and refresh dashboard metrics without restarting MongoDB:

```bash
./demo.sh
```

---

## Step 4: Run tests

Verify that required files exist, there are no duplicate MongoDB containers, MongoDB is reachable, and demo data is present (e.g. `blog_main.articles` has documents):

```bash
./run_tests.sh
```

---

## Step 5: Stop MongoDB

Stop the benchmark MongoDB container:

```bash
./stop.sh
```

---

## Step 6: Clean up (optional)

Stop the container, remove unused Docker resources (containers, images, volumes), and remove local artifacts (e.g. `node_modules`, `venv`, `.pytest_cache`, `*.pyc`, `vendor`, `*.rr`) from this project:

```bash
./cleanup.sh
```

---

## Project files (reference)

| File             | Purpose |
|------------------|--------|
| `benchmark.js`   | Node script: bulkWrite (inserts/updates/deletes) on `blog_main.articles`, `blog_meta.tags`, `blog_audit.history`. |
| `start.sh`       | Start MongoDB (Docker), run benchmark, show metrics dashboard. |
| `stop.sh`        | Stop the MongoDB container. |
| `demo.sh`        | Run benchmark again to refresh metrics. |
| `run_tests.sh`   | Check files, no duplicate services, MongoDB reachable, demo data. |
| `cleanup.sh`     | Stop container, Docker prune, remove project artifacts. |

---

## Running without Docker

If MongoDB 8.x is already running on `localhost:27017`, you can run only the benchmark:

```bash
npm install
node benchmark.js
```

Scripts that start or query MongoDB (`start.sh`, `demo.sh`, `run_tests.sh`) expect a server on port 27017; `stop.sh` and `cleanup.sh` only affect the Docker container.
