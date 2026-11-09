// Fills a league with demo opponents for presentations and testing.
//
// Creates bot accounts, adds them to the league, and drafts full rosters for
// every team (bots and any real member whose roster isn't full) from the
// league's season, best players first, snake order. Uses the Admin SDK, so it
// bypasses security rules: run it only against your own project.
//
// Usage (from scripts/firestore-seed, with serviceAccountKey.json in place):
//   node demo-league.js <INVITE_CODE> [botCount]
// Example:
//   node demo-league.js K7QX2M 3

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const BOT_NAMES = ['Gridiron Ghosts', 'Blitz Brigade', 'Red Zone Rebels', 'Fourth & Long', 'Hail Mary Club', 'Pick Six Posse', 'Two Minute Drill', 'End Zone Elite', 'Audible Kings', 'Sideline Sharks', 'Pocket Passers'];

async function main() {
  const [code, countArg] = process.argv.slice(2);
  if (!code) throw new Error('Usage: node demo-league.js <INVITE_CODE> [botCount]');

  const match = await db.collection('leagues').where('inviteCode', '==', code.toUpperCase()).limit(1).get();
  if (match.empty) throw new Error(`No league uses invite code ${code}.`);
  const leagueRef = match.docs[0].ref;
  const league = match.docs[0].data();
  const leagueId = leagueRef.id;

  const openSpots = league.maxTeams - league.memberIds.length;
  const botCount = Math.min(Number(countArg ?? openSpots), openSpots);
  console.log(`${league.name}: ${league.memberIds.length}/${league.maxTeams} teams, adding ${botCount} bots.`);

  // 1. Bot accounts, memberships, and teams.
  const batch = db.batch();
  const botIds = [];
  for (let i = 0; i < botCount; i++) {
    const uid = `bot_${leagueId}_${i + 1}`;
    const username = `bot_${(i + 1).toString().padStart(2, '0')}_${leagueId.slice(0, 4).toLowerCase()}`;
    botIds.push(uid);
    batch.set(db.doc(`users/${uid}`), {
      username, email: `${username}@bots.podium.app`, displayName: BOT_NAMES[i % BOT_NAMES.length],
      role: 'user', status: 'active', createdAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.doc(`usernames/${username}`), { uid });
    batch.set(leagueRef.collection('members').doc(uid), {
      userId: uid, username, isMuted: false, coins: 1000, joinedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.doc(`teams/${leagueId}_${uid}`), {
      leagueId, ownerId: uid, teamName: BOT_NAMES[i % BOT_NAMES.length],
      wins: 0, losses: 0, ties: 0, pointsFor: 0, createdAt: FieldValue.serverTimestamp(),
    });
  }
  if (botIds.length) batch.update(leagueRef, { memberIds: FieldValue.arrayUnion(...botIds) });
  await batch.commit();

  // 2. Player pool: total points across the season's loaded weeks.
  const stats = await db.collection('playerStats').get();
  const pool = new Map();
  for (const doc of stats.docs) {
    const s = doc.data();
    if (!String(s.scoringPeriodId).startsWith(`period_${league.season}_`)) continue;
    if (!league.sports.includes(s.sport)) continue;
    const p = pool.get(s.playerId) ?? { ...s, total: 0 };
    p.total += s.fantasyPoints ?? 0;
    pool.set(s.playerId, p);
  }
  const taken = new Set((await db.collection('rosterSlots').where('leagueId', '==', leagueId).get()).docs.map((d) => d.data().playerId));
  const available = [...pool.values()].filter((p) => !taken.has(p.playerId)).sort((a, b) => b.total - a.total);

  // 3. Snake draft until every roster is full.
  const teams = (await db.collection('teams').where('leagueId', '==', leagueId).get()).docs.map((d) => d.id);
  const counts = {};
  const starters = {};
  for (const teamId of teams) {
    const slots = await db.collection('rosterSlots').where('teamId', '==', teamId).get();
    counts[teamId] = slots.size;
    starters[teamId] = slots.docs.filter((d) => d.data().isStarter).length;
  }

  const writes = [];
  let round = 0;
  while (available.length && teams.some((t) => counts[t] < league.rosterSize)) {
    const order = round % 2 === 0 ? teams : [...teams].reverse();
    for (const teamId of order) {
      if (counts[teamId] >= league.rosterSize || !available.length) continue;
      const p = available.shift();
      const isStarter = starters[teamId] < league.starterCount;
      writes.push({ ref: db.doc(`rosterSlots/${leagueId}_${p.playerId}`), data: {
        leagueId, playerId: p.playerId, teamId, slotPosition: p.position ?? '', isStarter,
        playerName: p.fullName, sport: p.sport, realTeam: p.realTeam ?? '', acquiredAt: FieldValue.serverTimestamp(),
      } });
      counts[teamId] += 1;
      if (isStarter) starters[teamId] += 1;
    }
    round += 1;
  }
  for (let i = 0; i < writes.length; i += 400) {
    const chunk = db.batch();
    for (const w of writes.slice(i, i + 400)) chunk.set(w.ref, w.data);
    await chunk.commit();
  }
  console.log(`Drafted ${writes.length} players across ${teams.length} teams.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
