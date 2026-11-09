import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/roster_slot.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../theme.dart';
import 'player_picker_screen.dart';

/// Use Case 3: a team's roster and lineup. The owner can add and drop
/// players and move them between starters and bench; anyone else sees a
/// read-only roster.
class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    required this.league,
    required this.teamId,
    required this.viewerId,
    this.extraActions = const [],
  });

  final League league;
  final String teamId;
  final String viewerId;

  /// Buttons other features add to the owner's team page (for example, the
  /// AI Coach).
  final List<Widget> extraActions;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _teams = TeamService();
  late final Stream<Team?> _teamStream = _teams.watchTeam(widget.teamId);
  late final Stream<List<RosterSlot>> _rosterStream = _teams.watchRoster(widget.teamId);
  final Set<String> _busy = {};

  bool get _isOwner => widget.teamId == Team.idFor(widget.league.id, widget.viewerId);

  Future<void> _run(String slotId, Future<void> Function() action) async {
    setState(() => _busy.add(slotId));
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy.remove(slotId));
    }
  }

  Future<void> _confirmDrop(RosterSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Drop ${slot.playerName}?'),
        content: const Text('Another team will be able to add this player.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Drop')),
        ],
      ),
    );
    if (ok == true) {
      await _run(slot.id, () => _teams.dropPlayer(league: widget.league, slot: slot));
    }
  }

  Future<void> _rename(Team team) async {
    final controller = TextEditingController(text: team.teamName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename team'),
        content: TextField(controller: controller, maxLength: 30, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _run('rename', () => _teams.renameTeam(team.id, name));
  }

  Widget _slotTile(RosterSlot slot) {
    final busy = _busy.contains(slot.id);
    final locked = widget.league.lineupLocked;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: slot.isStarter ? PodiumColors.gold : PodiumColors.line,
        foregroundColor: slot.isStarter ? PodiumColors.navy : PodiumColors.chalk,
        child: Text(
          slot.slotPosition.isEmpty ? '?' : slot.slotPosition,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(slot.playerName),
      subtitle: Text(
        '${slot.realTeam} · ${slot.sport}',
        style: const TextStyle(color: PodiumColors.muted),
      ),
      trailing: !_isOwner
          ? null
          : busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: slot.isStarter ? 'Move to bench' : 'Start',
                      icon: Icon(slot.isStarter ? Icons.arrow_downward : Icons.arrow_upward),
                      onPressed: locked
                          ? null
                          : () => _run(
                                slot.id,
                                () => _teams.setStarter(
                                  league: widget.league,
                                  slot: slot,
                                  isStarter: !slot.isStarter,
                                ),
                              ),
                    ),
                    IconButton(
                      tooltip: 'Drop',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: locked ? null : () => _confirmDrop(slot),
                    ),
                  ],
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Team?>(
      stream: _teamStream,
      builder: (context, teamSnap) {
        final team = teamSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(team?.teamName ?? 'Team'),
            actions: [
              if (_isOwner && team != null)
                IconButton(
                  tooltip: 'Rename team',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rename(team),
                ),
            ],
          ),
          floatingActionButton: _isOwner && !widget.league.lineupLocked && widget.league.draftComplete
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add players'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PlayerPickerScreen(league: widget.league)),
                  ),
                )
              : null,
          body: StreamBuilder<List<RosterSlot>>(
            stream: _rosterStream,
            builder: (context, rosterSnap) {
              if (!rosterSnap.hasData) return const Center(child: CircularProgressIndicator());
              final roster = rosterSnap.data!;
              final starters = roster.where((s) => s.isStarter).toList();
              final bench = roster.where((s) => !s.isStarter).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '${team?.record ?? '0-0'} · ${(team?.pointsFor ?? 0).toStringAsFixed(1)} pts · '
                      '${roster.length}/${widget.league.rosterSize} players',
                      style: const TextStyle(color: PodiumColors.muted),
                    ),
                  ),
                  if (widget.league.lineupLocked)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PodiumColors.dangerTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Lineups are locked while this week is being scored.'),
                    ),
                  if (_isOwner && widget.extraActions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Wrap(spacing: 8, runSpacing: 8, children: widget.extraActions),
                    ),
                  _SectionHeader(
                    title: 'Starters',
                    detail: '${starters.length}/${widget.league.starterCount}',
                  ),
                  if (starters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No starters yet.', style: TextStyle(color: PodiumColors.muted)),
                    ),
                  for (final s in starters) _slotTile(s),
                  _SectionHeader(title: 'Bench', detail: '${bench.length}'),
                  if (bench.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Bench is empty.', style: TextStyle(color: PodiumColors.muted)),
                    ),
                  for (final s in bench) _slotTile(s),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(width: 8),
          Text(detail, style: const TextStyle(color: PodiumColors.muted)),
        ],
      ),
    );
  }
}
