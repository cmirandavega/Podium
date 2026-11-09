import '../../models/ai_feature.dart';

/// The user has used all of today's requests for this feature.
class AiLimitReachedException implements Exception {
  AiLimitReachedException({required this.feature, required this.resetsAt});

  final AiFeature feature;

  /// When the limit resets (next UTC midnight), in local time.
  final DateTime resetsAt;

  @override
  String toString() {
    final hour = resetsAt.hour % 12 == 0 ? 12 : resetsAt.hour % 12;
    final minute = resetsAt.minute.toString().padLeft(2, '0');
    final suffix = resetsAt.hour < 12 ? 'AM' : 'PM';
    return "You've reached today's limit of ${feature.dailyLimit} "
        '${feature.label} requests. It resets at $hour:$minute $suffix.';
  }
}

/// The AI service didn't respond in time or returned an error.
/// Callers should keep the user's input and offer a retry.
class AiUnavailableException implements Exception {
  AiUnavailableException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// The AI service answered, but the answer was empty or not in the
/// expected format (for example, JSON missing required fields).
class AiBadResponseException implements Exception {
  AiBadResponseException(this.message);

  final String message;

  @override
  String toString() => message;
}
