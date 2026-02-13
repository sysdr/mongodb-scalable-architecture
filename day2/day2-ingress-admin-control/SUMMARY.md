# Day 2: Admission Control Demo — Summary

## 1. Simple Explanation of the Output

### Script / phase messages (blue, green, yellow)
- **`[INFO]`** / **`[SUCCESS]`** / **`[WARNING]`** — What the script is doing (e.g. “Starting MongoDB”, “Data and logs cleaned”, “Load generator stopped”).
- You see two main phases: **Phase 1** (small cache 256 MB) and **Phase 2** (large cache 2 GB).

### Load generator lines
- Each **`.`** = one document inserted.
- **`[Load Generator] Inserted 1000 documents.`** (then 2000, 3000, …) = counter of inserts.
- Lots of dots and rising numbers = the app is hammering MongoDB with writes.

### Dashboard header
- **“MongoDB Admission Control Dashboard”** and the lines about **`qw`**, **`dirty`**, **`write.out`** tell you what to watch: **queued writes**, **how full/dirty the cache is**, and **how many write “tickets” are in use**.

### serverStatus block (purple “wiredTiger.cache & concurrentTransactions”)
- **wiredTiger.cache** — How much data is in the cache, how much is “dirty” (not yet written to disk), eviction, etc.
- **concurrentTransactions** — **`write.out`** = writes currently using a ticket, **`available`** = free tickets. This is the “bouncer” in numbers.
- These numbers show how busy the engine is and how close you are to the bouncer limiting new work.

### mongostat line (e.g. `insert 641 … dirty 2.1% used 2.1% …`)
- **insert** — Inserts per second in that 5-second window.
- **dirty** — Share of cache that is dirty (not yet flushed).
- **used** — Share of cache in use.
- **res** — Resident memory.
- **net_in / net_out** — Network traffic.
- So this line is a live snapshot: “this many inserts, this much cache pressure.”

**Bottom line:** The output is “script phases → load generator (dots + “Inserted N documents”) → dashboard (serverStatus + mongostat).” Together they show: we’re sending lots of writes, and here is how full the cache is and how many write tickets are in use.

---

## 2. Workflow Summary (What This Project Does)

| Step | What happens |
|------|------------------------|
| 1 | Script checks Docker and that no old MongoDB container is running (duplicate check). |
| 2 | Creates directories and generates the **load generator** (Node app that does `insertOne` in a loop with a big payload). |
| 3 | **Phase 1:** Starts MongoDB with a **small cache (256 MB)**. Runs the load generator so it inserts as fast as possible. Runs the **dashboard** for a few seconds (mongostat + serverStatus). Stops load generator and MongoDB. |
| 4 | Cleans data, then **Phase 2:** Starts MongoDB with a **large cache (2 GB)**. Same load generator, same dashboard. Stops everything. |
| 5 | Optionally cleans up; otherwise leaves `app/` and data for you to re-run or validate. |

So the workflow is: **two runs of the same write load, first with a tiny cache, then with a big cache**, while you watch cache and ticket usage.

---

## 3. How This Connects to “Configuring Ingress Admission Control: The Unseen Bouncer for High-Scale MongoDB”

### What the topic means
- **Ingress** = operations (reads/writes) **entering** the storage engine.
- **Admission control** = MongoDB’s internal **“bouncer”**: it decides how many of those operations are allowed to use the WiredTiger cache and run at once (via **tickets**).
- So the “unseen bouncer” is: **before** a write (or read) is allowed to run, the engine checks “do we have cache space and a free ticket?” If not, the operation is **queued** (e.g. you see **qw** in mongostat) until there’s room.

### How this project demonstrates it
- With a **small cache (256 MB)**: the cache fills up quickly under heavy inserts. The “bouncer” starts to say “no more room / no more tickets” → more operations wait in line → you’d see **queued writes (qw)** and high **dirty %** in the dashboard; throughput may dip or stabilize under pressure.
- With a **large cache (2 GB)**: same load, but more room. Fewer operations are queued; **dirty %** and pressure are lower; throughput stays higher.
- The **dashboard** (mongostat’s `dirty`, `used`, `qw` and serverStatus’s `wiredTiger.cache`, `concurrentTransactions.write.out/available`) is exactly where you **see** that bouncer in action: how full the cache is and how many writes are “in” vs “waiting.”

### One-sentence link
This practical project **shows admission control in action** by stressing MongoDB with the same write load under a small vs large cache and letting you see, on the dashboard, how the “unseen bouncer” (admission control) responds: more queueing and pressure with 256 MB, smoother behavior with 2 GB.
