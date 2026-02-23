const { MongoClient } = require('mongodb');
const fs = require('fs');
const path = require('path');

async function runTest(url, dbName, collectionName, username, password) {
    let client;
    let coldMs = 0;
    let warmMs = 0;
    try {
        console.log("--- Client: Attempting initial connection and query (cold path)...");
        const startCold = process.hrtime.bigint();
        client = new MongoClient(url, {
            auth: { username, password },
            serverSelectionTimeoutMS: 5000,
            connectTimeoutMS: 5000,
            socketTimeoutMS: 5000,
            maxPoolSize: 1
        });
        await client.connect();
        const db = client.db(dbName);
        const collection = db.collection(collectionName);
        await collection.insertOne({ timestamp: new Date(), message: "initial data" }).catch(() => {});
        await collection.findOne({});
        const endCold = process.hrtime.bigint();
        coldMs = Number(endCold - startCold) / 1_000_000;
        console.log(`--- Client: Initial connection & query completed in: ${coldMs} ms`);

        console.log("--- Client: Attempting subsequent query on same connection (warm path)...");
        const startWarm = process.hrtime.bigint();
        await collection.findOne({});
        const endWarm = process.hrtime.bigint();
        warmMs = Number(endWarm - startWarm) / 1_000_000;
        console.log(`--- Client: Subsequent query completed in: ${warmMs} ms`);
    } catch (e) {
        console.error("--- Client: Error during test:", e.message);
        process.exit(1);
    } finally {
        if (client) {
            await client.close();
            console.log("--- Client: Connection closed.");
        }
    }
    const metricsFile = process.env.METRICS_FILE;
    if (metricsFile && (coldMs > 0 || warmMs > 0)) {
        try {
            const dir = path.dirname(metricsFile);
            if (dir) fs.mkdirSync(dir, { recursive: true });
            fs.writeFileSync(metricsFile, JSON.stringify({
                coldAuthDurationSec: 0,
                coldQueryLatencySec: coldMs / 1000,
                warmQueryLatencySec: warmMs / 1000,
                lastUpdated: new Date().toISOString(),
                source: 'client'
            }), 'utf8');
        } catch (e) {
            console.error("--- Client: Could not write metrics file:", e.message);
        }
    }
}

const MONGO_URL = process.env.MONGO_URL || `mongodb://localhost:${process.env.MONGO_PORT || '27017'}/`;
const DB_NAME = process.env.DB_NAME || 'testdb';
const COLLECTION_NAME = process.env.COLLECTION_NAME || 'testcollection';
const MONGO_USER = process.env.MONGO_USER || 'admin';
const MONGO_PASS = process.env.MONGO_PASS || 'password';

runTest(MONGO_URL, DB_NAME, COLLECTION_NAME, MONGO_USER, MONGO_PASS);
