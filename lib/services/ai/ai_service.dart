import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../models/ai_feature.dart';
import '../../models/ai_message.dart';
import 'ai_exceptions.dart';
import 'ai_usage_service.dart';

/// What to do after a failed Gemini request.
enum AiFailure {
  /// Temporary (overloaded, rate limited, server error): wait, then retry.
  transient,

  /// The model didn't answer in time or isn't available: try the next model.
  switchModel,

  /// Won't fix itself (App Check, permissions, bad request): stop now.
  fatal,
}

/// Calls Gemini through Firebase AI Logic (Gemini Developer API).
///
/// The Gemini API key lives in the Firebase project, not in the app, which
/// keeps AI credentials off the client as Requirement 12 asks. Every call
/// checks the user's daily limit first and only counts successful responses.
///
/// Requests retry with exponential backoff on temporary errors and fall back
/// to other models when one is slow or unavailable, within a total time limit
/// so the user is never left waiting for minutes.
///
/// Feature code (Coach, Trade Analyzer) builds the prompt with [AiPrompts]
/// and calls [chat] or [generateJson]. It never talks to Gemini directly.
class AiService {
  AiService({AiUsageService? usage, Random? random})
      : _usage = usage ?? AiUsageService(),
        _random = random ?? Random();

  final AiUsageService _usage;
  final Random _random;

  /// Tried in order. Flash-Lite answers fast and is reliable on the free
  /// tier; the others are fallbacks with separate capacity. Check the
  /// Firebase console (AI Logic) for models available to the project.
  static const models = ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite', 'gemini-3.6-flash'];

  /// Each attempt may take this long before moving on.
  static const attemptTimeout = Duration(seconds: 20);

  /// No retry starts after this much total time.
  static const totalBudget = Duration(seconds: 45);

  static const maxAttempts = 5;

  /// Exponential backoff with full jitter: a random wait between 0 and
  /// 1 s, 2 s, 4 s... (capped at 8 s), so many clients retrying at once
  /// spread out instead of hitting the server together.
  static Duration backoff(int retry, Random random) {
    final capMs = min(8000, 1000 * pow(2, retry).toInt());
    return Duration(milliseconds: random.nextInt(capMs + 1));
  }

  /// Sorts an error into retry, switch model, or stop.
  static AiFailure classify(Object error) {
    if (error is TimeoutException) return AiFailure.switchModel;
    final text = error.toString().toLowerCase();
    const modelProblems = ['no longer available', 'not found', 'is not supported', 'deprecated'];
    if (modelProblems.any(text.contains)) return AiFailure.switchModel;
    const temporary = [
      '429', '500', '502', '503', '504',
      'internal', 'unavailable', 'overloaded', 'high demand',
      'resource_exhausted', 'rate limit', 'quota', 'try again',
      'socket', 'network', 'connection', 'timed out',
    ];
    if (temporary.any(text.contains)) return AiFailure.transient;
    return AiFailure.fatal;
  }

  GenerativeModel _model(String name, String systemInstruction, [GenerationConfig? config]) {
    return FirebaseAI.googleAI().generativeModel(
      model: name,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: config,
    );
  }

  /// One chat turn for the AI Assistant Coach.
  ///
  /// [history] is the saved conversation (oldest first), not including
  /// [message]. Throws [AiLimitReachedException], [AiUnavailableException],
  /// or [AiBadResponseException]. On failure the caller should keep the
  /// user's message on screen and offer a retry.
  Future<String> chat({
    required AiFeature feature,
    required String systemInstruction,
    required List<AiMessage> history,
    required String message,
  }) async {
    await _usage.ensureAvailable(feature);
    final past = history
        .map((m) => m.isUser ? Content.text(m.content) : Content.model([TextPart(m.content)]))
        .toList();

    final response = await _send((modelName) {
      final session = _model(modelName, systemInstruction).startChat(history: past);
      return session.sendMessage(Content.text(message));
    });
    final text = response.text?.trim() ?? '';
    if (text.isEmpty) {
      throw AiBadResponseException('The AI Coach returned an empty answer.');
    }

    await _recordQuietly(feature);
    return text;
  }

  /// A structured JSON answer, used by the Trade Analyzer.
  ///
  /// Temporary errors are retried inside [_send]. If the answer is not valid
  /// JSON or is missing any of [requiredKeys], asks once more (Use Case 4
  /// exception path). If that fails too it throws, and the caller falls back
  /// to its statistics-only result.
  Future<Map<String, dynamic>> generateJson({
    required AiFeature feature,
    required String systemInstruction,
    required String prompt,
    required Schema schema,
    required List<String> requiredKeys,
  }) async {
    await _usage.ensureAvailable(feature);
    final config = GenerationConfig(responseMimeType: 'application/json', responseSchema: schema);

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _send(
          (modelName) => _model(modelName, systemInstruction, config).generateContent([Content.text(prompt)]),
        );
        final decoded = jsonDecode(response.text ?? '');
        if (decoded is Map<String, dynamic> && requiredKeys.every(decoded.containsKey)) {
          await _recordQuietly(feature);
          return decoded;
        }
        lastError = AiBadResponseException('The AI response was missing required fields.');
      } on FormatException catch (error) {
        lastError = AiBadResponseException('The AI response was not valid JSON: $error');
      } on AiUnavailableException catch (error) {
        // _send already retried and fell back; asking again won't help.
        lastError = error;
        break;
      }
    }
    throw lastError ?? AiUnavailableException('The AI service is unavailable.');
  }

  /// Requests left today for [feature], for the UI.
  Stream<int> watchRemaining(AiFeature feature) => _usage.watchRemaining(feature);

  /// Runs [request] with the first model, retrying temporary errors with
  /// backoff and moving down [models] when a model is slow or unavailable.
  Future<GenerateContentResponse> _send(
    Future<GenerateContentResponse> Function(String modelName) request,
  ) async {
    final started = DateTime.now();
    var modelIndex = 0;
    var retries = 0;
    Object? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final model = models[modelIndex];
      try {
        return await request(model).timeout(attemptTimeout);
      } on Exception catch (error) {
        lastError = error;
        final kind = classify(error);
        debugPrint('Gemini attempt ${attempt + 1} with $model failed ($kind): $error');
        if (kind == AiFailure.fatal) break;

        if (kind == AiFailure.switchModel) {
          if (modelIndex == models.length - 1) break; // no models left
          modelIndex++;
        } else {
          // After two temporary failures on one model, try the next one.
          retries++;
          if (retries % 2 == 0 && modelIndex < models.length - 1) modelIndex++;
          final wait = backoff(retries - 1, _random);
          if (DateTime.now().difference(started) + wait >= totalBudget) break;
          await Future<void>.delayed(wait);
        }
        if (DateTime.now().difference(started) >= totalBudget) break;
      }
    }

    if (lastError is TimeoutException) {
      throw AiUnavailableException('The AI service took too long to respond.', lastError);
    }
    throw AiUnavailableException('The AI service is unavailable right now.', lastError);
  }

  /// The answer already succeeded, so a failed usage write (for example,
  /// two requests racing at the limit) shouldn't hide it from the user.
  Future<void> _recordQuietly(AiFeature feature) async {
    try {
      await _usage.record(feature);
    } on Exception {
      // Rules still cap the count, so the next ensureAvailable call blocks.
    }
  }
}
