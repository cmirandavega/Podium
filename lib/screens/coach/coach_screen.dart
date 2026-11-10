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
import '../../widgets/podium_ui.dart';

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
    if (error is AiUnavailableException) {
      return "The Coach didn't answer (${error.cause ?? error.message}). Your question is saved; tap Retry.";
    }
    if (error is AiBadResponseException) {
      return "The Coach didn't answer (${error.message}). Your question is saved; tap Retry.";
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PodiumColors.navy,
        borderRadius: BorderRadius.circular(PodiumRadii.tile),
        border: Border.all(color: status == 'pending' ? PodiumColors.gold : PodiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert_rounded, size: 18, color: PodiumColors.gold),
              const SizedBox(width: 6),
              Text('LINEUP CHANGE', style: PodiumText.overline.copyWith(color: PodiumColors.gold, fontSize: 11)),
              const Spacer(),
              if (status == 'applied') const StatusPill.gold('APPLIED'),
              if (status == 'dismissed') const StatusPill(label: 'DISMISSED'),
            ],
          ),
          const SizedBox(height: 10),
          _swapLine(Icons.arrow_upward_rounded, PodiumColors.gold, 'Start', start?.playerName ?? m.startPlayerId ?? ''),
          const SizedBox(height: 6),
          _swapLine(Icons.arrow_downward_rounded, PodiumColors.silver, 'Bench', bench?.playerName ?? m.benchPlayerId ?? ''),
          if (status != 'applied' && status != 'dismissed') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: busy || league.lineupLocked ? null : () => _apply(league, m),
                    child: Text(league.lineupLocked ? 'Lineups locked' : 'Set lineup'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: busy ? null : () => _coach.dismissSuggestion(league: league, message: m),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _swapLine(IconData icon, Color color, String verb, String player) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$verb ', style: const TextStyle(fontSize: 13, color: PodiumColors.muted)),
        Expanded(
          child: Text(
            player,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _bubble(League league, AiMessage m, Map<String, RosterSlot> roster) {
    final mine = m.isUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: mine ? 300 : 340),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        decoration: BoxDecoration(
          color: mine ? PodiumColors.line : PodiumColors.field,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine ? null : Border.all(color: PodiumColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: PodiumColors.gold),
                    const SizedBox(width: 6),
                    Text('COACH', style: PodiumText.overline.copyWith(fontSize: 11, color: PodiumColors.gold)),
                  ],
                ),
              ),
            Text(m.content, style: const TextStyle(fontSize: 14, height: 1.45)),
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
            title: const Row(
              children: [
                TintedIcon(
                  icon: Icons.auto_awesome,
                  color: PodiumColors.navy,
                  background: PodiumColors.gold,
                  size: 36,
                ),
                SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coach'),
                    Text(
                      'Lineup advice from your roster',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: PodiumColors.muted),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              StreamBuilder<int>(
                stream: _remaining,
                builder: (context, snap) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: snap.hasData ? StatusPill(label: '${snap.data} LEFT TODAY') : const SizedBox.shrink(),
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
                                          PodiumCard(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            radius: PodiumRadii.tile,
                                            onTap: _thinking || roster.isEmpty ? null : () => _ask(league, s),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.auto_awesome, size: 18, color: PodiumColors.gold),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                ),
                                                const Icon(Icons.north_east_rounded, size: 18, color: PodiumColors.muted),
                                              ],
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
                            // After each Coach reply, offer the suggested questions again.
                            if (messages.isNotEmpty && !messages.last.isUser && !_thinking && roster.isNotEmpty)
                              SizedBox(
                                height: 48,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  children: [
                                    for (final s in _suggestions)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ActionChip(
                                          label: Text(s),
                                          onPressed: () => _ask(league, s),
                                        ),
                                      ),
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
                            Container(
                              decoration: const BoxDecoration(
                                color: PodiumColors.deep,
                                border: Border(top: BorderSide(color: PodiumColors.line)),
                              ),
                              child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
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
                                    const SizedBox(width: 8),
                                    IconButton.filled(
                                      tooltip: 'Send',
                                      style: IconButton.styleFrom(
                                        backgroundColor: PodiumColors.gold,
                                        foregroundColor: PodiumColors.navy,
                                        disabledBackgroundColor: PodiumColors.line,
                                        disabledForegroundColor: PodiumColors.muted,
                                        fixedSize: const Size(50, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(PodiumRadii.control),
                                        ),
                                      ),
                                      icon: const Icon(Icons.arrow_upward_rounded),
                                      onPressed: _thinking || roster.isEmpty || unanswered
                                          ? null
                                          : () => _ask(league, _input.text),
                                    ),
                                  ],
                                ),
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
