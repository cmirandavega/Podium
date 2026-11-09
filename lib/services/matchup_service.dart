import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/league.dart';
import '../models/matchup.dart';
import '../models/roster_slot.dart';
import '../models/team.dart';
import '../models/weekly_report.dart';
import 'player_history_service.dart';
import 'season_engine.dart';
import 'team_service.dart';

/// Extra work to do in the same batch when a week is scored, such as
/// settling wagers (Use Case 13). Receives the finished matchups.
typedef WeekScoredHook = Future<void> Function(
  WriteBatch batch,
  League league,
  List<Matchup> finished,
);

/// Use Case 15: weekly head-to-head matchups and playoffs, run by the
/// commissioner. Scoring a week also updates standings (Use Case 11) and
/// writes each team's weekly report (Use Case 5).
///
/// Podium replays a past season, so the commissioner advances the league one
/// week at a time: lock lineups, then score the week from the stats the
/// ingestion script loaded.
class MatchupService {
  MatchupService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    TeamService? teams,
    PlayerHistoryService? history,
    this.onWeekScored,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _teams = teams ?? TeamService(),
        _history = history ?? PlayerHistoryService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final TeamService _teams;
  final PlayerHistoryService _history;
  final WeekScoredHook? onWeekScored;

  CollectionReference<Map<String, dynamic>> get _matchups => _db.collection('matchups');

  void _requireCommissioner(League league) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !league.isCommissioner(uid)) {
      throw StateError('Only the commissioner can run the schedule.');
    }
  }

  Stream<List<Matchup>> watchMatchups(String leagueId) => _matchups
      .where('leagueId', isEqualTo: leagueId)
      .snapshots()
      .map((q) {
        final list = q.docs.map(Matchup.fromFirestore).toList();
        list.sort((a, b) => a.week != b.week ? a.week.compareTo(b.week) : a.id.compareTo(b.id));
        return list;
      });

  Stream<List<WeeklyReport>> watchReports(String teamId) => _db
      .collection('weeklyReports')
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((q) {
        final list = q.docs.map(WeeklyReport.fromFirestore).toList();
        list.sort((a, b) => b.week.compareTo(a.week));
        return list;
      });

  /// Builds the regular-season schedule and starts week 1.
  Future<void> startSeason(League league) async {
    _requireCommissioner(league);
    if (league.phase != 'preseason') throw StateError('The season has already started.');
    final teams = await _teams.getTeamsInLeague(league.id);
    if (teams.length < 2) throw StateError('A league needs at least two teams to start.');

    final periodsLoaded = await _periodExists(league.periodIdForWeek(1));
    if (!periodsLoaded) {
      throw StateError('No stats are loaded for ${league.season} week 1. Run the ingestion script first.');
    }

    final ids = [for (final t in teams) t.id]..shuffle();
    final schedule = SeasonEngine.roundRobin(ids, league.regularSeasonWeeks);
    final batch = _db.batch();
    for (var w = 0; w < schedule.length; w++) {
      for (var i = 0; i < schedule[w].length; i++) {
        _writeMatchup(batch, league, week: w + 1, index: i, pairing: schedule[w][i]);
      }
    }
    batch.update(_db.collection('leagues').doc(league.id), {
      'phase': 'regular',
      'currentWeek': 1,
      'lineupLocked': false,
    });
    await batch.commit();
  }

  /// Locks every lineup for the current week, like kickoff in a live season.
  Future<void> setLineupsLocked(League league, bool locked) async {
    _requireCommissioner(league);
    await _db.collection('leagues').doc(league.id).update({'lineupLocked': locked});
  }

  /// Scores the current week: matchup results, team records, standings, and
  /// weekly reports, all in one batch. Then moves to the next week, seeds
  /// the playoffs, or ends the season.
  Future<void> scoreCurrentWeek(League league) async {
    _requireCommissioner(league);
    if (league.phase != 'regular' && league.phase != 'playoffs') {
      throw StateError('There is no week to score right now.');
    }
    if (!league.lineupLocked) throw StateError('Lock lineups before scoring the week.');

    final week = league.currentWeek;
    final periodId = league.currentPeriodId;
    if (!await _periodExists(periodId)) {
      throw StateError('No stats are loaded for ${league.season} week $week. Run the ingestion script first.');
    }

    final weekGames = (await _matchups
            .where('leagueId', isEqualTo: league.id)
            .where('week', isEqualTo: week)
            .get())
        .docs
        .map(Matchup.fromFirestore)
        .where((m) => !m.isFinal)
        .toList();
    if (weekGames.isEmpty) throw StateError('Week $week has no games left to score.');

    final teams = {for (final t in await _teams.getTeamsInLeague(league.id)) t.id: t};
    final points = await _history.pointsForPeriod(periodId);
    final rosters = <String, List<RosterSlot>>{};
    final scores = <String, TeamWeekScore>{};
    for (final id in teams.keys) {
      rosters[id] = await _teams.getRoster(id);
      scores[id] = SeasonEngine.scoreTeam(
        roster: rosters[id]!,
        points: points,
        starterCount: league.starterCount,
      );
    }

    final ranksBefore = SeasonEngine.ranks(SeasonEngine.standings(teams.values.toList()));
    final updated = Map<String, Team>.of(teams);
    final batch = _db.batch();
    final finished = <Matchup>[];
    final results = <String, ({String result, String? opponent, double? opponentPoints})>{};

    for (final game in weekGames) {
      final home = scores[game.homeTeamId]!;
      if (game.isBye) {
        batch.update(_matchups.doc(game.id), {
          'homeScore': home.points,
          'status': 'final',
          'winnerTeamId': game.homeTeamId,
        });
        results[game.homeTeamId] = (result: 'BYE', opponent: null, opponentPoints: null);
        finished.add(_final(game, home.points, 0, game.homeTeamId));
        continue;
      }
      final away = scores[game.awayTeamId!]!;
      final winner = SeasonEngine.winner(
        home: game.homeTeamId,
        away: game.awayTeamId!,
        homeScore: home.points,
        awayScore: away.points,
        playoff: game.isPlayoff,
      );
      batch.update(_matchups.doc(game.id), {
        'homeScore': home.points,
        'awayScore': away.points,
        'status': 'final',
        'winnerTeamId': winner,
      });
      finished.add(_final(game, home.points, away.points, winner));

      String outcome(String teamId) => winner == null ? 'T' : (winner == teamId ? 'W' : 'L');
      results[game.homeTeamId] = (result: outcome(game.homeTeamId), opponent: game.awayTeamId, opponentPoints: away.points);
      results[game.awayTeamId!] = (result: outcome(game.awayTeamId!), opponent: game.homeTeamId, opponentPoints: home.points);

      // Only regular-season games count toward the record.
      if (!game.isPlayoff) {
        for (final id in [game.homeTeamId, game.awayTeamId!]) {
          final t = updated[id]!;
          final r = outcome(id);
          updated[id] = Team(
            id: t.id,
            leagueId: t.leagueId,
            ownerId: t.ownerId,
            teamName: t.teamName,
            wins: t.wins + (r == 'W' ? 1 : 0),
            losses: t.losses + (r == 'L' ? 1 : 0),
            ties: t.ties + (r == 'T' ? 1 : 0),
            pointsFor: t.pointsFor + scores[id]!.points,
          );
        }
      }
    }

    for (final t in updated.values) {
      final before = teams[t.id]!;
      if (t.gamesPlayed != before.gamesPlayed) {
        batch.update(_db.collection('teams').doc(t.id), {
          'wins': t.wins,
          'losses': t.losses,
          'ties': t.ties,
          'pointsFor': double.parse(t.pointsFor.toStringAsFixed(1)),
        });
      }
    }

    final ranksAfter = SeasonEngine.ranks(SeasonEngine.standings(updated.values.toList()));
    for (final entry in results.entries) {
      final score = scores[entry.key]!;
      final r = entry.value;
      batch.set(_db.collection('weeklyReports').doc(WeeklyReport.idFor(entry.key, periodId)), {
        'teamId': entry.key,
        'leagueId': league.id,
        'scoringPeriodId': periodId,
        'week': week,
        'pointsEarned': score.points,
        'optimalPoints': score.optimalPoints,
        'rosterEfficiency': score.optimalPoints == 0 ? 1.0 : score.points / score.optimalPoints,
        'rankChange': (ranksBefore[entry.key] ?? 0) - (ranksAfter[entry.key] ?? 0),
        'rank': ranksAfter[entry.key] ?? 0,
        'result': r.result,
        'opponentTeamId': r.opponent,
        'opponentPoints': r.opponentPoints,
        'topScorerName': score.topScorer?.playerName,
        'topScorerPoints': score.topScorer == null ? null : score.topScorerPoints,
        'bestBenchName': score.bestBench?.playerName,
        'bestBenchPoints': score.bestBench == null ? null : score.bestBenchPoints,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (onWeekScored != null) await onWeekScored!(batch, league, finished);

    _advance(batch, league, updated.values.toList(), finished);
    await batch.commit();
  }

  /// Moves the league forward after week [League.currentWeek] is scored.
  void _advance(WriteBatch batch, League league, List<Team> teams, List<Matchup> finished) {
    final leagueRef = _db.collection('leagues').doc(league.id);
    final week = league.currentWeek;
    final next = week + 1;

    if (league.phase == 'regular' && week < league.regularSeasonWeeks) {
      batch.update(leagueRef, {'currentWeek': next, 'lineupLocked': false});
      return;
    }

    if (league.phase == 'regular') {
      final pairings = SeasonEngine.seedPlayoffs(SeasonEngine.standings(teams), league.playoffTeams);
      if (pairings.isEmpty) {
        final champion = SeasonEngine.standings(teams).first.id;
        batch.update(leagueRef, {'phase': 'complete', 'lineupLocked': false, 'championTeamId': champion});
        return;
      }
      for (var i = 0; i < pairings.length; i++) {
        _writeMatchup(batch, league, week: next, index: i, pairing: pairings[i], playoffRound: 1);
      }
      batch.update(leagueRef, {'phase': 'playoffs', 'currentWeek': next, 'lineupLocked': false});
      return;
    }

    // Playoffs: winners of this round meet next week, or the season ends.
    final winners = [for (final m in finished) m.winnerTeamId ?? m.homeTeamId];
    if (winners.length >= 2) {
      final round = finished.first.round + 1;
      _writeMatchup(batch, league,
          week: next, index: 0, pairing: (home: winners[0], away: winners[1]), playoffRound: round);
      batch.update(leagueRef, {'currentWeek': next, 'lineupLocked': false});
    } else {
      batch.update(leagueRef, {
        'phase': 'complete',
        'lineupLocked': false,
        'championTeamId': winners.isEmpty ? null : winners.first,
      });
    }
  }

  void _writeMatchup(
    WriteBatch batch,
    League league, {
    required int week,
    required int index,
    required Pairing pairing,
    int playoffRound = 0,
  }) {
    batch.set(_matchups.doc(Matchup.idFor(league.id, week, index)), {
      'leagueId': league.id,
      'week': week,
      'homeTeamId': pairing.home,
      'awayTeamId': pairing.away,
      'homeScore': 0.0,
      'awayScore': 0.0,
      'status': 'scheduled',
      'type': playoffRound > 0 ? 'playoff' : 'regular',
      'round': playoffRound,
      'winnerTeamId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Matchup _final(Matchup m, double home, double away, String? winner) => Matchup(
        id: m.id,
        leagueId: m.leagueId,
        week: m.week,
        homeTeamId: m.homeTeamId,
        awayTeamId: m.awayTeamId,
        homeScore: home,
        awayScore: away,
        status: 'final',
        type: m.type,
        round: m.round,
        winnerTeamId: winner,
      );

  Future<bool> _periodExists(String periodId) async =>
      (await _db.collection('scoringPeriods').doc(periodId).get()).exists;
}
