import 'package:flutter/material.dart';

import '../theme.dart';
import 'podium_mark.dart';

/// Shared layout for the login, register, and forgot password screens:
/// the Podium brand up top, the form in a card, and a faint podium
/// silhouette rising from the bottom of the screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = false,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  /// Shown under the form card, e.g. "New to Podium? Create an account".
  final Widget? footer;

  static const _sports = ['NFL', 'NBA', 'MLB', 'SOCCER'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // The full brand block only on the first screen; pushed screens get a
    // compact header so the form stays above the keyboard.
    final hero = !showBack;

    return Scaffold(
      appBar: showBack ? AppBar(backgroundColor: Colors.transparent) : null,
      extendBodyBehindAppBar: showBack,
      body: Stack(
        children: [
          const Positioned(left: 0, right: 0, bottom: 0, child: _PodiumSilhouette()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, hero ? 48 : 64, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: PodiumMark(scale: hero ? 1.4 : 0.9)),
                      const SizedBox(height: 18),
                      if (hero) ...[
                        Text(
                          'PODIUM',
                          textAlign: TextAlign.center,
                          style: PodiumText.wordmark(size: 44),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in _sports)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(PodiumRadii.pill),
                                  border: Border.all(color: PodiumColors.line),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                    color: PodiumColors.muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: (hero ? text.titleLarge : text.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: PodiumColors.silver),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PodiumColors.field.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: PodiumColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 18),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three faint podium steps behind the form.
class _PodiumSilhouette extends StatelessWidget {
  const _PodiumSilhouette();

  Widget _step(double height) => Container(
        width: 110,
        height: height,
        decoration: BoxDecoration(
          color: PodiumColors.field.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          // Uniform border: Flutter only allows a radius with uniform sides.
          // The bottom edge sits off the bottom of the screen anyway.
          border: Border.all(color: PodiumColors.line.withValues(alpha: 0.55)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _step(150),
            const SizedBox(width: 6),
            _step(220),
            const SizedBox(width: 6),
            _step(110),
          ],
        ),
      ),
    );
  }
}
