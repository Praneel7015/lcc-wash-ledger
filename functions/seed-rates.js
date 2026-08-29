// One-shot: wipe old rates and write correct ones.
// Run: node seed-rates.js

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const sa = require('./serviceAccountKey.json');

initializeApp({ credential: cert(sa) });
const db = getFirestore();

const rates = {
  'hatch_sedan__exterior':  { vehicleType: 'hatch_sedan', packageId: 'exterior',  amountRupees: 199  },
  'hatch_sedan__full':      { vehicleType: 'hatch_sedan', packageId: 'full',       amountRupees: 299  },
  'hatch_sedan__underbody': { vehicleType: 'hatch_sedan', packageId: 'underbody',  amountRupees: 399  },
  'hatch_sedan__detailing': { vehicleType: 'hatch_sedan', packageId: 'detailing',  amountRupees: 1299 },
  'suv__exterior':          { vehicleType: 'suv',         packageId: 'exterior',   amountRupees: 299  },
  'suv__full':              { vehicleType: 'suv',         packageId: 'full',       amountRupees: 349  },
  'suv__underbody':         { vehicleType: 'suv',         packageId: 'underbody',  amountRupees: 499  },
  'suv__detailing':         { vehicleType: 'suv',         packageId: 'detailing',  amountRupees: 1999 },
  'bike__bike_wash':        { vehicleType: 'bike',        packageId: 'bike_wash',  amountRupees: 64   },
};

async function run() {
  const snap = await db.collection('rates').get();
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  Object.entries(rates).forEach(([key, val]) => {
    batch.set(db.collection('rates').doc(key), val);
  });
  await batch.commit();
  console.log(`✓ Done — ${Object.keys(rates).length} rates written to Firestore`);
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
