import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/sport.dart';
import '../../services/league_service.dart';
import '../../widgets/sport_picker.dart';

/// Commissioner changes the league's sports before the season starts.
class EditSportsScreen extends StatefulWidget {
  const EditSportsScreen({super.key, required this.league});

  final League league;

  @override
  State<EditSportsScreen> createState() => _EditSportsScreenState();
}

class _EditSportsScreenState extends State<EditSportsScreen> {
  final _leagues = LeagueService();
  late final Stream<List<Sport>> _sportsStream = _leagues.watchSports();
  late String _format = widget.league.format;
  late List<String> _sports = [...widget.league.sports];
  String? _error;
  bool _saving = false;

  Future<void> _save(List<Sport> available) async {
    final error = LeagueService.validateSports(
      format: _format,
      selected: _sports,
      available: available,
    );
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _saving = true);
    try {
      await _leagues.updateSports(
        league: widget.league,
        format: _format,
        sports: _sports,
        availableSports: available,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('League sports updated.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update sports: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('League Sports')),
      body: StreamBuilder<List<Sport>>(
        stream: _sportsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final available = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SportPicker(
                sports: available,
                format: _format,
                selected: _sports,
                errorText: _error,
                enabled: !_saving,
                onFormatChanged: (f) => setState(() => _format = f),
                onSelectionChanged: (s) => setState(() {
                  _sports = s;
                  _error = null;
                }),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _save(available),
                child: const Text('Save Sports'),
              ),
            ],
          );
        },
      ),
    );
  }
}
