import 'package:flutter/material.dart';

import '../../models/ai_message.dart';
import '../../models/league.dart';
import '../../models/roster_slot.dart';
import '../../models/team.dart';
import '../../services/ai/ai_exceptions.dart';
import '../../services/coach_service.dart';
import '../../services/league_service.dart';
import '../../services/team_service.dart';
import '../../theme.dart';

/// Use Case 12: chat with the AI Assistant Coach about your team.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.leagueId, required this.userId});

  final String leagueId;
  final String userId;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _coach = CoachService();
  final _input = TextEditingController();
  late final String _teamId = Team.idFor(widget.leagueId, widget.userId);
  late final Stream<League?> _league = LeagueService().watchLeague(widget.leagueId);
  late final Stream<List<AiMessage>> _messages = _coach.watchMessages(_teamId);
  late final Stream<List<RosterSlot>> _roster = TeamService().watchRoster(_teamId);
  late final Stream<int> _remaining = _coach.watchRemaining();

  bool _thinking = false;
  String? _error;
  final Set<String> _applying = {};

  static const _suggestions = [
    'Optimize my lineup for this week',
    'Who is my weakest starter?',
    'Which available player should I add?',
    'How is my bench doing?',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask(League league, String question) async {
    if (question.trim().isEmpty) return;
    setState(() {
      _thinking = true;
      _error = null;
    });
    _input.clear();
    try {
      await _coach.ask(league: league, question: question);
    } catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _retry(League league) async {
    setState(() {
      _thinking = true;
      _error = null;
    });
    try {
      await _coach.retry(league);
    } catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  String _describe(Object error) {
    if (error is AiLimitReachedException) return error.toString();
    if (error is AiUnavailableException || error is AiBadResponseException) {
      return "The Coach didn't answer. Your question is saved; tap Retry.";
    }
    return '$error';
  }

  Future<void> _apply(League league, AiMessage message) async {
    setState(() => _applying.add(message.id!));
    try {
      await _coach.applySuggestion(league: league, message: message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lineup updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _applying.remove(message.id));
    }
  }

  Widget _suggestionCard(League league, AiMessage m, Map<String, RosterSlot> roster) {
    final start = roster[m.startPlayerId];
    final bench = roster[m.benchPlayerId];
    final status = m.suggestionStatus ?? 'pending';
    final busy = _applying.contains(m.id);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PodiumColors.navy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PodiumColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Suggested lineup change',
              style: TextStyle(fontWeight: FontWeight.w700, color: PodiumColors.gold)),
          const SizedBox(height: 4),
          Text('Start ${start?.playerName ?? m.startPlayerId}'),
          Text('Bench ${bench?.playerName ?? m.benchPlayerId}'),
          const SizedBox(height: 8),
          if (status == 'applied')
            const Text('Applied', style: TextStyle(color: PodiumColors.muted))
          else if (status == 'dismissed')
            const Text('Dismissed', style: TextStyle(color: PodiumColors.muted))
          else
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(88, 36)),
                  onPressed: busy || league.lineupLocked ? null : () => _apply(league, m),
                  child: Text(league.lineupLocked ? 'Locked' : 'Apply'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : () => _coach.dismissSuggestion(league: league, message: m),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _bubble(League league, AiMessage m, Map<String, RosterSlot> roster) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.isUser ? PodiumColors.gold.withValues(alpha: 0.2) : PodiumColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: m.isUser ? PodiumColors.gold : PodiumColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.isUser)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('AI Coach', style: TextStyle(fontSize: 12, color: PodiumColors.gold)),
              ),
            Text(m.content),
            if (m.hasSuggestion) _suggestionCard(league, m, roster),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<League?>(
      stream: _league,
      builder: (context, leagueSnap) {
        final league = leagueSnap.data;
        if (league == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('AI Coach')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Coach'),
            actions: [
              StreamBuilder<int>(
                stream: _remaining,
                builder: (context, snap) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      snap.hasData ? '${snap.data} left today' : '',
                      style: const TextStyle(color: PodiumColors.muted),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: StreamBuilder<List<RosterSlot>>(
                  stream: _roster,
                  builder: (context, rosterSnap) {
                    final roster = {for (final s in rosterSnap.data ?? const <RosterSlot>[]) s.playerId: s};
                    return StreamBuilder<List<AiMessage>>(
                      stream: _messages,
                      builder: (context, msgSnap) {
                        final messages = msgSnap.data ?? const <AiMessage>[];
                        final unanswered = messages.isNotEmpty && messages.last.isUser;
                        return Column(
                          children: [
                            if (roster.isEmpty && rosterSnap.hasData)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Add players to your roster first so the Coach has a team to look at.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: PodiumColors.muted),
                                ),
                              ),
                            Expanded(
                              child: messages.isEmpty
                                  ? ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        const Text(
                                          'Ask about your lineup, your bench, or available players. '
                                          'The Coach only uses your roster and Podium stats.',
                                          style: TextStyle(color: PodiumColors.muted),
                                        ),
                                        const SizedBox(height: 16),
                                        for (final s in _suggestions)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: OutlinedButton(
                                              onPressed: _thinking || roster.isEmpty
                                                  ? null
                                                  : () => _ask(league, s),
                                              child: Text(s),
                                            ),
                                          ),
                                      ],
                                    )
                                  : ListView(
                                      reverse: true,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      children: [
                                        for (final m in messages.reversed) _bubble(league, m, roster),
                                      ],
                                    ),
                            ),
                            if (_thinking) const LinearProgressIndicator(),
                            if (_error != null || (unanswered && !_thinking))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _error ?? 'Your last question has no answer yet.',
                                        style: const TextStyle(color: PodiumColors.danger),
                                      ),
                                    ),
                                    if (unanswered)
                                      TextButton(
                                        onPressed: _thinking ? null : () => _retry(league),
                                        child: const Text('Retry'),
                                      ),
                                  ],
                                ),
                              ),
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _input,
                                        minLines: 1,
                                        maxLines: 4,
                                        maxLength: 500,
                                        enabled: !_thinking && roster.isNotEmpty,
                                        decoration: const InputDecoration(
                                          hintText: 'Ask the Coach',
                                          counterText: '',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Send',
                                      icon: const Icon(Icons.send, color: PodiumColors.gold),
                                      onPressed: _thinking || roster.isEmpty || unanswered
                                          ? null
                                          : () => _ask(league, _input.text),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
