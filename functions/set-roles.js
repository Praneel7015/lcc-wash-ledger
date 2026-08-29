// One-time script to assign Firebase Auth custom claims (roles).
// Run with: node set-roles.js
// Requires: serviceAccountKey.json in the same folder (never commit this file).

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const roles = [
  { uid: '4LuxviSp9ffyDh8236aN1AFIN1X2', role: 'worker' },
  { uid: '8CIJSp18raXuDB1lxq9HdkPQ3tx1', role: 'owner' },
  { uid: 'v4Nsf4zMZbQAvex0IaGqx8WwOm82', role: 'owner' },
];

async function main() {
  for (const { uid, role } of roles) {
    await admin.auth().setCustomUserClaims(uid, { role });
    console.log(`✓ role=${role} set on ${uid}`);
  }
  console.log('All done — roles assigned.');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
