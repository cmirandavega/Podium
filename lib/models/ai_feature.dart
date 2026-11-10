/// The two AI features in Podium. Each has its own daily request limit,
/// tracked in the aiUsage collection (Use Cases 4 and 12).
///
/// If you change a limit here, change it in firestore.rules too: the rules
/// enforce the same numbers so the limit can't be bypassed from the client.
enum AiFeature {
  tradeAnalyzer('trade_analyzer', 'AI Trade Analyzer', 10),
  assistantCoach('assistant_coach', 'AI Assistant Coach', 30);

  const AiFeature(this.key, this.label, this.dailyLimit);

  /// Value stored in aiUsage.feature.
  final String key;

  /// Name shown to users in messages.
  final String label;

  /// Requests allowed per user per UTC day.
  final int dailyLimit;
}
