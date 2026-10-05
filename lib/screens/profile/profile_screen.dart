import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../utils/validators.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _displayName = TextEditingController(text: widget.user.displayName);
  bool _saving = false;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await UserService().updateDisplayName(widget.user.uid, _displayName.text);
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile not saved. Check your connection and try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logOut() async {
    final auth = AuthService();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.signOut();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Just now';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _displayName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: Validators.displayName,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 32),
            _InfoRow(label: 'Username', value: '@${user.username}'),
            _InfoRow(label: 'Email', value: user.email),
            _InfoRow(label: 'Account type', value: user.isAdmin ? 'Admin' : 'Player'),
            _InfoRow(label: 'Member since', value: _formatDate(user.createdAt)),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _logOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PodiumColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: PodiumColors.muted))),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
