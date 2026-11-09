import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/league.dart';
import '../models/matchup.dart';
import '../models/wager.dart';

/// Use Case 13: prediction wagers with Podium currency.
///
/// Stakes leave the member's balance when a wager is created or accepted,
/// so they're held until the matchup is final. Settlement runs inside the
/// same batch that scores the week (see [settleInBatch]), so payouts and
/// results can't disagree.
class WagerService {
  WagerService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _wagers => _db.collection('wagers');

  DocumentReference<Map<String, dynamic>> _member(String leagueId, String uid) =>
      _db.collection('leagues').doc(leagueId).collection('members').doc(uid);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  /// Returns an error, or null when the wager can be placed or accepted.
  static String? validate({
    required League league,
    required Matchup matchup,
    required int amount,
    required int balance,
  }) {
    if (league.phase != 'regular' && league.phase != 'playoffs') {
      return 'Wagers open once the season starts.';
    }
    if (matchup.week != league.currentWeek || matchup.isFinal) {
      return 'You can only wager on this week\'s games.';
    }
    if (league.lineupLocked) return 'Wagers close when lineups lock.';
    if (matchup.isBye) return "Bye weeks can't be wagered on.";
    if (amount < Wager.minAmount) return 'The minimum wager is ${Wager.minAmount} coins.';
    if (amount > balance) return 'You only have $balance coins.';
    return null;
  }

  /// What a wager pays once its matchup is final. The winner of a matched
  /// wager gets both stakes; a tie returns each stake; an unmatched offer is
  /// refunded.
  static WagerOutcome outcome(Wager w, Matchup finalGame) {
    if (w.isOpen) {
      return (status: 'void', winnerId: null, payouts: {w.creatorId: w.amount});
    }
    final opponent = w.opponentId!;
    final winningTeam = finalGame.winnerTeamId;
    if (winningTeam == null) {
      return (status: 'push', winnerId: null, payouts: {w.creatorId: w.amount, opponent: w.amount});
    }
    final winner = winningTeam == w.pickTeamId ? w.creatorId : opponent;
    return (status: 'won', winnerId: winner, payouts: {winner: w.amount * 2});
  }

  Stream<List<Wager>> watchLeagueWagers(String leagueId) => _wagers
      .where('leagueId', isEqualTo: leagueId)
      .snapshots()
      .map((q) {
        final list = q.docs.map(Wager.fromFirestore).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// Creates an open offer and takes the stake from the creator's balance.
  Future<void> create({
    required League league,
    required LeagueMember me,
    required Matchup matchup,
    required String pickTeamId,
    required int amount,
  }) async {
    final uid = _uid;
    final error = validate(league: league, matchup: matchup, amount: amount, balance: me.coins);
    if (error != null) throw StateError(error);
    if (!matchup.involves(pickTeamId)) throw StateError('Pick one of the two teams in this game.');

    final ref = _wagers.doc();
    await _db.runTransaction((transaction) async {
      final member = await transaction.get(_member(league.id, uid));
      final coins = (member.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < amount) throw StateError('You only have $coins coins.');
      transaction.set(ref, {
        'leagueId': league.id,
        'matchupId': matchup.id,
        'week': matchup.week,
        'creatorId': uid,
        'creatorName': me.username,
        'pickTeamId': pickTeamId,
        'amount': amount,
        'status': 'open',
        'opponentId': null,
        'opponentName': null,
        'winnerId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_member(league.id, uid), {'coins': coins - amount, 'lastWagerId': ref.id});
    });
  }

  /// Takes the other side of an open offer for the same amount.
  Future<void> accept({
    required League league,
    required LeagueMember me,
    required Wager wager,
    required Matchup matchup,
  }) async {
    final uid = _uid;
    if (wager.creatorId == uid) throw StateError("You can't take your own wager.");
    final error = validate(league: league, matchup: matchup, amount: wager.amount, balance: me.coins);
    if (error != null) throw StateError(error);

    final ref = _wagers.doc(wager.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(ref);
      if (current.data()?['status'] != 'open') throw StateError('Someone already took this wager.');
      final member = await transaction.get(_member(league.id, uid));
      final coins = (member.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < wager.amount) throw StateError('You only have $coins coins.');
      transaction.update(ref, {'status': 'matched', 'opponentId': uid, 'opponentName': me.username});
      transaction.update(_member(league.id, uid), {'coins': coins - wager.amount, 'lastWagerId': wager.id});
    });
  }

  /// Creator withdraws an open offer and gets the stake back.
  Future<void> cancel({required League league, required Wager wager}) async {
    final uid = _uid;
    if (wager.creatorId != uid) throw StateError('Only the creator can cancel this wager.');
    final ref = _wagers.doc(wager.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(ref);
      if (current.data()?['status'] != 'open') throw StateError('This wager is no longer open.');
      final member = await transaction.get(_member(league.id, uid));
      final coins = (member.data()?['coins'] as num?)?.toInt() ?? 0;
      transaction.update(ref, {'status': 'cancelled'});
      transaction.update(_member(league.id, uid), {'coins': coins + wager.amount, 'lastWagerId': wager.id});
    });
  }

  /// Settles every open or matched wager on [finished] games, inside the
  /// batch that scores the week. Pass this to MatchupService.onWeekScored.
  Future<void> settleInBatch(WriteBatch batch, League league, List<Matchup> finished) async {
    final games = {for (final m in finished) m.id: m};
    final query = await _wagers
        .where('leagueId', isEqualTo: league.id)
        .where('week', isEqualTo: league.currentWeek)
        .get();
    final totals = <String, int>{};
    for (final doc in query.docs) {
      final w = Wager.fromFirestore(doc);
      final game = games[w.matchupId];
      if (game == null || !(w.isOpen || w.isMatched)) continue;
      final result = outcome(w, game);
      batch.update(doc.reference, {
        'status': result.status,
        'winnerId': result.winnerId,
        'settledAt': FieldValue.serverTimestamp(),
      });
      result.payouts.forEach((uid, coins) => totals[uid] = (totals[uid] ?? 0) + coins);
    }
    totals.forEach((uid, coins) {
      batch.update(_member(league.id, uid), {'coins': FieldValue.increment(coins)});
    });
  }
}
