const { MongoClient } = require('mongodb');

const uri = 'mongodb://localhost:27017';
const dbNames = ['blog_main', 'blog_meta', 'blog_audit'];
const collectionNames = ['articles', 'tags', 'history'];
const numInserts = 100;
const numUpdates = 50;
const numDeletes = 10;

async function runBenchmark() {
    const client = new MongoClient(uri);
    try {
        await client.connect();
        console.log('Connected to MongoDB successfully!');
        const startTime = process.hrtime.bigint();

        for (let i = 0; i < dbNames.length; i++) {
            const dbName = dbNames[i];
            const collectionName = collectionNames[i];
            const db = client.db(dbName);
            const collection = db.collection(collectionName);
            console.log(`\n--- Processing ${dbName}.${collectionName} ---`);
            await collection.deleteMany({});
            const operations = [];
            for (let j = 0; j < numInserts; j++) {
                operations.push({
                    insertOne: {
                        document: {
                            _id: `doc-${dbName}-${j}`,
                            title: `Article ${j} for ${dbName}`,
                            status: 'draft',
                            timestamp: new Date()
                        }
                    }
                });
            }
            for (let j = 0; j < numUpdates; j++) {
                operations.push({
                    updateOne: {
                        filter: { _id: `doc-${dbName}-${j}` },
                        update: { $set: { status: 'published', updated_at: new Date() } }
                    }
                });
            }
            for (let j = 0; j < numDeletes; j++) {
                operations.push({
                    deleteOne: {
                        filter: { _id: `doc-${dbName}-${numInserts - 1 - j}` }
                    }
                });
            }
            console.log(`Executing bulkWrite for ${dbName}.${collectionName} with ${operations.length} operations...`);
            const result = await collection.bulkWrite(operations, { ordered: false });
            console.log(`  ✅ Inserted: ${result.insertedCount}, Updated: ${result.modifiedCount}, Deleted: ${result.deletedCount}`);
        }

        const endTime = process.hrtime.bigint();
        const totalDurationMs = Number(endTime - startTime) / 1_000_000;
        console.log(`\n--- Benchmark Results ---\nTotal time: ${totalDurationMs.toFixed(2)} ms`);
        const mainDb = client.db(dbNames[0]);
        const mainCollection = mainDb.collection(collectionNames[0]);
        const docCount = await mainCollection.countDocuments({});
        console.log(`Documents in ${dbNames[0]}.${collectionNames[0]}: ${docCount}`);
    } catch (err) {
        console.error('Failed to run benchmark:', err);
        process.exit(1);
    } finally {
        await client.close();
        console.log('Connection to MongoDB closed.');
    }
}

runBenchmark();
