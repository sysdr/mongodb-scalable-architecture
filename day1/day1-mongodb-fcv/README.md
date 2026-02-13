# Day 1 – MongoDB 8.0 FCV setup (day1-mongodb-dcv)

This project directory holds config, data, and helper scripts. **`setup.sh`** lives in the parent directory (`day1/`) and creates/updates this structure.

## Quick start

1. **Generate files and start MongoDB** (Docker or local) — run from **day1** (parent of this directory):
   ```bash
   /path/to/day1/setup.sh          # interactive: choose Docker or local
   # Or non-interactive:
   DEPLOY_METHOD=1 /path/to/day1/setup.sh   # Docker
   DEPLOY_METHOD=2 /path/to/day1/setup.sh   # local mongod
   # Generate only (no MongoDB start):
   GENERATE_ONLY=1 /path/to/day1/setup.sh
   ```

2. **Start MongoDB** (checks for existing container/process, no duplicates) — run from this directory or by full path:
   ```bash
   /path/to/day1/day1-mongodb-dcv/start.sh
   ```

3. **Run tests** (generated files, duplicate services, reachability, demo data):
   ```bash
   /path/to/day1/day1-mongodb-dcv/run_tests.sh
   ```

4. **Demo data for dashboard metrics** (so dashboard values are not zero):
   ```bash
   /path/to/day1/day1-mongodb-dcv/demo.sh
   ```
   Inserts sample documents into `day1_demo.metrics` and prints server metrics. Run after MongoDB is started so any dashboard you use shows non-zero ops and document counts.

## Generated files (verified by setup and tests)

- `./data/db` – MongoDB data directory  
- `./data/log` – MongoDB log directory  
- `./config` – Config directory  
- `./config/mongod.conf` – Generated `mongod` config for local reference  

## Dashboard validation

- **Values should not be zero**: After starting MongoDB, run `./demo.sh` (or `run_tests.sh`, which runs a small demo) to insert data and generate activity.
- **Metrics updated by demo**: The demo inserts into `day1_demo.metrics` and triggers server stats (connections, opcounters). Refresh your dashboard after running the demo to see non-zero values.

## Scripts

| Script       | Location | Purpose |
|-------------|-----------|---------|
| `setup.sh`  | **day1/** (parent) | Create dirs in day1-mongodb-dcv, generate `config/mongod.conf`, optionally start MongoDB and set FCV 8.0. |
| `start.sh`  | day1-mongodb-dcv/ | Start MongoDB (Docker or local), avoiding duplicate containers/processes; calls parent `setup.sh`. |
| `run_tests.sh` | day1-mongodb-dcv/ | Verify generated files, no duplicate services, optional reachability and demo. |
| `demo.sh`   | day1-mongodb-dcv/ | Insert demo data so dashboard metrics are non-zero. |
