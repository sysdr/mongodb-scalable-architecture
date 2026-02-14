// generate_load.js
let docs = [];
const numDocs = 500000; // Total documents to insert
const batchSize = 10000; // Documents per batch

print("Starting data insertion into 'testdb.items'...");
for (let i = 0; i < numDocs; i++) {
    docs.push({
        _id: i,
        name: "Item_" + i + "_" + Date.now(),
        value: Math.random() * 1000,
        tags: ["tag" + (i % 10), "common_tag", "day4_test"],
        timestamp: new Date()
    });
    if (docs.length === batchSize) {
        db.items.insertMany(docs);
        docs = [];
        print("  Inserted " + (i + 1) + " documents...");
    }
}
if (docs.length > 0) {
    db.items.insertMany(docs);
}
print("Data insertion complete. Total documents: " + numDocs);
