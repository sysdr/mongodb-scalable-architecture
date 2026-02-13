const { MongoClient } = require('mongodb');

const uri = "mongodb://localhost:27017/";
const client = new MongoClient(uri);

async function runLoadTest(cacheSizeGB) {
    try {
        await client.connect();
        const database = client.db("admission_test_db");
        const collection = database.collection("requests");

        let counter = 0;
        console.log(`[Load Generator] Starting load test with cacheSizeGB: ${cacheSizeGB}`);

        // Insert documents rapidly
        while (true) {
            const doc = {
                requestId: `req-${process.hrtime.bigint()}`,
                payload: `data-for-request-${counter++}-${Math.random()}`.repeat(100), // Larger payload to increase dirty bytes
                timestamp: new Date()
            };
            try {
                await collection.insertOne(doc);
                process.stdout.write('.'); // Indicate progress
                if (counter % 1000 === 0) {
                    console.log(`n[Load Generator] Inserted ${counter} documents.`);
                }
            } catch (e) {
                // If MongoDB is throttling, we might see write errors or timeouts.
                // Log and continue, as the goal is to observe admission control.
                if (e.name === 'MongoServerError' || e.name === 'MongoNetworkError' || e.name === 'MongoServerSelectionError') {
                    process.stdout.write('E'); // Indicate error
                } else {
                    console.error(`n[Load Generator] Error inserting document: ${e.message}`);
                }
                // Small delay on error to prevent CPU spin if DB is truly down
                await new Promise(resolve => setTimeout(resolve, 100));
            }
        }
    } catch (e) {
        console.error(`n[Load Generator] Fatal error: ${e.message}`);
    } finally {
        // client.close(); // Keep client open to continuously insert
    }
}

// Get cache size from command line argument
const cacheSizeGB = process.argv[2] ? parseFloat(process.argv[2]) : null;
if (cacheSizeGB === null) {
    console.error("Usage: node load_generator.js <cache_size_gb>");
    process.exit(1);
}

runLoadTest(cacheSizeGB);
