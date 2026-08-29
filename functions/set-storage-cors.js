// One-shot: set CORS on the Firebase Storage bucket so images load from
// custom domains (e.g. wash.sindhole.com) in the browser.
// Run: node set-storage-cors.js  (from the functions/ directory)

const { initializeApp, cert } = require('firebase-admin/app');
const { getStorage } = require('firebase-admin/storage');
const sa = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(sa),
  storageBucket: 'wash-ledgar.firebasestorage.app',
});

async function run() {
  const bucket = getStorage().bucket();

  await bucket.setCorsConfiguration([
    {
      origin: ['*'],
      method: ['GET', 'HEAD', 'OPTIONS'],
      responseHeader: ['Content-Type', 'Authorization', 'Range'],
      maxAgeSeconds: 3600,
    },
  ]);

  // Verify it was applied
  const [meta] = await bucket.getMetadata();
  console.log('CORS applied:');
  console.log(JSON.stringify(meta.cors, null, 2));
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
