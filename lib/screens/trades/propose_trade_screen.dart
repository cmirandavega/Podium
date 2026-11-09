import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/roster_slot.dart';
import '../../models/team.dart';
import '../../models/trade.dart';
import '../../models/trade_analysis.dart';
import '../../services/ai/ai_exceptions.dart';
import '../../services/team_service.dart';
import '../../services/trade_analyzer_service.dart';
import '../../services/trade_service.dart';
import '../../theme.dart';
import 'analysis_card.dart';

/// Build a trade offer (or a counter-offer), analyze it with AI, and send it.
/// Also works as a "what if" tool: analyze without sending (Use Case 4).
class ProposeTradeScreen extends StatefulWidget {
  const ProposeTradeScreen({
    super.key,
    required this.league,
    required this.userId,
    this.counterOf,
  });

  final League league;
  final String userId;

  /// When set, this is a counter-offer to that trade.
  final Trade? counterOf;

  @override
  State<ProposeTradeScreen> createState() => _ProposeTradeScreenState();
}

class _ProposeTradeScreenState extends State<ProposeTradeScreen> {
  final _teams = TeamService();
  final _trades = TradeService();
  final _analyzer = TradeAnalyzerService();
  late final String _myTeamId = Team.idFor(widget.league.id, widget.userId);
  late final Stream<List<Team>> _teamStream = _teams.watchTeamsInLeague(widget.league.id);
  late final Stream<List<RosterSlot>> _myRoster = _teams.watchRoster(_myTeamId);

  String? _otherTeamId;
  Stream<List<RosterSlot>>? _theirRoster;
  final Set<String> _send = {};
  final Set<String> _receive = {};
  TradeAnalysis? _analysis;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final counter = widget.counterOf;
    if (counter != null) {
      // Counter-offers start from the original, with sides swapped.
      _selectTeam(counter.proposerTeamId);
      _send.addAll(counter.requested.map((i) => i.playerId));
      _receive.addAll(counter.offered.map((i) => i.playerId));
    }
  }

  void _selectTeam(String teamId) {
    _otherTeamId = teamId;
    _theirRoster = _teams.watchRoster(teamId);
    if (widget.counterOf == null) _send.clear();
    _receive.clear();
    _analysis = null;
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _analyze(List<RosterSlot> mine, List<RosterSlot> theirs) async {
    setState(() => _busy = true);
    try {
      final result = await _analyzer.analyzeTrade(
        league: widget.league,
        proposerTeamId: _myTeamId,
        receiverTeamId: _otherTeamId!,
        offered: mine.where((s) => _send.contains(s.playerId)).toList(),
        requested: theirs.where((s) => _receive.contains(s.playerId)).toList(),
      );
      if (mounted) setState(() => _analysis = result);
    } on AiLimitReachedException catch (error) {
      _toast(error.toString());
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(Team receiver, List<RosterSlot> mine, List<RosterSlot> theirs) async {
    setState(() => _busy = true);
    try {
      final offered = mine.where((s) => _send.contains(s.playerId)).toList();
      final requested = theirs.where((s) => _receive.contains(s.playerId)).toList();
      if (widget.counterOf != null) {
        await _trades.counter(
          league: widget.league,
          original: widget.counterOf!,
          originalProposer: receiver,
          offered: offered,
          requested: requested,
        );
      } else {
        await _trades.propose(league: widget.league, receiver: receiver, offered: offered, requested: requested);
      }
      if (!mounted) return;
      _toast(widget.counterOf != null ? 'Counter-offer sent.' : 'Trade offer sent.');
      Navigator.of(context).pop();
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _rosterPicker(String title, List<RosterSlot> roster, Set<String> picked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (roster.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No players.', style: TextStyle(color: PodiumColors.muted)),
          ),
        for (final s in roster)
          CheckboxListTile(
            dense: true,
            value: picked.contains(s.playerId),
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      v == true ? picked.add(s.playerId) : picked.remove(s.playerId);
                      _analysis = null;
                    }),
            title: Text(s.playerName),
            subtitle: Text(
              '${s.slotPosition} · ${s.realTeam} · ${s.sport}${s.isStarter ? ' · starter' : ''}',
              style: const TextStyle(color: PodiumColors.muted),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCounter = widget.counterOf != null;
    return Scaffold(
      appBar: AppBar(title: Text(isCounter ? 'Counter-offer' : 'Propose Trade')),
      body: StreamBuilder<List<Team>>(
        stream: _teamStream,
        builder: (context, teamSnap) {
          if (!teamSnap.hasData) return const Center(child: CircularProgressIndicator());
          final others = teamSnap.data!.where((t) => t.id != _myTeamId).toList()
            ..sort((a, b) => a.teamName.compareTo(b.teamName));
          if (others.isEmpty) {
            return const Center(child: Text('No other teams to trade with yet.'));
          }
          final matches = others.where((t) => t.id == _otherTeamId);
          final Team? other = matches.isEmpty ? null : matches.first;

          return StreamBuilder<List<RosterSlot>>(
            stream: _myRoster,
            builder: (context, mineSnap) {
              final mine = mineSnap.data ?? const <RosterSlot>[];
              return StreamBuilder<List<RosterSlot>>(
                stream: _theirRoster,
                builder: (context, theirSnap) {
                  final theirs = theirSnap.data ?? const <RosterSlot>[];
                  final ready = other != null && _send.isNotEmpty && _receive.isNotEmpty;
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: DropdownButtonFormField<String>(
                          initialValue: _otherTeamId,
                          decoration: const InputDecoration(labelText: 'Trade with'),
                          items: [
                            for (final t in others) DropdownMenuItem(value: t.id, child: Text(t.teamName)),
                          ],
                          onChanged: isCounter || _busy
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _selectTeam(v));
                                },
                        ),
                      ),
                      _rosterPicker('You send', mine, _send),
                      if (other != null) _rosterPicker('You receive from ${other.teamName}', theirs, _receive),
                      if (_analysis != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: AnalysisCard(
                            analysis: _analysis!,
                            proposerName: 'You',
                            receiverName: other?.teamName ?? 'Them',
                          ),
                        ),
                      if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.psychology_outlined),
                          label: const Text('Analyze with AI'),
                          onPressed: !ready || _busy ? null : () => _analyze(mine, theirs),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: FilledButton(
                          onPressed: !ready || _busy ? null : () => _submit(other!, mine, theirs),
                          child: Text(isCounter ? 'Send counter-offer' : 'Send trade offer'),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
