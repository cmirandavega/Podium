import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/status_screens.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import '../reports/report_history_screen.dart';

/// Session handling: decides which screen to show based on the
/// Firebase Auth session and the user's Firestore profile.
///
/// Signed out          -> LoginScreen
/// Profile loading     -> LoadingScreen
/// Suspended account   -> StatusScreen
/// Active account      -> HomeScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final Stream<User?> _authStream = AuthService().authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return _ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.uid});

  final String uid;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<AppUser?> _userStream = UserService().watchUser(widget.uid);

  void _signOut() => AuthService().signOut();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StatusScreen(
            title: 'Your profile did not load.',
            body: 'Check your connection, then log in again.',
            actionLabel: 'Log out',
            onAction: _signOut,
          );
        }

        final appUser = snapshot.data;
        if (appUser == null) {
          // Right after registration the profile document may not exist yet.
          return LoadingScreen(
            message: 'Setting up your account',
            onSignOut: _signOut,
          );
        }
        if (appUser.isSuspended) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Suspended')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block, size: 56, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Account Standing: Suspended',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'An administrator suspended this account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('View Moderation History'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReportHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _signOut,
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return HomeScreen(user: appUser);
      },
    );
  }
}
