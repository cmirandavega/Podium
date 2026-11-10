import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';

/// Global leaderboard as its own screen.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: const GlobalLeaderboardView(),
    );
  }
}

/// The global leaderboard body: podium for the top 3, then a ranked list.
/// Used by [LeaderboardScreen] and the Leaders tab.
class GlobalLeaderboardView extends StatefulWidget {
  const GlobalLeaderboardView({super.key, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 40)});

  final EdgeInsets padding;

  @override
  State<GlobalLeaderboardView> createState() => _GlobalLeaderboardViewState();
}

class _GlobalLeaderboardViewState extends State<GlobalLeaderboardView> {
  late final Stream<List<LeaderboardEntry>> _stream = LeaderboardService().getLeaderboard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load leaderboard.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Padding(
            padding: widget.padding,
            child: const EmptyCard(
              icon: Icons.emoji_events_outlined,
              title: 'No standings yet',
              message: 'Teams show up here once their first week is scored.',
            ),
          );
        }
        final rows = [
          for (final e in entries)
            PodiumEntry(name: e.teamName, points: e.points, detail: '${e.sport} · ${e.season}'),
        ];
        return ListView(
          padding: widget.padding,
          children: [
            PodiumStand(top: rows.take(3).toList()),
            if (rows.length > 3) ...[
              const SizedBox(height: 22),
              RankedList(entries: rows.sublist(3), firstRank: 4),
            ],
          ],
        );
      },
    );
  }
}

/// One row on a leaderboard.
class PodiumEntry {
  const PodiumEntry({
    required this.name,
    required this.points,
    this.detail,
    this.isMe = false,
    this.record,
  });

  final String name;
  final double points;
  final String? detail;
  final bool isMe;
  final String? record;
}

/// Top three on gold, silver, and bronze steps: 2nd left, 1st center, 3rd right.
class PodiumStand extends StatelessWidget {
  const PodiumStand({super.key, required this.top});

  final List<PodiumEntry> top;

  @override
  Widget build(BuildContext context) {
    Widget slot(int rank, double stepHeight, double avatar) {
      if (top.length < rank) return const Expanded(child: SizedBox.shrink());
      final entry = top[rank - 1];
      final color = PodiumColors.medal(rank)!;
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (rank == 1) ...[
              const Icon(Icons.workspace_premium, color: PodiumColors.gold, size: 26),
              const SizedBox(height: 4),
            ],
            InitialsAvatar(
              name: entry.name,
              size: avatar,
              ring: color,
              ringWidth: 3,
              background: PodiumColors.field,
              foreground: PodiumColors.chalk,
            ),
            const SizedBox(height: 8),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (entry.isMe)
              const Text(
                'YOU',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: PodiumColors.gold),
              ),
            const SizedBox(height: 2),
            Text(
              formatPoints(entry.points),
              style: PodiumText.score(
                size: rank == 1 ? 20 : 18,
                color: rank == 3 ? PodiumColors.bronzeText : color,
                weight: rank == 1 ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: stepHeight,
              width: double.infinity,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                  bottom: Radius.circular(4),
                ),
              ),
              child: Text(
                '$rank',
                style: PodiumText.score(size: rank == 1 ? 48 : (rank == 2 ? 40 : 36), color: PodiumColors.navy),
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: [
        for (var i = 0; i < top.length; i++)
          '${i + 1}: ${top[i].name}, ${formatPoints(top[i].points)} points',
      ].join('. '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          slot(2, 96, 56),
          const SizedBox(width: 8),
          slot(1, 128, 68),
          const SizedBox(width: 8),
          slot(3, 72, 56),
        ],
      ),
    );
  }
}

/// Ranked rows below the podium, in a card with a header.
class RankedList extends StatelessWidget {
  const RankedList({super.key, required this.entries, required this.firstRank});

  final List<PodiumEntry> entries;
  final int firstRank;

  @override
  Widget build(BuildContext context) {
    final showRecord = entries.any((e) => e.record != null);
    return PodiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                const SizedBox(width: 32, child: Text('#', style: PodiumText.overline)),
                const Expanded(child: Text('TEAM', style: PodiumText.overline)),
                if (showRecord) const SizedBox(width: 52, child: Text('W-L', textAlign: TextAlign.right, style: PodiumText.overline)),
                const SizedBox(width: 72, child: Text('PTS', textAlign: TextAlign.right, style: PodiumText.overline)),
              ],
            ),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            const Divider(),
            _RankRow(rank: firstRank + i, entry: entries[i], showRecord: showRecord),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry, required this.showRecord});

  final int rank;
  final PodiumEntry entry;
  final bool showRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: entry.isMe ? PodiumColors.goldTint : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: PodiumText.score(size: 18, color: entry.isMe ? PodiumColors.gold : PodiumColors.muted),
            ),
          ),
          InitialsAvatar(
            name: entry.name,
            size: 34,
            ring: entry.isMe ? PodiumColors.gold : PodiumColors.line,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '${entry.name} (you)' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (entry.detail != null) Text(entry.detail!, style: PodiumText.caption),
              ],
            ),
          ),
          if (showRecord)
            SizedBox(
              width: 52,
              child: Text(
                entry.record ?? '',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: PodiumColors.silver),
              ),
            ),
          SizedBox(
            width: 72,
            child: Text(
              formatPoints(entry.points),
              textAlign: TextAlign.right,
              style: PodiumText.score(size: 19, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
