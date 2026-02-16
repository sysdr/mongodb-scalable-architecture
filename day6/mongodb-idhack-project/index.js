const { MongoClient } = require('mongodb');
const { uuidv7 } = require('uuidv7');

const uri = "mongodb://localhost:27017";
const client = new MongoClient(uri);
const DB_NAME = "idhackDB";
const COLLECTION_NAME = "contentItems";
const NUM_DOCUMENTS = 100000;
const NUM_LOOKUPS = 10000;

async function run() {
    try {
        await client.connect();
        const database = client.db(DB_NAME);
        const collection = database.collection(COLLECTION_NAME);

        console.log(`Connected to MongoDB. Using database: ${DB_NAME}, collection: ${COLLECTION_NAME}`);

        // --- Clean up previous data ---
        console.log(`Dropping existing collection '${COLLECTION_NAME}'...`);
        await collection.drop().catch(err => {
            if (err.code !== 26) console.warn("Collection drop failed (might not exist):", err.message);
        });
        console.log("Collection clean-up complete or not needed.");

        // --- 1. Insert Documents with UUIDv7 _id ---
        console.log(`\n--- 1. Inserting ${NUM_DOCUMENTS} documents with UUIDv7 _id ---`);
        const documents = [];
        const insertedIds = [];
        for (let i = 0; i < NUM_DOCUMENTS; i++) {
            const id = uuidv7();
            documents.push({
                _id: id,
                title: `Content Item ${i} - ${id.substring(0, 8)}`,
                content: `This is the content for item number ${i}. It's quite interesting!`,
                createdAt: new Date()
            });
            insertedIds.push(id);
        }

        const insertStartTime = process.hrtime.bigint();
        const insertResult = await collection.insertMany(documents);
        const insertEndTime = process.hrtime.bigint();
        const insertDurationMs = Number(insertEndTime - insertStartTime) / 1_000_000;
        console.log(`Inserted ${insertResult.insertedCount} documents in ${insertDurationMs.toFixed(2)} ms.`);
        console.log(`Average insert rate: ${(NUM_DOCUMENTS / (insertDurationMs / 1000)).toFixed(2)} docs/sec.`);

        // --- 2. Perform Point Lookups and Benchmark ---
        console.log(`\n--- 2. Performing ${NUM_LOOKUPS} random point lookups ---`);

        // Shuffle the IDs to ensure random access patterns
        for (let i = insertedIds.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [insertedIds[i], insertedIds[j]] = [insertedIds[j], insertedIds[i]];
        }

        let totalLookupDurationNs = 0n;

        for (let i = 0; i < NUM_LOOKUPS; i++) {
            const randomIndex = Math.floor(Math.random() * insertedIds.length);
            const idToLookup = insertedIds[randomIndex];

            const lookupStartTime = process.hrtime.bigint();
            const document = await collection.findOne({ _id: idToLookup });
            const lookupEndTime = process.hrtime.bigint();

            totalLookupDurationNs += (lookupEndTime - lookupStartTime);

            if (!document) {
                console.warn(`Document with ID ${idToLookup} not found!`);
            }
        }

        const averageLookupDurationMs = Number(totalLookupDurationNs) / NUM_LOOKUPS / 1_000_000;
        const totalLookupDurationMs = Number(totalLookupDurationNs) / 1_000_000;

        console.log(`\n--- Lookup Results ---`);
        console.log(`Total documents inserted: ${NUM_DOCUMENTS}`);
        console.log(`Total lookups performed: ${NUM_LOOKUPS}`);
        console.log(`Total lookup time: ${totalLookupDurationMs.toFixed(2)} ms.`);
        console.log(`Average lookup latency per document: ${averageLookupDurationMs.toFixed(3)} ms.`);
        console.log(`Achieved lookup throughput: ${(NUM_LOOKUPS / (totalLookupDurationMs / 1000)).toFixed(2)} lookups/sec.`);

        // --- Demo and Verify: Fetch a specific document ---
        console.log("\n--- Demo & Verification: Fetching a specific document ---");
        const demoId = insertedIds[Math.floor(insertedIds.length / 2)];
        console.log(`Attempting to fetch document with ID: ${demoId}`);
        const demoDoc = await collection.findOne({ _id: demoId });
        if (demoDoc) {
            console.log("Successfully fetched document. Sample data:");
            console.log(`  _id: ${demoDoc._id}`);
            console.log(`  title: ${demoDoc.title}`);
            console.log(`  createdAt: ${demoDoc.createdAt}`);
            console.log("Verification successful! 🎉");
        } else {
            console.error("Failed to fetch demo document.");
            process.exit(1);
        }

    } catch (e) {
        console.error("An error occurred:", e);
        process.exit(1);
    } finally {
        await client.close();
        console.log("Disconnected from MongoDB.");
    }
}

run().catch(console.dir);
