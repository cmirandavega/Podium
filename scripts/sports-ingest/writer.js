// Writes ingested data to Firestore with the Admin SDK, using the Section 6 schema:
//   players/{SPORT}_{externalApiId}
//   playerStats/{SPORT}_{externalApiId}_{gameId}
//   scoringPeriods/period_{season}_w{week}
// Stat and period documents are replaced in full so stat corrections never leave stale values.
// Document IDs are deterministic, so re-running ingest.js updates documents instead of duplicating them.
const path = require('path');

let db = null;
let admin = null;

function connect() {
  if (db) return db;
  const { initializeApp, cert } = require('firebase-admin/app');
  const firestore = require('firebase-admin/firestore');
  const keyPath = path.resolve(__dirname, process.env.SERVICE_ACCOUNT_PATH || './serviceAccountKey.json');
  initializeApp({ credential: cert(require(keyPath)) });
  db = firestore.getFirestore();
  admin = firestore;
  return db;
}

async function commitInChunks(writes) {
  const database = connect();
  for (let i = 0; i < writes.length; i += 450) {
    const batch = database.batch();
    for (const { ref, data, merge } of writes.slice(i, i + 450)) {
      if (merge) batch.set(ref(database), data, { merge: true });
      else batch.set(ref(database), data);
    }
    await batch.commit();
  }
}

/**
 * period: { id, season, week, startDate, endDate, lockTime }
 * rows:   [{ sport, externalApiId, fullName, realTeam, position, gameId, gameDate, stats, fantasyPoints }]
 */
async function writeWeek(period, rows) {
  connect();
  const { Timestamp, FieldValue } = admin;
  const writes = [];

  writes.push({
    ref: (d) => d.collection('scoringPeriods').doc(period.id),
    data: {
      season: String(period.season),
      week: period.week,
      startDate: Timestamp.fromDate(period.startDate),
      endDate: Timestamp.fromDate(period.endDate),
      lockTime: Timestamp.fromDate(period.lockTime),
    },
  });

  for (const r of rows) {
    const playerId = `${r.sport}_${r.externalApiId}`;
    const player = {
      sport: r.sport,
      externalApiId: r.externalApiId,
      fullName: r.fullName,
      realTeam: r.realTeam,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (r.position) player.position = r.position;
    // merge keeps fields other code may set later, such as injuryStatus
    writes.push({ ref: (d) => d.collection('players').doc(playerId), data: player, merge: true });

    writes.push({
      ref: (d) => d.collection('playerStats').doc(`${playerId}_${r.gameId}`),
      data: {
        playerId,
        sport: r.sport,
        scoringPeriodId: period.id,
        gameId: r.gameId,
        gameDate: Timestamp.fromDate(r.gameDate),
        rawStats: r.stats,
        fantasyPoints: r.fantasyPoints,
      },
    });
  }

  await commitInChunks(writes);
  return writes.length;
}

module.exports = { writeWeek };
