import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/league.dart';
import '../models/player_stat.dart';
import '../models/roster_slot.dart';
import '../models/team.dart';

/// Use Case 3: building and managing a fantasy roster.
///
/// Other features (matchups, trades, weekly analysis, both AI tools) read
/// rosters only through this service: [getTeamsInLeague], [getRoster], and
/// [getStarters]. Swapping in a different Team Builder means keeping these
/// method signatures.
class TeamService {
  TeamService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _teams => _db.collection('teams');
  CollectionReference<Map<String, dynamic>> get _slots => _db.collection('rosterSlots');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  // Reads used across features.

  Future<List<Team>> getTeamsInLeague(String leagueId) async {
    final query = await _teams.where('leagueId', isEqualTo: leagueId).get();
    return query.docs.map(Team.fromFirestore).toList();
  }

  Future<List<RosterSlot>> getRoster(String teamId) async {
    final query = await _slots.where('teamId', isEqualTo: teamId).get();
    return sortRoster(query.docs.map(RosterSlot.fromFirestore).toList());
  }

  /// The players who score for [teamId] this week.
  Future<List<RosterSlot>> getStarters(String teamId) async {
    final roster = await getRoster(teamId);
    return roster.where((s) => s.isStarter).toList();
  }

  Future<Team?> getTeam(String teamId) async {
    final doc = await _teams.doc(teamId).get();
    return doc.exists ? Team.fromFirestore(doc) : null;
  }

  // Live streams for screens.

  Stream<Team?> watchTeam(String teamId) => _teams.doc(teamId).snapshots().map(
        (doc) => doc.exists ? Team.fromFirestore(doc) : null,
      );

  Stream<List<Team>> watchTeamsInLeague(String leagueId) => _teams
      .where('leagueId', isEqualTo: leagueId)
      .snapshots()
      .map((q) => q.docs.map(Team.fromFirestore).toList());

  Stream<List<RosterSlot>> watchRoster(String teamId) => _slots
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((q) => sortRoster(q.docs.map(RosterSlot.fromFirestore).toList()));

  /// Every rostered player in the league, used to hide taken players.
  Stream<Set<String>> watchTakenPlayerIds(String leagueId) => _slots
      .where('leagueId', isEqualTo: leagueId)
      .snapshots()
      .map((q) => {for (final d in q.docs) d.data()['playerId'] as String? ?? ''});

  /// Starters first, then by sport and position.
  static List<RosterSlot> sortRoster(List<RosterSlot> slots) {
    slots.sort((a, b) {
      if (a.isStarter != b.isStarter) return a.isStarter ? -1 : 1;
      final bySport = a.sport.compareTo(b.sport);
      if (bySport != 0) return bySport;
      final byPos = a.slotPosition.compareTo(b.slotPosition);
      return byPos != 0 ? byPos : a.playerName.compareTo(b.playerName);
    });
    return slots;
  }

  /// Checks the Use Case 3 exception paths. Returns an error, or null.
  static String? validateAdd({
    required League league,
    required String playerSport,
    required int rosterCount,
  }) {
    if (league.lineupLocked) return 'Lineups are locked while this week is being scored.';
    if (league.phase == 'complete') return 'This season is over.';
    if (!league.draftComplete) return 'Rosters are built in the draft. Adds open once it\'s over.';
    if (!league.sports.contains(playerSport)) {
      return '$playerSport players aren\'t eligible in this league.';
    }
    if (rosterCount >= league.rosterSize) {
      return 'Your roster is full (${league.rosterSize} players). Drop someone first.';
    }
    return null;
  }

  static String? validateStarterChange({
    required League league,
    required bool makeStarter,
    required int starterCount,
  }) {
    if (league.lineupLocked) return 'Lineups are locked while this week is being scored.';
    if (makeStarter && starterCount >= league.starterCount) {
      return 'You already have ${league.starterCount} starters. Bench someone first.';
    }
    return null;
  }

  // Changes the owner makes.

  /// Adds a player to the user's own team. New players start if there's an
  /// open starter spot, otherwise they go to the bench.
  Future<void> addPlayer({required League league, required PlayerWeek player}) async {
    final uid = _uid;
    final teamId = Team.idFor(league.id, uid);
    final roster = await getRoster(teamId);
    final error = validateAdd(
      league: league,
      playerSport: player.sport,
      rosterCount: roster.length,
    );
    if (error != null) throw StateError(error);

    final starters = roster.where((s) => s.isStarter).length;
    final ref = _slots.doc(RosterSlot.idFor(league.id, player.playerId));
    final teamRef = _teams.doc(teamId);

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) throw StateError('${player.fullName} is already on a roster.');
      final team = await transaction.get(teamRef);
      final count = (team.data()?['rosterCount'] as num?)?.toInt() ?? 0;
      if (count >= league.rosterSize) {
        throw StateError('Your roster is full (${league.rosterSize} players). Drop someone first.');
      }
      // Security rules check that rosterCount and the new slot change together.
      transaction.update(teamRef, {'rosterCount': count + 1, 'lastSlotId': ref.id});
      transaction.set(ref, {
        'leagueId': league.id,
        'playerId': player.playerId,
        'teamId': teamId,
        'slotPosition': player.position ?? '',
        'isStarter': starters < league.starterCount,
        'playerName': player.fullName,
        'sport': player.sport,
        'realTeam': player.realTeam,
        'acquiredAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> dropPlayer({required League league, required RosterSlot slot}) async {
    if (league.lineupLocked) {
      throw StateError('Lineups are locked while this week is being scored.');
    }
    if (slot.teamId != Team.idFor(league.id, _uid)) {
      throw StateError('You can only change your own roster.');
    }
    final teamRef = _teams.doc(slot.teamId);
    await _db.runTransaction((transaction) async {
      final team = await transaction.get(teamRef);
      final count = (team.data()?['rosterCount'] as num?)?.toInt() ?? 0;
      transaction.update(teamRef, {'rosterCount': count > 0 ? count - 1 : 0, 'lastSlotId': slot.id});
      transaction.delete(_slots.doc(slot.id));
    });
  }

  Future<void> setStarter({
    required League league,
    required RosterSlot slot,
    required bool isStarter,
  }) async {
    final roster = await getRoster(slot.teamId);
    final error = validateStarterChange(
      league: league,
      makeStarter: isStarter,
      starterCount: roster.where((s) => s.isStarter).length,
    );
    if (error != null) throw StateError(error);
    await _slots.doc(slot.id).update({'isStarter': isStarter});
  }

  /// Benches one starter and starts one bench player in a single write.
  /// Used by the lineup screen and the AI Coach's "Apply" button (Use Case 12).
  Future<void> swapStarter({
    required League league,
    required String startPlayerId,
    required String benchPlayerId,
  }) async {
    if (league.lineupLocked) {
      throw StateError('Lineups are locked while this week is being scored.');
    }
    final teamId = Team.idFor(league.id, _uid);
    final roster = await getRoster(teamId);
    RosterSlot? find(String playerId) {
      for (final s in roster) {
        if (s.playerId == playerId) return s;
      }
      return null;
    }

    final toStart = find(startPlayerId);
    final toBench = find(benchPlayerId);
    if (toStart == null || toBench == null) {
      throw StateError('Both players must be on your roster.');
    }
    if (toStart.isStarter) throw StateError('${toStart.playerName} is already starting.');
    if (!toBench.isStarter) throw StateError('${toBench.playerName} is already on the bench.');

    final batch = _db.batch();
    batch.update(_slots.doc(toStart.id), {'isStarter': true});
    batch.update(_slots.doc(toBench.id), {'isStarter': false});
    await batch.commit();
  }

  Future<void> renameTeam(String teamId, String name) {
    if (name.trim().isEmpty) throw ArgumentError('Enter a team name.');
    return _teams.doc(teamId).update({'teamName': name.trim()});
  }
}
