import 'package:flutter/material.dart';

import '../../models/trade_analysis.dart';
import '../../theme.dart';

/// Shows an AI Trade and Team Analyzer result (Use Case 4).
class AnalysisCard extends StatelessWidget {
  const AnalysisCard({
    super.key,
    required this.analysis,
    this.proposerName = 'Proposer',
    this.receiverName = 'Receiver',
  });

  final TradeAnalysis analysis;
  final String proposerName;
  final String receiverName;

  String _signed(double v) => v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final isTrade = analysis.analysisType == 'trade';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodiumColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PodiumColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: PodiumColors.gold),
              const SizedBox(width: 8),
              Text(
                isTrade ? 'AI Trade Analysis' : 'AI Roster Report',
                style: const TextStyle(fontWeight: FontWeight.w700, color: PodiumColors.gold),
              ),
              const Spacer(),
              if (analysis.fromCache)
                const Text('Saved', style: TextStyle(color: PodiumColors.muted, fontSize: 12)),
            ],
          ),
          if (!analysis.aiAvailable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PodiumColors.dangerTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('The AI summary is temporarily unavailable. Showing the statistics-only result.'),
            ),
          ],
          if (isTrade) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${analysis.fairnessRating}/10',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fairness · ${analysis.verdict}',
                    style: const TextStyle(color: PodiumColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$proposerName: ${_signed(analysis.projectedDeltaProposer)} projected starter points per week'),
            Text('$receiverName: ${_signed(analysis.projectedDeltaReceiver)} projected starter points per week'),
          ],
          if (analysis.positionalImpact.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Positional impact', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(analysis.positionalImpact),
          ],
          const SizedBox(height: 12),
          Text(analysis.explanation),
          const SizedBox(height: 10),
          Text(
            'Based on stats through week ${analysis.throughWeek}.',
            style: const TextStyle(color: PodiumColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
