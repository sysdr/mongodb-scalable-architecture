const { MongoClient } = require('mongodb');
const uri = process.env.MONGO_URI || 'mongodb://localhost:27017';
async function run() {
  const client = new MongoClient(uri, { serverSelectionTimeoutMS: 5000 });
  await client.connect();
  const db = client.db('contentDB');
  const feed = db.collection('clustered_content_feed');
  const products = db.collection('product_catalog');
  await feed.find({ userId: 'userA' }).sort({ publishTime: 1 }).toArray();
  await products.find({ categoryId: 'Electronics' }).limit(10).toArray();
  await feed.countDocuments({});
  await products.countDocuments({});
  await client.close();
  console.log('Demo queries completed. Dashboard metrics updated.');
}
run().catch(e => { console.error(e.message); process.exit(1); });
