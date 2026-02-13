# Day 3: TCMalloc Hardware Alignment Demo

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Build MongoDB with TCMalloc (host or `--docker`), start server, run demo workload, then **dashboard** (tcmalloc + opcounters; values non-zero from workload). |
| `start.sh` | Start MongoDB only (full path to binary; checks for duplicate services). Run from day3 or use full path. |
| `stop.sh` | Stop host mongod and/or Docker container. |
| `demo.sh` | Insert demo data so dashboard metrics are non-zero. Run after MongoDB is started. |
| `run_tests.sh` | Verify generated files, no duplicate services, MongoDB reachable, TCMalloc and demo metrics. |

## Generated files (by setup)

- **Host:** `data/`, `log/`, `mongodb-<version>/` (source), `mongodb-build/install/` (binaries).
- **Docker:** `Dockerfile`, `data/`, `log/`, Docker image and container.

## Usage

1. **Full setup (Docker; no sudo):**  
   `./setup.sh --docker`  
   (Builds image, starts container, runs workload, then dashboard with non-zero metrics.)

2. **Full setup (host):**  
   `./setup.sh`  
   (Installs deps if needed, builds MongoDB with TCMalloc, starts mongod, runs workload and dashboard.)

3. **Start only (after setup):**  
   `./start.sh`  
   or full path:  
   `/path/to/day3/start.sh`

4. **Stop:**  
   `./stop.sh`

5. **Demo (populate metrics):**  
   `./demo.sh`

6. **Tests:**  
   `./run_tests.sh`

## Dashboard

The dashboard runs at the end of `setup.sh` (after the demo workload), so **tcmalloc** and **opcounters** show non-zero values. To refresh metrics later, run `./demo.sh` then inspect serverStatus (tcmalloc, opcounters, connections).
