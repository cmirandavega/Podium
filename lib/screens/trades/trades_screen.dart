import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/team.dart';
import '../../models/trade.dart';
import '../../models/trade_analysis.dart';
import '../../services/ai/ai_exceptions.dart';
import '../../services/league_service.dart';
import '../../services/team_service.dart';
import '../../services/trade_analyzer_service.dart';
import '../../services/trade_service.dart';
import '../../theme.dart';
import 'analysis_card.dart';
import 'propose_trade_screen.dart';

/// Use Case 8: offers to you, your offers, and the league's trade history.
class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key, required this.leagueId, required this.userId});

  final String leagueId;
  final String userId;

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> {
  late final Stream<League?> _league = LeagueService().watchLeague(widget.leagueId);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.leagueId);
  late final Stream<List<Trade>> _trades = TradeService().watchLeagueTrades(widget.leagueId);

  Widget _tradeTile(BuildContext context, League league, Trade t, Map<String, Team> teams) {
    String name(String id) => teams[id]?.teamName ?? 'Team';
    return ListTile(
      leading: Icon(
        t.isPending ? Icons.swap_horiz : Icons.history,
        color: t.isPending ? PodiumColors.gold : PodiumColors.muted,
      ),
      title: Text('${name(t.proposerTeamId)} → ${name(t.receiverTeamId)}'),
      subtitle: Text(
        '${t.offered.map((i) => i.playerName).join(', ')} for ${t.requested.map((i) => i.playerName).join(', ')}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: PodiumColors.muted),
      ),
      trailing: Text(t.statusLabel),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TradeDetailScreen(league: league, trade: t, teams: teams, userId: widget.userId),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<League?>(
      stream: _league,
      builder: (context, leagueSnap) {
        final league = leagueSnap.data;
        if (league == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Trades'),
            actions: [
              IconButton(
                tooltip: 'AI roster report',
                icon: const Icon(Icons.psychology_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RosterReportScreen(league: league)),
                ),
              ),
            ],
          ),
          floatingActionButton: league.phase == 'complete'
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Propose trade'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProposeTradeScreen(league: league, userId: widget.userId),
                    ),
                  ),
                ),
          body: StreamBuilder<List<Team>>(
            stream: _teams,
            builder: (context, teamSnap) {
              final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
              return StreamBuilder<List<Trade>>(
                stream: _trades,
                builder: (context, snap) {
                  if (snap.hasError) return const Center(child: Text('Unable to load trades.'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final all = snap.data!;
                  final incoming = all.where((t) => t.isPending && t.receiverId == widget.userId).toList();
                  final outgoing = all.where((t) => t.isPending && t.proposerId == widget.userId).toList();
                  final history = all.where((t) => !t.isPending).toList();
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      _section('Offers to you'),
                      if (incoming.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('None right now.', style: TextStyle(color: PodiumColors.muted)),
                        ),
                      for (final t in incoming) _tradeTile(context, league, t, teams),
                      _section('Your offers'),
                      if (outgoing.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('None right now.', style: TextStyle(color: PodiumColors.muted)),
                        ),
                      for (final t in outgoing) _tradeTile(context, league, t, teams),
                      _section('League history'),
                      for (final t in history) _tradeTile(context, league, t, teams),
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

/// One trade: the players on each side, an AI analysis, and the actions
/// the viewer can take.
class TradeDetailScreen extends StatefulWidget {
  const TradeDetailScreen({
    super.key,
    required this.league,
    required this.trade,
    required this.teams,
    required this.userId,
  });

  final League league;
  final Trade trade;
  final Map<String, Team> teams;
  final String userId;

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  final _trades = TradeService();
  final _analyzer = TradeAnalyzerService();
  final _teamService = TeamService();
  TradeAnalysis? _analysis;
  bool _busy = false;

  Trade get t => widget.trade;
  String _name(String id) => widget.teams[id]?.teamName ?? 'Team';

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String done, {bool pop = true}) async {
    setState(() => _busy = true);
    try {
      await action();
      _toast(done);
      if (pop && mounted) Navigator.of(context).pop();
    } on AiLimitReachedException catch (error) {
      _toast(error.toString());
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() => _run(() async {
        final proposerRoster = await _teamService.getRoster(t.proposerTeamId);
        final receiverRoster = await _teamService.getRoster(t.receiverTeamId);
        final offeredIds = {for (final i in t.offered) i.playerId};
        final requestedIds = {for (final i in t.requested) i.playerId};
        final result = await _analyzer.analyzeTrade(
          league: widget.league,
          proposerTeamId: t.proposerTeamId,
          receiverTeamId: t.receiverTeamId,
          offered: proposerRoster.where((s) => offeredIds.contains(s.playerId)).toList(),
          requested: receiverRoster.where((s) => requestedIds.contains(s.playerId)).toList(),
          tradeId: t.id,
        );
        if (mounted) setState(() => _analysis = result);
      }, 'Analysis ready.', pop: false);

  Widget _side(String title, List<TradeItem> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final i in items) Text('• ${i.playerName}'),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isReceiver = t.receiverId == widget.userId;
    final isProposer = t.proposerId == widget.userId;
    final involved = isReceiver || isProposer;
    return Scaffold(
      appBar: AppBar(title: Text('Trade · ${t.statusLabel}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _side('${_name(t.proposerTeamId)} sends', t.offered),
          const SizedBox(height: 16),
          _side('${_name(t.receiverTeamId)} sends', t.requested),
          if (t.parentTradeId != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('This is a counter-offer.', style: TextStyle(color: PodiumColors.muted)),
            ),
          const SizedBox(height: 20),
          if (_analysis != null) ...[
            AnalysisCard(
              analysis: _analysis!,
              proposerName: _name(t.proposerTeamId),
              receiverName: _name(t.receiverTeamId),
            ),
            const SizedBox(height: 16),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
          if (involved && t.isPending)
            OutlinedButton.icon(
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Analyze with AI'),
              onPressed: _busy ? null : _analyze,
            ),
          if (isReceiver && t.isPending) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || widget.league.lineupLocked
                  ? null
                  : () => _run(() => _trades.accept(league: widget.league, trade: t), 'Trade completed.'),
              child: Text(widget.league.lineupLocked ? 'Accept (lineups locked)' : 'Accept'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ProposeTradeScreen(
                            league: widget.league,
                            userId: widget.userId,
                            counterOf: t,
                          ),
                        ),
                      ),
              child: const Text('Counter'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _run(() => _trades.reject(league: widget.league, trade: t), 'Trade rejected.'),
              child: const Text('Reject'),
            ),
          ],
          if (isProposer && t.isPending) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : () => _run(() => _trades.cancel(league: widget.league, trade: t), 'Offer withdrawn.'),
              child: const Text('Withdraw offer'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Use Case 4 alternate path: analyze your roster without a trade.
class RosterReportScreen extends StatefulWidget {
  const RosterReportScreen({super.key, required this.league});

  final League league;

  @override
  State<RosterReportScreen> createState() => _RosterReportScreenState();
}

class _RosterReportScreenState extends State<RosterReportScreen> {
  late final Future<TradeAnalysis> _report = TradeAnalyzerService().analyzeRoster(league: widget.league);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Roster Report')),
      body: FutureBuilder<TradeAnalysis>(
        future: _report,
        builder: (context, snap) {
          if (snap.hasError) {
            final error = snap.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is AiLimitReachedException || error is StateError
                      ? '$error'
                      : 'The AI report is temporarily unavailable. Try again in a minute.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [AnalysisCard(analysis: snap.data!)],
          );
        },
      ),
    );
  }
}
