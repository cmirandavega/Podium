import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_feature.dart';
import '../models/ai_message.dart';
import '../models/league.dart';
import '../models/roster_slot.dart';
import '../models/team.dart';
import 'ai/ai_prompts.dart';
import 'ai/ai_service.dart';
import 'player_history_service.dart';
import 'team_service.dart';

/// A lineup change parsed from a Coach reply.
typedef LineupSwap = ({String startPlayerId, String benchPlayerId});

/// Use Case 12: the AI Assistant Coach.
///
/// Each team has one saved conversation at coachConversations/{teamId}.
/// Every question sends the team's real roster, lineup, recent weekly
/// points, and the best available players, so answers come from Podium data.
class CoachService {
  CoachService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    AiService? ai,
    TeamService? teams,
    PlayerHistoryService? history,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _ai = ai ?? AiService(),
        _teams = teams ?? TeamService(),
        _history = history ?? PlayerHistoryService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final AiService _ai;
  final TeamService _teams;
  final PlayerHistoryService _history;

  static const role = '''
You are the Podium AI Assistant Coach. You help one fantasy manager run their team in a Podium league, which can mix players from several sports into one roster with a single points system.
- Recommend lineup changes for the league's upcoming week using the weekly fantasy points in DATA.
- Keep replies under 150 words, in plain language.
- Only starters score. The league allows the number of starters given in DATA.
- When you recommend moving one bench player into the lineup in place of one starter, end your reply with exactly one line in this format and nothing after it:
[[SWAP start=<playerId of the bench player to start> bench=<playerId of the starter to bench>]]
- Use playerIds exactly as written in DATA, recommend at most one swap per reply, and never suggest a swap when lineupLocked is true.
- If the user asks about a player who isn't on their roster, answer from that player's stats in DATA if they appear there, and suggest the AI Trade Analyzer for trade questions.''';

  static final _swapPattern = RegExp(r'\[\[SWAP start=([^\s\]]+) bench=([^\s\]]+)\]\]');

  /// Splits a reply into the text to show and an optional lineup swap.
  static ({String text, LineupSwap? swap}) parseReply(String reply) {
    final match = _swapPattern.firstMatch(reply);
    final text = reply.replaceAll(_swapPattern, '').trim();
    if (match == null) return (text: text, swap: null);
    return (
      text: text,
      swap: (startPlayerId: match.group(1)!, benchPlayerId: match.group(2)!),
    );
  }

  /// Keeps a suggested swap only if it matches the current roster: the
  /// player to start is on the bench and the player to bench is starting.
  static LineupSwap? validSwap(LineupSwap? swap, List<RosterSlot> roster) {
    if (swap == null) return null;
    RosterSlot? find(String id) {
      for (final s in roster) {
        if (s.playerId == id) return s;
      }
      return null;
    }

    final start = find(swap.startPlayerId);
    final bench = find(swap.benchPlayerId);
    if (start == null || bench == null || start.isStarter || !bench.isStarter) return null;
    return swap;
  }

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _conversation(String teamId) =>
      _db.collection('coachConversations').doc(teamId);

  CollectionReference<Map<String, dynamic>> _messages(String teamId) =>
      _conversation(teamId).collection('messages');

  Stream<List<AiMessage>> watchMessages(String teamId) => _messages(teamId)
      .orderBy('createdAt')
      .snapshots()
      .map((q) => q.docs.map(AiMessage.fromFirestore).toList());

  Stream<int> watchRemaining() => _ai.watchRemaining(AiFeature.assistantCoach);

  /// Saves the question, then asks the Coach. If the AI call fails, the
  /// question stays saved and [retry] answers it later.
  Future<void> ask({required League league, required String question}) async {
    final text = question.trim();
    if (text.isEmpty) throw ArgumentError('Type a question first.');
    if (text.length > 500) throw ArgumentError('Questions can be up to 500 characters.');
    final teamId = Team.idFor(league.id, _uid);

    await _conversation(teamId).set({
      'userId': _uid,
      'teamId': teamId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _messages(teamId).add(AiMessage.user(text).toFirestore());
    await _respond(league, teamId);
  }

  /// Answers the last unanswered question.
  Future<void> retry(League league) => _respond(league, Team.idFor(league.id, _uid));

  Future<void> _respond(League league, String teamId) async {
    final saved = await _messages(teamId).orderBy('createdAt').get();
    final messages = saved.docs.map(AiMessage.fromFirestore).toList();
    if (messages.isEmpty || !messages.last.isUser) return;

    final roster = await _teams.getRoster(teamId);
    final data = await buildData(league: league, roster: roster);
    final question = messages.last.content;
    // Send the latest 20 turns so long conversations stay within limits.
    final earlier = messages.sublist(0, messages.length - 1);
    final history = earlier.length > 20 ? earlier.sublist(earlier.length - 20) : earlier;

    final reply = await _ai.chat(
      feature: AiFeature.assistantCoach,
      systemInstruction: AiPrompts.system(role),
      history: history,
      message: '$data\n\nQUESTION: $question',
    );

    final parsed = parseReply(reply);
    final swap = validSwap(parsed.swap, roster);
    await _messages(teamId).add(AiMessage(
      role: 'assistant',
      content: parsed.text,
      startPlayerId: swap?.startPlayerId,
      benchPlayerId: swap?.benchPlayerId,
    ).toFirestore());
  }

  /// The DATA block for one question: league rules, the roster with each
  /// player's weekly points, and the top available players.
  Future<String> buildData({required League league, required List<RosterSlot> roster}) async {
    final throughWeek = PlayerHistoryService.visibleThroughWeek(league);
    final weekly = await _history.weeklyPoints(
      playerIds: [for (final s in roster) s.playerId],
      season: league.season,
      throughWeek: throughWeek,
    );
    final taken = await _teams.watchTakenPlayerIds(league.id).first;
    final available = await _history.topAvailable(
      league: league,
      takenPlayerIds: taken,
      periodId: league.periodIdForWeek(throughWeek),
    );

    Map<String, Object?> player(RosterSlot s) {
      final weeks = weekly[s.playerId] ?? const <int, double>{};
      return {
        'playerId': s.playerId,
        'name': s.playerName,
        'position': s.slotPosition,
        'realTeam': s.realTeam,
        'sport': s.sport,
        'weeklyPoints': {for (final e in weeks.entries) 'week${e.key}': _round(e.value)},
        'averagePoints': _round(PlayerHistoryService.average(weeks)),
      };
    }

    return AiPrompts.dataBlock({
      // The league name is left out on purpose: the commissioner chooses it, so
      // it could carry instructions into every member's prompt. Only data from
      // the sports API and fixed league settings are sent.
      'league': {
        'sports': league.sports,
        'scoring': [
          if (league.sports.contains('NFL')) 'NFL uses standard PPR (point per reception) fantasy scoring.',
          if (league.sports.contains('Soccer'))
            'Soccer (Premier League) uses Fantasy Premier League-style scoring: appearances, goals '
                '(worth more for defenders and midfielders), assists, clean sheets, saves, and cards, '
                'scaled by 2.5 to match NFL point totals.',
        ],
        'starterCount': league.starterCount,
        'rosterSize': league.rosterSize,
        'upcomingWeek': league.currentWeek,
        'statsThroughWeek': throughWeek,
        'lineupLocked': league.lineupLocked,
      },
      'starters': [for (final s in roster.where((s) => s.isStarter)) player(s)],
      'bench': [for (final s in roster.where((s) => !s.isStarter)) player(s)],
      'topAvailablePlayers': [
        for (final p in available)
          {
            'playerId': p.playerId,
            'name': p.fullName,
            'position': p.position,
            'realTeam': p.realTeam,
            'sport': p.sport,
            'pointsInWeek$throughWeek': _round(p.points),
          },
      ],
    }, dataAsOf: DateTime.now());
  }

  /// Applies a suggested swap through Team Builder, which checks the roster
  /// and lineup lock again before saving (Use Case 12 -> Use Case 3).
  Future<void> applySuggestion({required League league, required AiMessage message}) async {
    if (!message.hasSuggestion || message.id == null) return;
    await _teams.swapStarter(
      league: league,
      startPlayerId: message.startPlayerId!,
      benchPlayerId: message.benchPlayerId!,
    );
    await _setStatus(league, message, 'applied');
  }

  Future<void> dismissSuggestion({required League league, required AiMessage message}) =>
      _setStatus(league, message, 'dismissed');

  Future<void> _setStatus(League league, AiMessage message, String status) => _messages(
        Team.idFor(league.id, _uid),
      ).doc(message.id).update({'suggestionStatus': status});

  static double _round(double v) => (v * 10).roundToDouble() / 10;
}
