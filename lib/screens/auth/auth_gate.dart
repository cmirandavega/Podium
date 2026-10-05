import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/status_screens.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

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
          return LoadingScreen(message: 'Setting up your account', onSignOut: _signOut);
        }

        if (appUser.isSuspended) {
          return StatusScreen(
            title: 'This account is suspended.',
            body: 'An administrator suspended this account. Contact your league '
                'commissioner if you think this is a mistake.',
            actionLabel: 'Back to log in',
            onAction: _signOut,
          );
        }

        return HomeScreen(user: appUser);
      },
    );
  }
}
