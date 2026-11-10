import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/league_feature_service.dart';

/// UI for creating a roster and saving each week's starter choices.
class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({super.key, required this.leagueId});
  final String leagueId;
  @override State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}
class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  final api = LeagueFeatureService.instance;
  String? periodId;
  String? activePeriod;
  bool working = false;
  Future<void> action(String op, {String? playerId, String? replacementId, bool? isStarter}) async {
    setState(() => working = true);
    try {
      await api.rosterAction(widget.leagueId, op, playerId: playerId,
          replacementId: replacementId, periodId: periodId ?? activePeriod, isStarter: isStarter);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roster saved.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => working = false); }
  }
  @override Widget build(BuildContext context) {
    final teamId = '${widget.leagueId}_${api.uid}';
    return Scaffold(appBar: AppBar(title: const Text('Team Builder')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: api.league(widget.leagueId), builder: (context, leagueSnap) {
          final league = leagueSnap.data?.data();
          if (league == null) return const Center(child: CircularProgressIndicator());
          final allowedSports = (league['sports'] as List<dynamic>? ?? []).map((e) => '$e').toSet();
          final rosterMax = (league['rosterSize'] as num?)?.toInt() ?? 12;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: api.periods(), builder: (context, periodSnap) {
              final periods = periodSnap.data?.docs.toList() ?? [];
              periods.sort((a,b) => ((b.data()['startDate'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
                .compareTo((a.data()['startDate'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
              final chosen = periods.any((p) => p.id == periodId) ? periodId : (periods.isEmpty ? null : periods.first.id);
              final chosenDoc = periods.where((p) => p.id == chosen).firstOrNull;
              activePeriod = chosen;
              final lock = (chosenDoc?.data()['lockTime'] as Timestamp?)?.toDate();
              final locked = lock != null && !DateTime.now().isBefore(lock);
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: api.roster(widget.leagueId, teamId), builder: (context, rosterSnap) {
                  if (rosterSnap.hasError) return Center(child: Text('${rosterSnap.error}'));
                  final slots = rosterSnap.data?.docs.toList() ?? [];
                  final rosterIds = slots.map((d) => '${d.data()['playerId']}').toSet();
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: api.db.collection('lineups').doc('${teamId}_$chosen').snapshots(),
                    builder: (context, lineupSnap) {
                    final lineData = lineupSnap.data?.data();
                    final starterIds = (lineData?['starters'] as List<dynamic>? ?? []).toSet();
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: api.players(), builder: (context, playersSnap) {
                      if (playersSnap.hasError) return Center(child: Text('${playersSnap.error}'));
                      if (!playersSnap.hasData) return const Center(child: CircularProgressIndicator());
                      final playerMap = {for(final p in playersSnap.data!.docs) p.id: p.data()};
                      final options = playersSnap.data!.docs.where((p) =>
                        allowedSports.contains(p.data()['sport']) && !rosterIds.contains(p.id)).toList();
                      options.sort((a,b) => '${a.data()['fullName']}'.compareTo('${b.data()['fullName']}'));
                      return ListView(padding: const EdgeInsets.all(16), children: [
                        Text('Roster: ${slots.length}/$rosterMax'), const SizedBox(height: 8),
                        if (periods.isEmpty) const Text('No scoring periods loaded. Import periods before choosing starters.'),
                        if (periods.isNotEmpty) DropdownButtonFormField<String>(
                          initialValue: chosen,
                          decoration: const InputDecoration(labelText: 'Scoring period'),
                          items: periods.map((p) => DropdownMenuItem(value:p.id,
                            child: Text('${p.data()['season'] ?? ''} Week ${p.data()['week'] ?? p.id}'))).toList(),
                          onChanged: (value) => setState(() => periodId=value)),
                        const SizedBox(height: 8),
                        if (locked) const Text('Lineup locked for this scoring period.'),
                        ...slots.map((slot) {
                          final pId = '${slot.data()['playerId']}';
                          final p = playerMap[pId] ?? {};
                          final starter = starterIds.contains(pId);
                          return Card(child: ListTile(
                            title: Text('${p['fullName'] ?? pId}'),
                            subtitle: Text('${p['sport'] ?? ''} • ${p['position'] ?? ''}'),
                            leading: IconButton(tooltip: starter ? 'Bench player' : 'Start player',
                              icon: Icon(starter ? Icons.star : Icons.star_border),
                              onPressed: working || locked || chosen == null ? null : () {
                                setState(() => periodId=chosen);
                                action('starter', playerId:pId, isStarter: !starter);
                              }),
                            trailing: PopupMenuButton<String>(
                              enabled: !working && !locked,
                              onSelected: (choice) async {
                                if (choice=='remove') await action('remove', playerId:pId);
                                if (choice=='replace') {
                                  final replacement = await showDialog<String>(context:context, builder:(context) =>
                                    SimpleDialog(title:const Text('Replace with'), children: options.take(100)
                                      .map((candidate) => SimpleDialogOption(
                                        onPressed:()=>Navigator.pop(context,candidate.id),
                                        child:Text('${candidate.data()['fullName']} (${candidate.data()['sport']})'))).toList()));
                                  if (replacement != null) await action('replace',playerId:pId,replacementId:replacement);
                                }
                              }, itemBuilder: (_) => const [
                                PopupMenuItem(value:'replace',child:Text('Replace')),
                                PopupMenuItem(value:'remove',child:Text('Remove')),
                              ]),
                          ));
                        }),
                        const SizedBox(height: 12),
                        const Text('Available athletes',style:TextStyle(fontWeight:FontWeight.bold)),
                        ...options.take(100).map((p) => ListTile(
                          title:Text('${p.data()['fullName'] ?? p.id}'),
                          subtitle:Text('${p.data()['sport']} • ${p.data()['position'] ?? ''}'),
                          trailing:IconButton(icon:const Icon(Icons.add_circle_outline),
                            onPressed:working || locked || slots.length>=rosterMax ? null
                              :()=>action('add',playerId:p.id)),
                        )),
                        if (options.length>100) const Text('Showing first 100 athletes.'),
                      ]);
                    },
                  );
                    },
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
