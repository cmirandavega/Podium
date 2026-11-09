import 'package:flutter/material.dart';

import '../models/sport.dart';
import '../theme.dart';

/// League format plus sport selection (Use Case 2). Used when creating a
/// league and when the commissioner edits its sports.
class SportPicker extends StatelessWidget {
  const SportPicker({
    super.key,
    required this.sports,
    required this.format,
    required this.selected,
    required this.onFormatChanged,
    required this.onSelectionChanged,
    this.errorText,
    this.enabled = true,
  });

  final List<Sport> sports;
  final String format;
  final List<String> selected;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<List<String>> onSelectionChanged;
  final String? errorText;
  final bool enabled;

  void _toggle(String sport) {
    if (format == 'single-sport') {
      onSelectionChanged([sport]);
      return;
    }
    final next = [...selected];
    next.contains(sport) ? next.remove(sport) : next.add(sport);
    onSelectionChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Format', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'single-sport', label: Text('Single-sport')),
            ButtonSegment(value: 'multi-sport', label: Text('Multi-sport')),
          ],
          selected: {format},
          onSelectionChanged: enabled
              ? (value) {
                  final next = value.first;
                  onFormatChanged(next);
                  if (next == 'single-sport' && selected.length > 1) {
                    onSelectionChanged([selected.first]);
                  }
                }
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          format == 'single-sport' ? 'Sport' : 'Sports (pick two or more)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sport in sports)
              FilterChip(
                label: Text(sport.isActive ? sport.name : '${sport.name} (unavailable)'),
                selected: selected.contains(sport.name),
                onSelected: enabled && sport.isActive ? (_) => _toggle(sport.name) : null,
                selectedColor: PodiumColors.gold.withValues(alpha: 0.25),
                checkmarkColor: PodiumColors.gold,
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(errorText!, style: const TextStyle(color: PodiumColors.danger)),
        ],
        const SizedBox(height: 8),
        const Text(
          'The sports you choose decide which players can be drafted. '
          'Player data is currently loaded for NFL.',
          style: TextStyle(color: PodiumColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}
