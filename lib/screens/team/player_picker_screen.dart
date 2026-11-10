import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/player_stat.dart';
import '../../models/scoring_period.dart';
import '../../services/scoring_service.dart';
import '../../services/team_service.dart';
import '../../theme.dart';

/// Use Case 3: browse eligible players and add them to your roster.
/// Only players from the league's sports who aren't on another roster show.
/// Players are ranked by fantasy points in the chosen week of the season.
class PlayerPickerScreen extends StatefulWidget {
  const PlayerPickerScreen({super.key, required this.league});

  final League league;

  @override
  State<PlayerPickerScreen> createState() => _PlayerPickerScreenState();
}

class _PlayerPickerScreenState extends State<PlayerPickerScreen> {
  final _scoring = ScoringService();
  final _teams = TeamService();
  final _search = TextEditingController();
  late final Stream<List<ScoringPeriod>> _periods = _scoring.watchPeriods();
  late final Stream<Set<String>> _taken = _teams.watchTakenPlayerIds(widget.league.id);

  String? _periodId;
  Stream<List<PlayerWeek>>? _weekStream;
  String _position = 'All';
  final Set<String> _adding = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectPeriod(String id) {
    setState(() {
      _periodId = id;
      _weekStream = _scoring.watchWeek(id);
    });
  }

  Future<void> _add(PlayerWeek player) async {
    setState(() => _adding.add(player.playerId));
    try {
      await _teams.addPlayer(league: widget.league, player: player);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${player.fullName} added to your roster.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _adding.remove(player.playerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Players')),
      body: StreamBuilder<List<ScoringPeriod>>(
        stream: _periods,
        builder: (context, periodSnap) {
          if (!periodSnap.hasData) return const Center(child: CircularProgressIndicator());
          final periods = periodSnap.data!
              .where((p) => p.season == widget.league.season)
              .toList();
          if (periods.isEmpty) {
            return const Center(child: Text('No player data is loaded for this season yet.'));
          }
          if (_periodId == null) {
            // Default to the latest loaded week. Scheduled after this frame
            // because setState can't run during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _periodId == null) _selectPeriod(periods.first.id);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'Search players',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _periodId,
                      items: [
                        for (final p in periods)
                          DropdownMenuItem(value: p.id, child: Text('Wk ${p.week}')),
                      ],
                      onChanged: (v) {
                        if (v != null) _selectPeriod(v);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<Set<String>>(
                  stream: _taken,
                  builder: (context, takenSnap) {
                    return StreamBuilder<List<PlayerWeek>>(
                      stream: _weekStream,
                      builder: (context, weekSnap) {
                        if (!weekSnap.hasData || !takenSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final taken = takenSnap.data!;
                        final eligible = weekSnap.data!
                            .where((p) => widget.league.sports.contains(p.sport))
                            .where((p) => !taken.contains(p.playerId))
                            .toList();
                        final positions = {
                          'All',
                          for (final p in eligible)
                            if (p.position != null) p.position!,
                        }.toList();
                        final query = _search.text.trim().toLowerCase();
                        final shown = eligible
                            .where((p) => _position == 'All' || p.position == _position)
                            .where((p) =>
                                query.isEmpty ||
                                p.fullName.toLowerCase().contains(query) ||
                                p.realTeam.toLowerCase().contains(query))
                            .take(200)
                            .toList();

                        return Column(
                          children: [
                            SizedBox(
                              height: 52,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                children: [
                                  for (final pos in positions)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(pos),
                                        selected: _position == pos,
                                        onSelected: (_) => setState(() => _position = pos),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: shown.isEmpty
                                  ? const Center(child: Text('No available players match.'))
                                  : ListView.builder(
                                      itemCount: shown.length,
                                      itemBuilder: (context, i) {
                                        final p = shown[i];
                                        final busy = _adding.contains(p.playerId);
                                        return ListTile(
                                          title: Text(p.fullName),
                                          subtitle: Text(
                                            '${p.position ?? '?'} · ${p.realTeam} · ${p.sport}',
                                            style: const TextStyle(color: PodiumColors.muted),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                p.points.toStringAsFixed(1),
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 8),
                                              busy
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : IconButton(
                                                      tooltip: 'Add to roster',
                                                      icon: const Icon(Icons.add_circle_outline,
                                                          color: PodiumColors.gold),
                                                      onPressed: () => _add(p),
                                                    ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
