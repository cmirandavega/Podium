import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/draft.dart';
import '../models/league.dart';
import '../models/player_stat.dart';
import '../models/roster_slot.dart';
import '../models/team.dart';
import 'team_service.dart';

/// Use Case 3: the live snake draft that builds every roster.
///
/// Each pick runs in one transaction that checks the team is on the clock
/// and the player is still available, then adds the player to the roster,
/// records the pick, and moves the clock to the next team. Two people can't
/// draft the same player or pick out of turn.
class DraftService {
  DraftService({FirebaseFirestore? db, FirebaseAuth? auth, TeamService? teams})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _teams = teams ?? TeamService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final TeamService _teams;

  DocumentReference<Map<String, dynamic>> _draft(String leagueId) =>
      _db.collection('drafts').doc(leagueId);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  Stream<Draft?> watchDraft(String leagueId) => _draft(leagueId).snapshots().map(
        (doc) => doc.exists ? Draft.fromFirestore(doc) : null,
      );

  Stream<List<DraftPick>> watchPicks(String leagueId) =>
      _draft(leagueId).collection('picks').snapshots().map((q) {
        final picks = q.docs.map(DraftPick.fromFirestore).toList();
        picks.sort((a, b) => b.pickNumber.compareTo(a.pickNumber));
        return picks;
      });

  /// Commissioner starts the draft: random order, rounds equal to the roster
  /// size. Every roster must be empty.
  Future<void> startDraft(League league) async {
    if (!league.isCommissioner(_uid)) throw StateError('Only the commissioner can start the draft.');
    if (league.draftStatus != 'not_started') throw StateError('The draft has already started.');
    final teams = await _teams.getTeamsInLeague(league.id);
    if (teams.length < 2) throw StateError('The league needs at least two teams to draft.');
    if (teams.length != league.memberIds.length) {
      throw StateError('Some members are missing a team. Try again in a moment.');
    }
    if (teams.any((t) => t.rosterCount > 0)) {
      throw StateError('Rosters must be empty before the draft starts.');
    }

    final order = [for (final t in teams) t.id]..shuffle();
    final batch = _db.batch();
    batch.set(_draft(league.id), {
      'leagueId': league.id,
      'status': 'live',
      'order': order,
      'rounds': league.rosterSize,
      'pickNumber': 0,
      'currentTeamId': order.first,
      'startedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('leagues').doc(league.id), {'draftStatus': 'live'});
    await batch.commit();
  }

  /// Drafts [player] for the team on the clock. Members pick for their own
  /// team; the commissioner can pick for whoever is on the clock ([auto]).
  Future<void> makePick({
    required League league,
    required PlayerWeek player,
    bool auto = false,
  }) async {
    final uid = _uid;
    if (!league.sports.contains(player.sport)) {
      throw StateError('${player.sport} players aren\'t eligible in this league.');
    }
    final draftRef = _draft(league.id);
    final slotRef = _db.collection('rosterSlots').doc(RosterSlot.idFor(league.id, player.playerId));

    await _db.runTransaction((transaction) async {
      final draftDoc = await transaction.get(draftRef);
      if (!draftDoc.exists) throw StateError('The draft hasn\'t started.');
      final draft = Draft.fromFirestore(draftDoc);
      if (!draft.isLive || draft.currentTeamId == null) throw StateError('The draft is over.');

      final teamId = draft.currentTeamId!;
      final mine = teamId == Team.idFor(league.id, uid);
      if (!mine && !(auto && league.isCommissioner(uid))) {
        throw StateError("It's not your turn yet.");
      }

      final slot = await transaction.get(slotRef);
      if (slot.exists) throw StateError('${player.fullName} was just drafted. Pick someone else.');
      final teamRef = _db.collection('teams').doc(teamId);
      final team = await transaction.get(teamRef);
      final count = (team.data()?['rosterCount'] as num?)?.toInt() ?? 0;

      transaction.update(teamRef, {'rosterCount': count + 1, 'lastSlotId': slotRef.id});
      transaction.set(slotRef, {
        'leagueId': league.id,
        'playerId': player.playerId,
        'teamId': teamId,
        'slotPosition': player.position ?? '',
        // The first picks fill the starting lineup; the rest go to the bench.
        'isStarter': count < league.starterCount,
        'playerName': player.fullName,
        'sport': player.sport,
        'realTeam': player.realTeam,
        'acquiredAt': FieldValue.serverTimestamp(),
      });
      transaction.set(draftRef.collection('picks').doc('${draft.pickNumber}'), {
        'pickNumber': draft.pickNumber,
        'round': draft.round,
        'teamId': teamId,
        'playerId': player.playerId,
        'playerName': player.fullName,
        'position': player.position ?? '',
        'sport': player.sport,
        'realTeam': player.realTeam,
        'auto': !mine,
        'pickedAt': FieldValue.serverTimestamp(),
      });

      final next = draft.pickNumber + 1;
      if (next >= draft.totalPicks) {
        transaction.update(draftRef, {'pickNumber': next, 'currentTeamId': null, 'status': 'complete'});
        transaction.update(_db.collection('leagues').doc(league.id), {'draftStatus': 'complete'});
      } else {
        transaction.update(draftRef, {
          'pickNumber': next,
          'currentTeamId': Draft.teamForPick(draft.order, next),
        });
      }
    });
  }
}
