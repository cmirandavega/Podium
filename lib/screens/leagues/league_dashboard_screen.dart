import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/league_feature_service.dart';
import 'league_sports_screen.dart';
import 'team_builder_screen.dart';
import 'league_chat_screen.dart';

class LeagueDashboardScreen extends StatelessWidget {
  const LeagueDashboardScreen({super.key, required this.leagueId});
  final String leagueId;
  @override Widget build(BuildContext context) {
    final api = LeagueFeatureService.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: api.league(leagueId), builder: (context, snap) {
        final d = snap.data?.data();
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text('${snap.error}')));
        if (d == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final commissioner = d['commissionerId'] == api.uid;
        return Scaffold(
          appBar: AppBar(title: Text('${d['name'] ?? 'League'}'), actions: [
            if (commissioner) IconButton(tooltip: 'Edit sports', icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LeagueSportsScreen(leagueId: leagueId)))),
          ]),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: api.db.collection('leagues').doc(leagueId).collection('members').doc(api.uid).snapshots(),
            builder: (context, member) {
              final joined = member.data?.exists == true;
              return ListView(padding: const EdgeInsets.all(20), children: [
                Text('Sports: ${(d['sports'] as List<dynamic>? ?? []).join(', ')}'),
                Text('Season: ${d['season'] ?? ''}'),
                Text('Roster size: ${d['rosterSize'] ?? 12}'),
                const SizedBox(height: 24),
                if (!joined) FilledButton.icon(onPressed: () async {
                  try { await api.joinLeague(leagueId); }
                  catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
                }, icon: const Icon(Icons.group_add), label: const Text('Join league')),
                if (joined) ...[
                  FilledButton.icon(icon: const Icon(Icons.groups), label: const Text('Team Builder'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TeamBuilderScreen(leagueId: leagueId)))),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(icon: const Icon(Icons.chat_bubble_outline), label: const Text('League Chat'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LeagueChatScreen(leagueId: leagueId)))),
                ],
              ]);
            },
          ),
        );
      },
    );
  }
}
