const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
const now = FieldValue.serverTimestamp();
const ts = (d) => Timestamp.fromDate(new Date(d));
async function seed() {
  const batch = db.batch();

  // Sample IDs used across collections
  const uid = 'demo_user_001';
  const uid2 = 'demo_user_002';
  const leagueId = 'demo_league_001';
  const teamId = `${leagueId}_${uid}`;
  const teamId2 = `${leagueId}_${uid2}`;
  const periodId = 'period_2026_w06';
  const qb = 'NFL_1001';
  const guard = 'NBA_2001';
  const tradeId = 'demo_trade_001';
  const convoId = 'demo_convo_001';

  // 1. users
  for (const [id, name] of [[uid, 'demo_user'], [uid2, 'demo_rival']]) {
    batch.set(db.doc(`users/${id}`), {
      username: name,
      email: `${name}@podium.app`,
      displayName: name.replace('_', ' '),
      role: 'user',
      status: 'active',
      createdAt: now,
    });
    // 2. usernames
    batch.set(db.doc(`usernames/${name}`), { uid: id });
  }

  // 3. sports
  const sports = { NFL: 'american-football', NBA: 'basketball', MLB: 'baseball', Soccer: 'football' };
  for (const [name, apiCode] of Object.entries(sports)) {
    batch.set(db.doc(`sports/${name}`), { name, apiCode, isActive: true });
  }

  // 4. leagues
  batch.set(db.doc(`leagues/${leagueId}`), {
    name: 'Demo League',
    commissionerId: uid,
    format: 'multi-sport',
    sports: ['NFL', 'NBA'],
    season: '2026',
    maxTeams: 10,
    rosterSize: 12,
    tradeReviewHours: 24,
    status: 'active',
    createdAt: now,
  });

  // 5. leagueSports
  for (const s of ['NFL', 'NBA']) {
    batch.set(db.doc(`leagueSports/${leagueId}_${s}`), { leagueId, sportName: s });
  }

  // 6. leagues/{leagueId}/members
  for (const id of [uid, uid2]) {
    batch.set(db.doc(`leagues/${leagueId}/members/${id}`), {
      userId: id, isMuted: false, joinedAt: now,
    });
  }

  // 7. players
  batch.set(db.doc(`players/${qb}`), {
    sport: 'NFL', externalApiId: '1001', fullName: 'Sample Quarterback',
    position: 'QB', realTeam: 'Sample City', injuryStatus: 'healthy', updatedAt: now,
  });
  batch.set(db.doc(`players/${guard}`), {
    sport: 'NBA', externalApiId: '2001', fullName: 'Sample Guard',
    position: 'PG', realTeam: 'Sample Town', injuryStatus: 'healthy', updatedAt: now,
  });

  // 8. scoringPeriods
  batch.set(db.doc(`scoringPeriods/${periodId}`), {
    startDate: ts('2026-10-05T00:00:00Z'),
    endDate: ts('2026-10-11T23:59:59Z'),
    lockTime: ts('2026-10-05T17:00:00Z'),
  });

  // 9. playerStats
  batch.set(db.doc('playerStats/demo_stat_001'), {
    playerId: qb, scoringPeriodId: periodId, gameDate: ts('2026-10-05T17:00:00Z'),
    rawStats: { passingYards: 285, passingTDs: 2, interceptions: 1 },
    fantasyPoints: 21.4,
  });

  // 10. teams
  batch.set(db.doc(`teams/${teamId}`), { leagueId, ownerId: uid, teamName: 'Demo Squad', createdAt: now });
  batch.set(db.doc(`teams/${teamId2}`), { leagueId, ownerId: uid2, teamName: 'Rival Squad', createdAt: now });

  // 11. rosterSlots
  batch.set(db.doc(`rosterSlots/${leagueId}_${qb}`), {
    leagueId, playerId: qb, teamId, slotPosition: 'QB', isStarter: true, acquiredAt: now,
  });
  batch.set(db.doc(`rosterSlots/${leagueId}_${guard}`), {
    leagueId, playerId: guard, teamId: teamId2, slotPosition: 'PG', isStarter: true, acquiredAt: now,
  });

  // 12. trades
  batch.set(db.doc(`trades/${tradeId}`), {
    leagueId, proposerTeamId: teamId, receiverTeamId: teamId2,
    parentTradeId: null, status: 'pending', createdAt: now, reviewEndsAt: null,
  });

  // 13. trades/{tradeId}/items
  batch.set(db.doc(`trades/${tradeId}/items/${qb}`), { playerId: qb, fromTeamId: teamId });
  batch.set(db.doc(`trades/${tradeId}/items/${guard}`), { playerId: guard, fromTeamId: teamId2 });

  // 14. leagues/{leagueId}/messages
  batch.set(db.doc(`leagues/${leagueId}/messages/demo_msg_001`), {
    senderId: uid, body: 'Welcome to the league!', isDeleted: false, createdAt: now,
  });

  // 15. notifications
  batch.set(db.doc('notifications/demo_notif_001'), {
    userId: uid2, type: 'trade_offer', message: 'You received a trade offer from Demo Squad.',
    relatedId: tradeId, isRead: false, createdAt: now,
  });

  // 16. weeklyReports
  batch.set(db.doc(`weeklyReports/${teamId}_${periodId}`), {
    teamId, scoringPeriodId: periodId, pointsEarned: 21.4,
    rosterEfficiency: 0.92, rankChange: 1, createdAt: now,
  });

  // 17. tradeAnalyses
  batch.set(db.doc('tradeAnalyses/demo_analysis_001'), {
    userId: uid2, tradeId, analysisType: 'trade', fairnessRating: 7,
    projectedDeltaProposer: -2.5, projectedDeltaReceiver: 3.1,
    explanation: 'Sample analysis explanation.', dataAsOf: now, createdAt: now,
  });

  // 18. coachConversations
  batch.set(db.doc(`coachConversations/${convoId}`), { userId: uid, teamId, createdAt: now });

  // 19. coachConversations/{convoId}/messages
  batch.set(db.doc(`coachConversations/${convoId}/messages/demo_cmsg_001`), {
    role: 'user', content: 'Who should I start at QB this week?', createdAt: now,
  });
  batch.set(db.doc(`coachConversations/${convoId}/messages/demo_cmsg_002`), {
    role: 'assistant', content: 'Sample Quarterback is your best option this week.', createdAt: now,
  });

  // 20. aiUsage
  batch.set(db.doc(`aiUsage/${uid}_2026-10-05_assistant_coach`), {
    userId: uid, usageDate: '2026-10-05', feature: 'assistant_coach', requestCount: 1,
  });

  await batch.commit();
  console.log('Seed complete: all 20 collections created.');
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});