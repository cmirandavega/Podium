import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/league_service.dart';
import 'league_home_screen.dart';

/// Join a league with the invite code the commissioner shared.
class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _teamName = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _teamName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final leagueId = await LeagueService().joinLeague(
        inviteCode: _code.text,
        teamName: _teamName.text,
        username: widget.user.username,
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
        SnackBar(content: Text('Could not join league: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join League')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _code,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Invite code'),
              validator: (v) => v == null || v.trim().length != 6
                  ? 'Invite codes are 6 characters.'
                  : null,
            ),
            TextFormField(
              controller: _teamName,
              enabled: !_saving,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Your team name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a team name.' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join League'),
            ),
          ],
        ),
      ),
    );
  }
}
