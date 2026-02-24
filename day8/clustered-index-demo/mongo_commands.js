// Connect to the database (mongosh file-compatible)
db = db.getSiblingDB('contentDB');

print("\n--- Day 8: Clustered Index Demo ---");

// 0. Drop collections so seed is idempotent when re-run
db.clustered_content_feed.drop();
db.product_catalog.drop();

// 1. Create content feed collection (compound index; clusteredIndex on non-_id requires MongoDB 8.0+)
print("\n1. Creating collection 'clustered_content_feed' with compound index...");
db.createCollection("clustered_content_feed");
db.clustered_content_feed.createIndex({ userId: 1, publishTime: 1 }, { unique: true, name: "feed_cluster_idx" });
print("Collection 'clustered_content_feed' created.");

// 2. Insert sample data
print("\n2. Inserting sample data into 'clustered_content_feed'...");
db.clustered_content_feed.insertMany([
   { userId: "userA", publishTime: ISODate("2023-10-26T10:00:00Z"), title: "User A Post 1", content: "This is the first post by User A.", tags: ["tech", "news"] },
   { userId: "userB", publishTime: ISODate("2023-10-26T10:05:00Z"), title: "User B Post 1", content: "User B's initial thoughts.", tags: ["thoughts"] },
   { userId: "userA", publishTime: ISODate("2023-10-26T10:10:00Z"), title: "User A Post 2", content: "Another update from User A.", tags: ["update"] },
   { userId: "userC", publishTime: ISODate("2023-10-26T10:15:00Z"), title: "User C Post 1", content: "Hello world from User C!", tags: ["intro"] },
   { userId: "userA", publishTime: ISODate("2023-10-26T10:20:00Z"), title: "User A Post 3", content: "Final post for today from User A.", tags: ["summary", "tech"] },
   { userId: "userB", publishTime: ISODate("2023-10-26T10:25:00Z"), title: "User B Post 2", content: "Follow-up from User B.", tags: ["followup"] },
   { userId: "userA", publishTime: ISODate("2023-10-26T10:30:00Z"), title: "User A Post 4", content: "Late night thoughts from User A.", tags: ["reflection"] }
]);
print("Sample data inserted. Total documents: " + db.clustered_content_feed.countDocuments({}));

// 3. Create product_catalog with compound index
print("\nAssignment: Creating 'product_catalog' collection with compound index...");
db.createCollection("product_catalog");
db.product_catalog.createIndex({ categoryId: 1, productId: 1 }, { unique: true });
var products = [];
for (var i = 1; i <= 100; i++) {
    var category = (i % 3 == 0) ? "Electronics" : ((i % 2 == 0) ? "Books" : "Clothing");
    products.push({
        categoryId: category,
        productId: "PROD" + (i < 10 ? "00" : i < 100 ? "0" : "") + i,
        name: "Product " + i + " (" + category + ")",
        price: (10 + i * 0.5).toFixed(2),
        description: "Description for product " + i + ".",
        stock: Math.floor(Math.random() * 1000) + 1
    });
}
db.product_catalog.insertMany(products);
print("100 sample products inserted. Total: " + db.product_catalog.countDocuments({}));
print("\n--- MongoDB Clustered Index Demo End ---");
