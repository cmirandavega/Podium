import 'package:flutter/material.dart';

import '../../models/trade_analysis.dart';
import '../../theme.dart';

/// Which side of the trade the person viewing the analysis is on.
enum TradeSide { proposer, receiver, neither }

/// A plain-language verdict for one side of a trade.
typedef TradeVerdict = ({String headline, String detail, int tone}); // tone: 1 good, 0 even, -1 bad

/// Shows an AI Trade and Team Analyzer result (Use Case 4), starting with
/// what the trade means for the person looking at it.
class AnalysisCard extends StatelessWidget {
  const AnalysisCard({
    super.key,
    required this.analysis,
    this.side = TradeSide.neither,
    this.proposerName = 'Proposer',
    this.receiverName = 'Receiver',
  });

  final TradeAnalysis analysis;
  final TradeSide side;
  final String proposerName;
  final String receiverName;

  /// Verdict from a side's change in projected weekly starter points.
  static TradeVerdict verdictFor(double delta) {
    final amount = delta.abs().toStringAsFixed(1);
    if (delta >= 8) {
      return (headline: 'This trade greatly benefits you', detail: "You'd gain about $amount projected points per week.", tone: 1);
    }
    if (delta >= 3) {
      return (headline: 'This trade helps you', detail: "You'd gain about $amount projected points per week.", tone: 1);
    }
    if (delta > -3) {
      return (headline: 'This trade is about even for you', detail: 'Your projected points per week barely change.', tone: 0);
    }
    if (delta > -8) {
      return (headline: 'This trade hurts you', detail: "You'd lose about $amount projected points per week.", tone: -1);
    }
    return (headline: 'This trade greatly hurts you', detail: "You'd lose about $amount projected points per week.", tone: -1);
  }

  /// Words for the 1-10 fairness rating.
  static String fairnessLabel(int rating) {
    if (rating >= 9) return 'Very fair';
    if (rating >= 7) return 'Fair';
    if (rating >= 5) return 'Somewhat uneven';
    if (rating >= 3) return 'Uneven';
    return 'Very lopsided';
  }

  static Color _toneColor(int tone) => switch (tone) {
        1 => PodiumColors.gold,
        -1 => PodiumColors.danger,
        _ => PodiumColors.silver,
      };

  String _signed(double v) => v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);

  /// Headline for someone not in the trade: who comes out ahead.
  TradeVerdict _neutralVerdict() {
    final gap = analysis.projectedDeltaProposer - analysis.projectedDeltaReceiver;
    if (gap.abs() < 3) {
      return (headline: 'An even trade', detail: 'Both teams change by about the same amount.', tone: 0);
    }
    final winner = gap > 0 ? proposerName : receiverName;
    return (headline: 'Favors $winner', detail: '$winner comes out ahead in projected points per week.', tone: 0);
  }

  Widget _pointsRow(String name, double delta) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text(
            '${_signed(delta)} pts/week',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: delta >= 3 ? PodiumColors.gold : (delta <= -3 ? PodiumColors.danger : PodiumColors.silver),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTrade = analysis.analysisType == 'trade';
    final verdict = switch (side) {
      TradeSide.proposer => verdictFor(analysis.projectedDeltaProposer),
      TradeSide.receiver => verdictFor(analysis.projectedDeltaReceiver),
      TradeSide.neither => _neutralVerdict(),
    };
    final color = _toneColor(verdict.tone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodiumColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTrade ? color : PodiumColors.gold),
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
            const SizedBox(height: 14),
            Text(verdict.headline, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(verdict.detail, style: const TextStyle(color: PodiumColors.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Fairness', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${fairnessLabel(analysis.fairnessRating)} (${analysis.fairnessRating}/10)',
                  style: const TextStyle(color: PodiumColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: analysis.fairnessRating / 10,
                minHeight: 8,
                backgroundColor: PodiumColors.line,
                color: analysis.fairnessRating >= 7
                    ? PodiumColors.gold
                    : (analysis.fairnessRating >= 4 ? PodiumColors.bronze : PodiumColors.danger),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Projected starter points', style: TextStyle(fontWeight: FontWeight.w600)),
            _pointsRow(side == TradeSide.proposer ? 'You' : proposerName, analysis.projectedDeltaProposer),
            _pointsRow(side == TradeSide.receiver ? 'You' : receiverName, analysis.projectedDeltaReceiver),
          ],
          if (analysis.positionalImpact.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Positional impact', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(analysis.positionalImpact),
          ],
          const SizedBox(height: 14),
          const Text('Why', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
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
