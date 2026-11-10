import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/scoring_period.dart';
import '../../models/sport.dart';
import '../../services/league_service.dart';
import '../../services/scoring_service.dart';
import '../../theme.dart';
import '../../widgets/sport_picker.dart';
import 'league_home_screen.dart';

/// Use Case 2: create a league and choose its sports.
class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _teamName = TextEditingController();
  final _leagues = LeagueService();
  late final Stream<List<Sport>> _sportsStream = _leagues.watchSports();
  late final Stream<List<ScoringPeriod>> _periodsStream = ScoringService().watchPeriods();

  String _format = 'single-sport';
  List<String> _sports = ['NFL'];
  String? _sportError;
  String? _season;
  int _maxTeams = 4;
  int _rosterSize = 12;
  int _starterCount = 8;
  int _weeks = 3;
  int _playoffTeams = 2;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _teamName.dispose();
    super.dispose();
  }

  /// Season -> number of weeks with scoring data.
  Map<String, int> _seasons(List<ScoringPeriod> periods) {
    final weeks = <String, int>{};
    for (final p in periods) {
      if (p.season == null || p.week == null) continue;
      weeks[p.season!] = (weeks[p.season!] ?? 0) + 1;
    }
    return weeks;
  }

  Future<void> _submit(List<Sport> available, Map<String, int> seasons, int maxRegular) async {
    final sportError = LeagueService.validateSports(
      format: _format,
      selected: _sports,
      available: available,
    );
    setState(() => _sportError = sportError);
    if (!_formKey.currentState!.validate() || sportError != null) return;

    setState(() => _saving = true);
    try {
      final leagueId = await _leagues.createLeague(
        name: _name.text,
        teamName: _teamName.text,
        username: widget.user.username,
        format: _format,
        sports: _sports,
        availableSports: available,
        season: _season ?? seasons.keys.first,
        maxTeams: _maxTeams,
        rosterSize: _rosterSize,
        starterCount: _starterCount,
        regularSeasonWeeks: _weeks.clamp(1, maxRegular).toInt(),
        playoffTeams: _playoffTeams,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LeagueHomeScreen(leagueId: leagueId, user: widget.user),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create league: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numberField({
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
    String? helper,
  }) {
    final safeValue = options.contains(value) ? value : options.last;
    return DropdownButtonFormField<int>(
      // Rebuild when the options change so the shown value stays valid.
      key: ValueKey('$label-${options.length}'),
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label, helperText: helper),
      items: [for (final o in options) DropdownMenuItem(value: o, child: Text('$o'))],
      onChanged: _saving
          ? null
          : (v) {
              if (v != null) onChanged(v);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create League')),
      body: StreamBuilder<List<Sport>>(
        stream: _sportsStream,
        builder: (context, sportSnap) {
          return StreamBuilder<List<ScoringPeriod>>(
            stream: _periodsStream,
            builder: (context, periodSnap) {
              if (!sportSnap.hasData || !periodSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sports = sportSnap.data!;
              final seasons = _seasons(periodSnap.data!);
              if (seasons.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No season data is loaded yet. Run the sports ingestion script '
                      'to load at least one week of stats, then create a league.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final season = _season ?? seasons.keys.first;
              final weeksAvailable = seasons[season]!;
              // Leave room for playoff rounds after the regular season.
              final playoffRounds = _playoffTeams == 4 ? 2 : (_playoffTeams == 2 ? 1 : 0);
              final maxRegular = (weeksAvailable - playoffRounds).clamp(1, 17).toInt();

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: 'League name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a league name.' : null,
                    ),
                    TextFormField(
                      controller: _teamName,
                      enabled: !_saving,
                      maxLength: 30,
                      decoration: const InputDecoration(labelText: 'Your team name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a team name.' : null,
                    ),
                    const SizedBox(height: 8),
                    SportPicker(
                      sports: sports,
                      format: _format,
                      selected: _sports,
                      errorText: _sportError,
                      enabled: !_saving,
                      onFormatChanged: (f) => setState(() => _format = f),
                      onSelectionChanged: (s) => setState(() {
                        _sports = s;
                        _sportError = null;
                      }),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: season,
                      decoration: const InputDecoration(
                        labelText: 'Season',
                        helperText: 'Podium replays this season week by week.',
                      ),
                      items: [
                        for (final s in seasons.keys)
                          DropdownMenuItem(value: s, child: Text('$s (${seasons[s]} weeks of data)')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _season = v),
                    ),
                    const SizedBox(height: 16),
                    _numberField(
                      label: 'Number of teams',
                      value: _maxTeams,
                      options: const [2, 4, 6, 8, 10, 12],
                      onChanged: (v) => setState(() {
                        _maxTeams = v;
                        if (_playoffTeams > v) _playoffTeams = v >= 4 ? 4 : 2;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _numberField(
                      label: 'Roster size',
                      value: _rosterSize,
                      options: const [6, 8, 10, 12, 14, 16],
                      onChanged: (v) => setState(() {
                        _rosterSize = v;
                        if (_starterCount > v) _starterCount = v;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _numberField(
                      label: 'Starters per week',
                      value: _starterCount,
                      options: [for (var i = 3; i <= _rosterSize; i++) i],
                      onChanged: (v) => setState(() => _starterCount = v),
                      helper: 'Only starters score points in matchups.',
                    ),
                    const SizedBox(height: 16),
                    _numberField(
                      label: 'Playoff teams',
                      value: _playoffTeams,
                      options: [0, 2, if (_maxTeams >= 4) 4],
                      onChanged: (v) => setState(() => _playoffTeams = v),
                    ),
                    const SizedBox(height: 16),
                    _numberField(
                      label: 'Regular season weeks',
                      value: _weeks,
                      options: [for (var i = 1; i <= maxRegular; i++) i],
                      onChanged: (v) => setState(() => _weeks = v),
                      helper: 'Limited by the weeks of data loaded for $season.',
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _submit(sports, seasons, maxRegular),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create League'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "You'll get an invite code to share with the other players.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PodiumColors.muted),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
