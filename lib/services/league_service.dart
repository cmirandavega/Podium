import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/league.dart';
import '../models/sport.dart';
import '../models/team.dart';

/// Use Case 2: creating leagues, choosing their sports, and joining them.
///
/// Creating or joining a league also creates the user's team in the same
/// batch, so a member always has a team (Use Case 3 builds the roster).
class LeagueService {
  LeagueService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _leagues => _db.collection('leagues');

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user;
  }

  /// Available sports. Falls back to the four Podium sports if the
  /// collection hasn't been seeded.
  Stream<List<Sport>> watchSports() {
    return _db.collection('sports').snapshots().map((query) {
      if (query.docs.isEmpty) return Sport.defaults;
      final sports = query.docs.map(Sport.fromFirestore).toList();
      const order = ['NFL', 'NBA', 'MLB', 'Soccer'];
      int rank(Sport s) {
        final i = order.indexOf(s.name);
        return i == -1 ? order.length : i;
      }

      sports.sort((a, b) => rank(a).compareTo(rank(b)));
      return sports;
    });
  }

  /// Leagues the user belongs to, newest first.
  Stream<List<League>> watchMyLeagues(String uid) {
    return _leagues.where('memberIds', arrayContains: uid).snapshots().map((query) {
      final leagues = query.docs.map(League.fromFirestore).toList();
      leagues.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return leagues;
    });
  }

  Stream<League?> watchLeague(String leagueId) {
    return _leagues.doc(leagueId).snapshots().map(
          (doc) => doc.exists ? League.fromFirestore(doc) : null,
        );
  }

  Stream<List<LeagueMember>> watchMembers(String leagueId) {
    return _leagues.doc(leagueId).collection('members').snapshots().map(
          (query) => query.docs.map(LeagueMember.fromFirestore).toList(),
        );
  }

  /// Validates a sport selection (Use Case 2 exception path). Returns an
  /// error message, or null when the selection is valid.
  static String? validateSports({
    required String format,
    required List<String> selected,
    required List<Sport> available,
  }) {
    if (selected.isEmpty) return 'Select at least one sport.';
    final active = {for (final s in available) if (s.isActive) s.name};
    final unavailable = selected.where((s) => !active.contains(s)).toList();
    if (unavailable.isNotEmpty) {
      return '${unavailable.join(', ')} is not available right now. Choose another sport.';
    }
    if (format == 'single-sport' && selected.length != 1) {
      return 'A single-sport league uses exactly one sport.';
    }
    if (format == 'multi-sport' && selected.length < 2) {
      return 'Pick two or more sports for a multi-sport league, or switch to single-sport.';
    }
    return null;
  }

  /// Six characters with no look-alikes (no 0/O or 1/I).
  static String generateInviteCode([Random? random]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = random ?? Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Creates the league, its leagueSports rows, the commissioner's
  /// membership, and the commissioner's team in one batch.
  Future<String> createLeague({
    required String name,
    required String teamName,
    required String username,
    required String format,
    required List<String> sports,
    required List<Sport> availableSports,
    required String season,
    required int maxTeams,
    required int rosterSize,
    required int starterCount,
    required int regularSeasonWeeks,
    required int playoffTeams,
    int tradeReviewHours = 0,
  }) async {
    final user = _user;
    if (name.trim().isEmpty) throw ArgumentError('Enter a league name.');
    if (teamName.trim().isEmpty) throw ArgumentError('Enter a team name.');
    final sportError = validateSports(
      format: format,
      selected: sports,
      available: availableSports,
    );
    if (sportError != null) throw ArgumentError(sportError);
    if (season.isEmpty) throw ArgumentError('Choose a season.');
    if (starterCount > rosterSize) {
      throw ArgumentError("Starters can't be more than the roster size.");
    }
    if (playoffTeams > maxTeams) {
      throw ArgumentError("Playoff teams can't be more than the number of teams.");
    }

    final leagueRef = _leagues.doc();
    final batch = _db.batch();

    batch.set(leagueRef, {
      'name': name.trim(),
      'commissionerId': user.uid,
      'format': format,
      'sports': sports,
      'season': season,
      'maxTeams': maxTeams,
      'rosterSize': rosterSize,
      'starterCount': starterCount,
      'tradeReviewHours': tradeReviewHours,
      'status': 'active',
      'inviteCode': generateInviteCode(),
      'memberIds': [user.uid],
      'currentWeek': 1,
      'regularSeasonWeeks': regularSeasonWeeks,
      'playoffTeams': playoffTeams,
      'lineupLocked': false,
      'phase': 'preseason',
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final sport in sports) {
      batch.set(_db.collection('leagueSports').doc('${leagueRef.id}_$sport'), {
        'leagueId': leagueRef.id,
        'sportName': sport,
      });
    }

    batch.set(leagueRef.collection('members').doc(user.uid), _memberData(user.uid, username));
    batch.set(
      _db.collection('teams').doc(Team.idFor(leagueRef.id, user.uid)),
      Team.newTeamData(leagueId: leagueRef.id, ownerId: user.uid, teamName: teamName),
    );

    await batch.commit();
    return leagueRef.id;
  }

  /// Joins a league with its invite code and creates the user's team.
  Future<String> joinLeague({
    required String inviteCode,
    required String teamName,
    required String username,
  }) async {
    final user = _user;
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) throw ArgumentError('Enter an invite code.');
    if (teamName.trim().isEmpty) throw ArgumentError('Enter a team name.');

    final match = await _leagues.where('inviteCode', isEqualTo: code).limit(1).get();
    if (match.docs.isEmpty) throw StateError('No league uses that invite code.');
    final leagueRef = match.docs.first.reference;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(leagueRef);
      final league = League.fromFirestore(snapshot);
      if (league.hasMember(user.uid)) throw StateError("You're already in this league.");
      if (league.status != 'active') throw StateError('This league has ended.');
      if (league.phase != 'preseason') {
        throw StateError('This league has already started its season.');
      }
      if (league.isFull) throw StateError('This league is full.');

      transaction.update(leagueRef, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
      });
      transaction.set(leagueRef.collection('members').doc(user.uid), _memberData(user.uid, username));
      transaction.set(
        _db.collection('teams').doc(Team.idFor(leagueRef.id, user.uid)),
        Team.newTeamData(leagueId: leagueRef.id, ownerId: user.uid, teamName: teamName),
      );
    });
    return leagueRef.id;
  }

  /// Commissioner edits the league's sports before the season starts
  /// (Use Case 2 "creating or editing a league").
  Future<void> updateSports({
    required League league,
    required String format,
    required List<String> sports,
    required List<Sport> availableSports,
  }) async {
    final user = _user;
    if (!league.isCommissioner(user.uid)) {
      throw StateError('Only the commissioner can change sports.');
    }
    if (league.phase != 'preseason') {
      throw StateError('Sports can only change before the season starts.');
    }
    final error = validateSports(format: format, selected: sports, available: availableSports);
    if (error != null) throw ArgumentError(error);

    final batch = _db.batch();
    batch.update(_leagues.doc(league.id), {'format': format, 'sports': sports});
    for (final old in league.sports.where((s) => !sports.contains(s))) {
      batch.delete(_db.collection('leagueSports').doc('${league.id}_$old'));
    }
    for (final sport in sports.where((s) => !league.sports.contains(s))) {
      batch.set(_db.collection('leagueSports').doc('${league.id}_$sport'), {
        'leagueId': league.id,
        'sportName': sport,
      });
    }
    await batch.commit();
  }

  Map<String, dynamic> _memberData(String uid, String username) => {
        'userId': uid,
        'username': username,
        'isMuted': false,
        'coins': LeagueMember.startingCoins,
        'joinedAt': FieldValue.serverTimestamp(),
      };
}
