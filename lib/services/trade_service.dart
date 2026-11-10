import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/league.dart';
import '../models/roster_slot.dart';
import '../models/team.dart';
import '../models/trade.dart';
import 'notification_service.dart';
import 'team_service.dart';

/// Use Case 8: propose, counter, accept, reject, and cancel trades.
///
/// Accepting runs in a transaction that re-reads every traded roster slot,
/// so a trade can't complete if a player was dropped or traded elsewhere in
/// the meantime, and both rosters change together or not at all.
class TradeService {
  TradeService({FirebaseFirestore? db, FirebaseAuth? auth, TeamService? teams})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _teams = teams ?? TeamService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final TeamService _teams;

  CollectionReference<Map<String, dynamic>> get _trades => _db.collection('trades');

  /// Kept small so the security rules can check every traded player within
  /// Firestore's limit on document reads per request.
  static const maxPerSide = 4;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  /// Checks a proposed trade against league rules. Returns an error, or null.
  static String? validate({
    required League league,
    required int proposerRosterSize,
    required int receiverRosterSize,
    required int offeredCount,
    required int requestedCount,
  }) {
    if (league.phase == 'complete') return 'The season is over.';
    if (offeredCount == 0 || requestedCount == 0) {
      return 'Pick at least one player on each side of the trade.';
    }
    if (offeredCount > maxPerSide || requestedCount > maxPerSide) {
      return 'Trades can include up to $maxPerSide players per side.';
    }
    if (proposerRosterSize - offeredCount + requestedCount > league.rosterSize) {
      return 'This trade would put you over the ${league.rosterSize}-player roster limit.';
    }
    if (receiverRosterSize - requestedCount + offeredCount > league.rosterSize) {
      return 'This trade would put the other team over the ${league.rosterSize}-player roster limit.';
    }
    return null;
  }

  Stream<List<Trade>> watchLeagueTrades(String leagueId) => _trades
      .where('leagueId', isEqualTo: leagueId)
      .snapshots()
      .asyncMap((q) async {
        final trades = <Trade>[];
        for (final doc in q.docs) {
          trades.add(await _withItems(Trade.fromFirestore(doc)));
        }
        trades.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return trades;
      });

  Future<Trade?> getTrade(String tradeId) async {
    final doc = await _trades.doc(tradeId).get();
    return doc.exists ? _withItems(Trade.fromFirestore(doc)) : null;
  }

  Future<Trade> _withItems(Trade trade) async {
    final items = await _trades.doc(trade.id).collection('items').get();
    return trade.withItems(items.docs.map(TradeItem.fromFirestore).toList());
  }

  /// Sends an offer from the user's team to [receiver].
  Future<String> propose({
    required League league,
    required Team receiver,
    required List<RosterSlot> offered,
    required List<RosterSlot> requested,
    String? parentTradeId,
  }) async {
    final uid = _uid;
    final proposerTeamId = Team.idFor(league.id, uid);
    if (receiver.id == proposerTeamId) throw StateError("You can't trade with yourself.");

    final proposerRoster = await _teams.getRoster(proposerTeamId);
    final receiverRoster = await _teams.getRoster(receiver.id);
    final error = validate(
      league: league,
      proposerRosterSize: proposerRoster.length,
      receiverRosterSize: receiverRoster.length,
      offeredCount: offered.length,
      requestedCount: requested.length,
    );
    if (error != null) throw StateError(error);
    final mine = {for (final s in proposerRoster) s.playerId};
    final theirs = {for (final s in receiverRoster) s.playerId};
    if (offered.any((s) => !mine.contains(s.playerId)) || requested.any((s) => !theirs.contains(s.playerId))) {
      throw StateError('Rosters changed. Refresh and pick the players again.');
    }

    final ref = _trades.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'leagueId': league.id,
      'proposerTeamId': proposerTeamId,
      'receiverTeamId': receiver.id,
      'proposerId': uid,
      'receiverId': receiver.ownerId,
      'parentTradeId': parentTradeId,
      // Lists of player IDs let the security rules check that accepting the
      // trade moves every player, not just some.
      'offeredIds': [for (final s in offered) s.playerId],
      'requestedIds': [for (final s in requested) s.playerId],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewEndsAt': null,
    });
    for (final s in [...offered, ...requested]) {
      batch.set(ref.collection('items').doc(s.playerId), {
        'playerId': s.playerId,
        'fromTeamId': s.teamId,
        'playerName': s.playerName,
      });
    }
    batch.set(
      _db.collection('notifications').doc(),
      NotificationService.newNotificationData(
        userId: receiver.ownerId,
        type: 'trade_offer',
        message: parentTradeId == null
            ? 'You received a trade offer in ${league.name}.'
            : 'Your trade offer in ${league.name} was countered.',
        relatedId: ref.id,
      ),
    );
    await batch.commit();
    return ref.id;
  }

  /// Receiver accepts: every traded player moves to the other team's bench.
  Future<void> accept({required League league, required Trade trade}) async {
    final uid = _uid;
    if (trade.receiverId != uid) throw StateError('Only the team receiving the offer can accept it.');
    if (league.lineupLocked) {
      throw StateError("Trades can't complete while lineups are locked. Try again after the week is scored.");
    }
    final proposerRoster = await _teams.getRoster(trade.proposerTeamId);
    final receiverRoster = await _teams.getRoster(trade.receiverTeamId);
    final error = validate(
      league: league,
      proposerRosterSize: proposerRoster.length,
      receiverRosterSize: receiverRoster.length,
      offeredCount: trade.offered.length,
      requestedCount: trade.requested.length,
    );
    if (error != null) throw StateError(error);

    final tradeRef = _trades.doc(trade.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(tradeRef);
      if (current.data()?['status'] != 'pending') throw StateError('This offer is no longer pending.');

      final slotRefs = [
        for (final item in trade.items) _db.collection('rosterSlots').doc(RosterSlot.idFor(league.id, item.playerId)),
      ];
      final slots = [for (final ref in slotRefs) await transaction.get(ref)];
      for (var i = 0; i < trade.items.length; i++) {
        final item = trade.items[i];
        if (!slots[i].exists || slots[i].data()?['teamId'] != item.fromTeamId) {
          throw StateError('${item.playerName} is no longer on the same roster, so this trade can\'t complete.');
        }
      }

      // Each team's roster count changes by the players it gains minus the
      // players it gives up.
      final proposerRef = _db.collection('teams').doc(trade.proposerTeamId);
      final receiverRef = _db.collection('teams').doc(trade.receiverTeamId);
      final proposerTeam = await transaction.get(proposerRef);
      final receiverTeam = await transaction.get(receiverRef);
      final delta = trade.requested.length - trade.offered.length;
      transaction.update(proposerRef, {
        'rosterCount': ((proposerTeam.data()?['rosterCount'] as num?)?.toInt() ?? 0) + delta,
        'lastTradeId': trade.id,
      });
      transaction.update(receiverRef, {
        'rosterCount': ((receiverTeam.data()?['rosterCount'] as num?)?.toInt() ?? 0) - delta,
        'lastTradeId': trade.id,
      });

      for (var i = 0; i < trade.items.length; i++) {
        transaction.update(slotRefs[i], {
          'teamId': trade.otherTeam(trade.items[i].fromTeamId),
          'isStarter': false,
          'lastTradeId': trade.id,
          'acquiredAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(tradeRef, {'status': 'completed'});
      transaction.set(
        _db.collection('notifications').doc(),
        NotificationService.newNotificationData(
          userId: trade.proposerId,
          type: 'trade_update',
          message: 'Your trade offer in ${league.name} was accepted. New players are on your bench.',
          relatedId: trade.id,
        ),
      );
    });
  }

  Future<void> reject({required League league, required Trade trade}) =>
      _close(league, trade, status: 'rejected', notify: trade.proposerId, message: 'was rejected');

  /// Proposer withdraws a pending offer.
  Future<void> cancel({required League league, required Trade trade}) =>
      _close(league, trade, status: 'cancelled', notify: trade.receiverId, message: 'was withdrawn');

  /// Receiver answers with a different offer. The original is marked
  /// countered and the new offer points back to it.
  Future<String> counter({
    required League league,
    required Trade original,
    required Team originalProposer,
    required List<RosterSlot> offered,
    required List<RosterSlot> requested,
  }) async {
    if (original.receiverId != _uid) throw StateError('Only the team receiving the offer can counter it.');
    if (!original.isPending) throw StateError('This offer is no longer pending.');
    final id = await propose(
      league: league,
      receiver: originalProposer,
      offered: offered,
      requested: requested,
      parentTradeId: original.id,
    );
    await _trades.doc(original.id).update({'status': 'countered'});
    return id;
  }

  Future<void> _close(
    League league,
    Trade trade, {
    required String status,
    required String notify,
    required String message,
  }) async {
    final uid = _uid;
    final allowed = status == 'cancelled' ? trade.proposerId == uid : trade.receiverId == uid;
    if (!allowed) throw StateError("You can't change this trade.");
    final batch = _db.batch();
    batch.update(_trades.doc(trade.id), {'status': status});
    batch.set(
      _db.collection('notifications').doc(),
      NotificationService.newNotificationData(
        userId: notify,
        type: 'trade_update',
        message: 'A trade offer in ${league.name} $message.',
        relatedId: trade.id,
      ),
    );
    await batch.commit();
  }
}
