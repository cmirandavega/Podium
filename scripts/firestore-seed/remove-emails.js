// One-time cleanup: removes the email field from every users document.
// Emails stay in Firebase Authentication; storing them in Firestore let any
// signed-in user read everyone's address (Sprint 4 security fix).
//
// Usage (from scripts/firestore-seed, with serviceAccountKey.json in place):
//   node remove-emails.js

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function main() {
  const users = await db.collection('users').get();
  const withEmail = users.docs.filter((d) => d.data().email !== undefined);
  for (let i = 0; i < withEmail.length; i += 400) {
    const batch = db.batch();
    for (const doc of withEmail.slice(i, i + 400)) batch.update(doc.ref, { email: FieldValue.delete() });
    await batch.commit();
  }
  console.log(`Removed the email field from ${withEmail.length} of ${users.size} user profiles.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
