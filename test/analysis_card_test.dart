import 'package:flutter_test/flutter_test.dart';
import 'package:podium/screens/trades/analysis_card.dart';

void main() {
  test('verdict reads the change from the viewer\'s side', () {
    expect(AnalysisCard.verdictFor(19.7).headline, 'This trade greatly benefits you');
    expect(AnalysisCard.verdictFor(4).headline, 'This trade helps you');
    expect(AnalysisCard.verdictFor(1.2).headline, 'This trade is about even for you');
    expect(AnalysisCard.verdictFor(-5).headline, 'This trade hurts you');
    final bad = AnalysisCard.verdictFor(-17.3);
    expect(bad.headline, 'This trade greatly hurts you');
    expect(bad.detail, "You'd lose about 17.3 projected points per week.");
    expect(bad.tone, -1);
  });

  test('fairness ratings get words', () {
    expect(AnalysisCard.fairnessLabel(10), 'Very fair');
    expect(AnalysisCard.fairnessLabel(7), 'Fair');
    expect(AnalysisCard.fairnessLabel(5), 'Somewhat uneven');
    expect(AnalysisCard.fairnessLabel(3), 'Uneven');
    expect(AnalysisCard.fairnessLabel(2), 'Very lopsided');
  });
}
