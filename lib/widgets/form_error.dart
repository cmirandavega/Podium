import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows a form-level error (wrong password, taken username, no connection).
class FormError extends StatelessWidget {
  const FormError({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PodiumColors.dangerTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PodiumColors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: PodiumColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message!, style: const TextStyle(color: PodiumColors.chalk))),
        ],
      ),
    );
  }
}
