import 'package:flutter/material.dart';

import '../../models/player_stat.dart';
import '../../models/scoring_period.dart';
import '../../services/scoring_service.dart';
import '../../theme.dart';

/// Use Case 10: Live Scoring. Shows every player's fantasy points for a week,
/// read live from Firestore after the ingestion script scores the games.
class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  static const _positions = ['All', 'QB', 'RB', 'WR'];

  final _service = ScoringService();
  late final Stream<List<ScoringPeriod>> _periods = _service.watchPeriods();
  final Map<String, Stream<List<PlayerWeek>>> _weekStreams = {};

  String? _selectedPeriodId;
  String _position = 'All';

  // One stream per week, created once, so switching weeks back and forth doesn't resubscribe.
  Stream<List<PlayerWeek>> _streamFor(String periodId) =>
      _weekStreams.putIfAbsent(periodId, () => _service.watchWeek(periodId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Scoring')),
      body: SafeArea(
        child: StreamBuilder<List<ScoringPeriod>>(
          stream: _periods,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _Message(
                title: 'Scores did not load.',
                body: 'Check your connection and try again.',
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final periods = snapshot.data!;
            if (periods.isEmpty) {
              return const _Message(
                title: 'No scores yet.',
                body: 'Scores appear here after game stats are imported for a week.',
              );
            }

            final selected = periods.firstWhere(
              (p) => p.id == _selectedPeriodId,
              orElse: () => periods.first,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: _WeekPicker(
                    periods: periods,
                    selectedId: selected.id,
                    onChanged: (id) => setState(() => _selectedPeriodId = id),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final position in _positions)
                        ChoiceChip(
                          label: Text(position),
                          selected: _position == position,
                          onSelected: (_) => setState(() => _position = position),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<PlayerWeek>>(
                    stream: _streamFor(selected.id),
                    builder: (context, weekSnapshot) {
                      if (weekSnapshot.hasError) {
                        return const _Message(
                          title: 'Scores did not load.',
                          body: 'Check your connection and try again.',
                        );
                      }
                      if (!weekSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final players = weekSnapshot.data!
                          .where((p) => _position == 'All' || p.position == _position)
                          .toList();
                      if (players.isEmpty) {
                        return const _Message(
                          title: 'No players match.',
                          body: 'Try another position or week.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: players.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: PodiumColors.line),
                        itemBuilder: (context, index) => _PlayerTile(
                          rank: index + 1,
                          player: players[index],
                          onTap: () => _showBreakdown(context, players[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context, PlayerWeek player) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PodiumColors.field,
      showDragHandle: true,
      builder: (_) => _BreakdownSheet(player: player),
    );
  }
}

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.periods,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ScoringPeriod> periods;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PodiumColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PodiumColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          dropdownColor: PodiumColors.field,
          items: [
            for (final p in periods)
              DropdownMenuItem(value: p.id, child: Text(p.label)),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.rank, required this.player, required this.onTap});

  final int rank;
  final PlayerWeek player;
  final VoidCallback onTap;

  Color get _rankColor {
    switch (rank) {
      case 1:
        return PodiumColors.gold;
      case 2:
        return PodiumColors.silver;
      case 3:
        return PodiumColors.bronze;
      default:
        return PodiumColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      if (player.position != null) player.position!,
      if (player.realTeam.isNotEmpty) player.realTeam,
    ].join(', ');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: SizedBox(
        width: 32,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _rankColor),
        ),
      ),
      title: Text(player.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(details, style: const TextStyle(color: PodiumColors.muted)),
      trailing: Text(
        player.points.toStringAsFixed(1),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: PodiumColors.gold,
        ),
      ),
    );
  }
}

class _BreakdownSheet extends StatelessWidget {
  const _BreakdownSheet({required this.player});

  final PlayerWeek player;

  static const _labels = {
    'passYds': 'Passing yards',
    'passTD': 'Passing touchdowns',
    'passInt': 'Interceptions',
    'rushYds': 'Rushing yards',
    'rushTD': 'Rushing touchdowns',
    'rec': 'Receptions',
    'recYds': 'Receiving yards',
    'recTD': 'Receiving touchdowns',
    'twoPt': 'Two-point conversions',
    'fumLost': 'Fumbles lost',
  };

  static String _format(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = _labels.keys.where(player.stats.containsKey).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(player.fullName, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${player.points.toStringAsFixed(1)} fantasy points'
              '${player.games > 1 ? ' across ${player.games} games' : ''}',
              style: const TextStyle(color: PodiumColors.gold, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            for (final key in stats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_labels[key]!, style: const TextStyle(color: PodiumColors.muted)),
                    ),
                    Text(_format(player.stats[key]!), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_football_outlined, size: 48, color: PodiumColors.muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: PodiumColors.muted)),
          ],
        ),
      ),
    );
  }
}
