// Script to assign Firebase Auth custom claims (roles) and display names.
// Run with: node set-roles.js
// Requires: serviceAccountKey.json in the same folder (never commit this file).

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const auth = getAuth();

const users = [
  { uid: '4LuxviSp9ffyDh8236aN1AFIN1X2', role: 'worker',  displayName: 'Worker' },
  { uid: 'TgCxG6oAJvN1c9aumWvBPUWQTkd2', role: 'worker',  displayName: 'Ganesh' },
  { uid: '9PVG7jWfHQbFKuywvpho4Fmq4TC2', role: 'worker',  displayName: 'Temporary Worker' },
  { uid: 'WqjnwlBJgqfblA3m4Ze5R5S9Zym2', role: 'worker',  displayName: 'Mithilesh' },
  { uid: '8CIJSp18raXuDB1lxq9HdkPQ3tx1', role: 'owner',   displayName: 'Praneel' },
  { uid: 'v4Nsf4zMZbQAvex0IaGqx8WwOm82', role: 'owner',   displayName: 'Owner' },
  // Add new users below — copy the UID from Firebase Console after creating the account
  // { uid: 'CAPTAIN1_UID_HERE', role: 'worker', displayName: 'Captain 1' },
  // { uid: 'CAPTAIN2_UID_HERE', role: 'worker', displayName: 'Captain 2' },
];

async function main() {
  for (const { uid, role, displayName } of users) {
    await auth.setCustomUserClaims(uid, { role });
    await auth.updateUser(uid, { displayName });
    console.log(`✓ ${displayName} — role=${role}, uid=${uid}`);
  }
  console.log('All done.');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
