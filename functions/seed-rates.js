// One-shot: wipe old rates and packages, then write correct ones.
// Run: node seed-rates.js  (from functions/ directory)

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

const packages = {
  'exterior': {
    label: 'Express Exterior Wash',
    description: "A fast rinse and shine when you're short on time.",
    vehicleTypes: ['hatch_sedan', 'suv'],
    order: 1,
  },
  'full': {
    label: 'Exterior + Interior Wash',
    description: 'Full clean, inside and out.',
    vehicleTypes: ['hatch_sedan', 'suv'],
    order: 2,
  },
  'underbody': {
    label: 'Exterior + Interior + Under Body',
    description: 'Full clean + vacuum, under body wash & tyre polish.',
    vehicleTypes: ['hatch_sedan', 'suv'],
    order: 3,
  },
  'detailing': {
    label: 'Full Detailing',
    description: 'Deep clean, shampoo, wax, tyre shine — like new.',
    vehicleTypes: ['hatch_sedan', 'suv'],
    order: 4,
  },
  'bike_wash': {
    label: 'Express Bike Wash',
    description: 'Quick exterior rinse and shine for two-wheelers.',
    vehicleTypes: ['bike'],
    order: 1,
  },
};

async function run() {
  // ── Rates ────────────────────────────────────────────────────────────
  const rateSnap = await db.collection('rates').get();
  const rateBatch = db.batch();
  rateSnap.docs.forEach(d => rateBatch.delete(d.ref));
  Object.entries(rates).forEach(([key, val]) => {
    rateBatch.set(db.collection('rates').doc(key), val);
  });
  await rateBatch.commit();
  console.log(`✓ Rates — ${Object.keys(rates).length} docs written`);

  // ── Packages ─────────────────────────────────────────────────────────
  const pkgSnap = await db.collection('packages').get();
  const pkgBatch = db.batch();
  pkgSnap.docs.forEach(d => pkgBatch.delete(d.ref));
  Object.entries(packages).forEach(([id, data]) => {
    pkgBatch.set(db.collection('packages').doc(id), data);
  });
  await pkgBatch.commit();
  console.log(`✓ Packages — ${Object.keys(packages).length} docs written`);

  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
