import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final Stream<List<LeaderboardEntry>> _stream = LeaderboardService().getLeaderboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<List<LeaderboardEntry>>(
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
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyCard(
                icon: Icons.emoji_events_outlined,
                title: 'No standings yet',
                message: 'Teams show up here once their first week is scored.',
              ),
            );
          }

          final rest = entries.length > 3 ? entries.sublist(3) : const <LeaderboardEntry>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _Podium(top: entries.take(3).toList()),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 22),
                PodiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Row(
                          children: [
                            SizedBox(width: 32, child: Text('#', style: PodiumText.overline)),
                            Expanded(child: Text('TEAM', style: PodiumText.overline)),
                            Text('PTS', style: PodiumText.overline),
                          ],
                        ),
                      ),
                      for (var i = 0; i < rest.length; i++) ...[
                        const Divider(),
                        _Row(rank: i + 4, entry: rest[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Top three on gold, silver, and bronze steps: 2nd left, 1st center, 3rd right.
class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<LeaderboardEntry> top;

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
              name: entry.teamName,
              size: avatar,
              ring: color,
              ringWidth: 3,
              background: PodiumColors.field,
              foreground: PodiumColors.chalk,
            ),
            const SizedBox(height: 8),
            Text(
              entry.teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
          '${i + 1}: ${top[i].teamName}, ${formatPoints(top[i].points)} points',
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

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('$rank', style: PodiumText.score(size: 18, color: PodiumColors.muted)),
          ),
          InitialsAvatar(name: entry.teamName, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('${entry.sport} · ${entry.season}', style: PodiumText.caption),
              ],
            ),
          ),
          Text(formatPoints(entry.points), style: PodiumText.score(size: 19, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
