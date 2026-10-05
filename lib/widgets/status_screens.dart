import 'package:flutter/material.dart';

import '../theme.dart';
import 'podium_mark.dart';

/// Full-screen loading state, optionally with a way out.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message, this.onSignOut});

  final String? message;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PodiumMark(),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: const TextStyle(color: PodiumColors.muted)),
            ],
            if (onSignOut != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onSignOut, child: const Text('Log out')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen message with one action, used for suspended accounts and load errors.
class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: PodiumMark()),
                  const SizedBox(height: 24),
                  Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(body, style: text.bodyLarge?.copyWith(color: PodiumColors.muted)),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
