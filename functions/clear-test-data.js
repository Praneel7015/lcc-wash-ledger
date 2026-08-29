// One-shot: wipe all visits and customers (test data cleanup).
// Run: node clear-test-data.js  (from the functions/ directory)

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const sa = require('./serviceAccountKey.json');

initializeApp({ credential: cert(sa) });
const db = getFirestore();

async function deleteCollection(name) {
  let total = 0;
  let snap;
  do {
    snap = await db.collection(name).limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    console.log(`  deleted ${total} ${name} docs so far...`);
  } while (snap.size === 400);
  console.log(`✓ ${name}: ${total} documents deleted`);
}

async function run() {
  console.log('Clearing test data...');
  await deleteCollection('visits');
  await deleteCollection('customers');
  console.log('Done.');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
