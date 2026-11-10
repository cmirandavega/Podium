import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/league_feature_service.dart';

/// Create a league or change sports as commissioner.
class LeagueSportsScreen extends StatefulWidget {
  const LeagueSportsScreen({super.key, this.leagueId});
  final String? leagueId;
  @override State<LeagueSportsScreen> createState() => _LeagueSportsScreenState();
}
class _LeagueSportsScreenState extends State<LeagueSportsScreen> {
  final name = TextEditingController();
  final season = TextEditingController(text: '2026');
  final selected = <String>{};
  int maxTeams = 10, rosterSize = 12;
  bool busy = false, loaded = false;
  final api = LeagueFeatureService.instance;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (widget.leagueId == null) return;
    try {
      final doc = await api.db.collection('leagues').doc(widget.leagueId).get();
      final d = doc.data();
      if (d == null || !mounted) return;
      setState(() {
        name.text = '${d['name'] ?? ''}'; season.text = '${d['season'] ?? ''}';
        selected.addAll((d['sports'] as List<dynamic>? ?? []).map((e) => '$e'));
        maxTeams = (d['maxTeams'] as num?)?.toInt() ?? 10;
        rosterSize = (d['rosterSize'] as num?)?.toInt() ?? 12;
        loaded = true;
      });
    } catch (e) { if (mounted) _error('$e'); }
  }
  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  Future<void> _save() async {
    if (selected.isEmpty) { _error('Select at least one available sport.'); return; }
    if (widget.leagueId == null && name.text.trim().isEmpty) { _error('Enter a league name.'); return; }
    setState(() => busy = true);
    try {
      if (widget.leagueId == null) {
        await api.createLeague(name: name.text.trim(), sports: selected.toList(),
          season: season.text.trim(), maxTeams: maxTeams, rosterSize: rosterSize);
      } else {
        await api.updateSports(widget.leagueId!, selected.toList());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) _error('$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { name.dispose(); season.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.leagueId == null ? 'Create league' : 'Edit league sports')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: api.sports(), builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Unable to load sports: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final sports = snap.data!.docs.where((d) => d.data()['isActive'] == true).toList();
        return ListView(padding: const EdgeInsets.all(20), children: [
          if (widget.leagueId == null) ...[
            TextField(controller: name, decoration: const InputDecoration(labelText: 'League name')),
            const SizedBox(height: 12),
            TextField(controller: season, decoration: const InputDecoration(labelText: 'Season')),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('Maximum teams')),
              DropdownButton<int>(value: maxTeams, items: [2,4,6,8,10,12,14,16,20]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) => setState(() => maxTeams = v!)),
            ]),
            Row(children: [
              const Expanded(child: Text('Roster size')),
              DropdownButton<int>(value: rosterSize, items: [5,8,10,12,15,20,25]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) => setState(() => rosterSize = v!)),
            ]),
          ],
          const SizedBox(height: 20), const Text('Choose one or more active sports'),
          if (sports.isEmpty) const Text('No active sports in Firestore. Ask an admin to seed sports.'),
          ...sports.map((d) => CheckboxListTile(
            title: Text(d.id.toUpperCase()),
            subtitle: Text('${d.data()['apiCode'] ?? ''}'),
            value: selected.contains(d.id),
            onChanged: busy ? null : (v) => setState(() {
              if (v == true) { selected.add(d.id); } else { selected.remove(d.id); }
            }),
          )),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy || sports.isEmpty || (widget.leagueId != null && !loaded) ? null : _save,
            child: Text(busy ? 'Saving...' : 'Save sports')),
        ]);
      },
    ),
  );
}
