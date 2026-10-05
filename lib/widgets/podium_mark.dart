import 'package:flutter/material.dart';

import '../theme.dart';

/// The Podium logo: silver, gold, and bronze steps.
class PodiumMark extends StatelessWidget {
  const PodiumMark({super.key, this.scale = 1});

  final double scale;

  Widget _step(double height, Color color) {
    return Container(
      width: 16 * scale,
      height: height * scale,
      margin: EdgeInsets.symmetric(horizontal: 1.5 * scale),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.vertical(top: Radius.circular(3 * scale)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Podium',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _step(28, PodiumColors.silver),
          _step(42, PodiumColors.gold),
          _step(20, PodiumColors.bronze),
        ],
      ),
    );
  }
}
