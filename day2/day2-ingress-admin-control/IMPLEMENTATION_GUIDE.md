# Implementation Guide — Ingress Admission Control Demo

This project demonstrates **MongoDB Ingress Admission Control** (the “unseen bouncer”) by running a write-heavy workload against MongoDB with a configurable WiredTiger cache size. You only need this project directory to run it.

---

## Prerequisites

- **Docker** — MongoDB runs in a container. Install [Docker](https://docs.docker.com/get-docker/) and ensure the daemon is running.
- **Node.js** (v14+) — The load generator is a Node script. Install [Node.js](https://nodejs.org/) and npm.

---

## Project layout

```
day2-ingress-admin-control/
├── app/
│   ├── load_generator.js    # Writes documents to MongoDB in a loop
│   ├── package.json
│   └── node_modules/        # Created after npm install
├── data/                    # Created at runtime (MongoDB data)
├── logs/                    # Created at runtime (optional)
├── start.sh                 # Start MongoDB + load generator + dashboard
├── run_validation_test.sh   # Optional: short test that checks metrics
├── SUMMARY.md               # Summary of output and topic connection
└── IMPLEMENTATION_GUIDE.md  # This file
```

---

## First-time setup (dependencies)

Install Node dependencies for the load generator:

```bash
cd app
npm install
cd ..
```

If `app/package.json` is missing, create it and install the driver:

```bash
cd app
npm init -y
npm install mongodb
cd ..
```

---

## How to run the application

1. **From the project directory**, make the start script executable (once):

   ```bash
   chmod +x start.sh
   ```

2. **Start the demo:**

   ```bash
   ./start.sh
   ```

   This will:
   - Start MongoDB in Docker with a **small cache (0.256 GB)** by default.
   - Start the load generator (continuous inserts).
   - Show the **monitoring dashboard** (mongostat + serverStatus every 5 seconds).

3. **Stop the demo:** Press **Ctrl+C**. The script will stop the load generator and the MongoDB container.

---

## Optional: run with a different cache size

Admission control is easier to see with a small cache. To compare behavior:

- **Small cache (more pressure, queued writes):**
  ```bash
  ./start.sh 0.256
  ```

- **Larger cache (less pressure, smoother throughput):**
  ```bash
  ./start.sh 2
  ```

The number is the WiredTiger `cacheSizeGB` value.

---

## What you’ll see

- **Load generator:** Dots (`.`) for each insert; lines like `[Load Generator] Inserted 1000 documents.`
- **Dashboard:**
  - **mongostat:** `insert`, `dirty`, `used`, `res`, `net_in`, `net_out`, etc.
  - **serverStatus:** `wiredTiger.cache` (bytes in cache, dirty, eviction) and `concurrentTransactions` (write tickets in use / available).

Watch **`dirty`** (cache dirty %) and **`qw`** (queued writes) to see admission control under load. See **SUMMARY.md** for a fuller explanation of the output and how it ties to the topic.

---

## Optional: validation test

To quickly check that MongoDB and the load generator work and that cache metrics are non-zero:

```bash
chmod +x run_validation_test.sh
./run_validation_test.sh
```

Expect: `[TEST] PASS: Cache bytes non-zero (...)`.

---

## Troubleshooting

| Issue | What to do |
|-------|------------|
| `Docker is required` | Install Docker and start the daemon. |
| `Load generator not found` / `Cannot find module 'mongodb'` | Run `cd app && npm install` from the project directory. |
| Port 27017 in use | Stop any other MongoDB (local or container): `docker ps -a` and stop the conflicting container. |
| Permission denied on `data/` | If data was created by Docker as root, remove it: `sudo rm -rf data/mongodb logs/mongodb` (paths relative to project dir). |

---

## Topic connection

This demo ties to **“Configuring Ingress Admission Control: The Unseen Bouncer for High-Scale MongoDB”**:

- **Admission control** limits how many operations can use the WiredTiger cache at once (via tickets). When the cache is full or tickets are exhausted, new writes are **queued** (e.g. visible as `qw` in mongostat).
- Running with **0.256 GB** cache increases pressure and queueing; running with **2 GB** reduces it. The dashboard metrics (dirty %, write tickets, cache bytes) show the “bouncer” in action.

For a short conceptual summary and output explanation, see **SUMMARY.md**.
