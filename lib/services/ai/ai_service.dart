import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../models/ai_feature.dart';
import '../../models/ai_message.dart';
import 'ai_exceptions.dart';
import 'ai_usage_service.dart';

/// Calls Gemini through Firebase AI Logic (Gemini Developer API).
///
/// The Gemini API key lives in the Firebase project, not in the app, which
/// keeps AI credentials off the client as Requirement 12 asks. Every call
/// checks the user's daily limit first and only counts successful responses.
///
/// Feature code (Coach, Trade Analyzer) builds the prompt with [AiPrompts]
/// and calls [chat] or [generateJson]. It never talks to Gemini directly.
class AiService {
  AiService({AiUsageService? usage}) : _usage = usage ?? AiUsageService();

  final AiUsageService _usage;

  /// Check the Firebase console (AI Logic) for models available to the project.
  static const modelName = 'gemini-3.8-flash';
  static const timeout = Duration(seconds: 60);

  /// Newer Flash models think before answering by default, which can take
  /// longer than the timeout. Lineup and trade advice doesn't need deep
  /// reasoning, so both features use a low thinking level.
  static final _thinking = ThinkingConfig.withThinkingLevel(ThinkingLevel.low);

  GenerativeModel _model(String systemInstruction, [GenerationConfig? config]) {
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: config ?? GenerationConfig(thinkingConfig: _thinking),
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

    final session = _model(systemInstruction).startChat(
      history: history
          .map((m) => m.isUser
              ? Content.text(m.content)
              : Content.model([TextPart(m.content)]))
          .toList(),
    );

    final response = await _send(() => session.sendMessage(Content.text(message)));
    final text = response.text?.trim() ?? '';
    if (text.isEmpty) {
      throw AiBadResponseException('The AI Coach returned an empty answer.');
    }

    await _recordQuietly(feature);
    return text;
  }

  /// A structured JSON answer, used by the Trade Analyzer and for the Coach's
  /// lineup suggestions.
  ///
  /// Retries once if the model doesn't answer or the JSON is missing any of
  /// [requiredKeys] (Use Case 4 exception path). If both attempts fail it
  /// throws, and the caller falls back to its statistics-only result.
  Future<Map<String, dynamic>> generateJson({
    required AiFeature feature,
    required String systemInstruction,
    required String prompt,
    required Schema schema,
    required List<String> requiredKeys,
  }) async {
    await _usage.ensureAvailable(feature);

    final model = _model(
      systemInstruction,
      GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        thinkingConfig: _thinking,
      ),
    );

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _send(() => model.generateContent([Content.text(prompt)]));
        final decoded = jsonDecode(response.text ?? '');
        if (decoded is Map<String, dynamic> && requiredKeys.every(decoded.containsKey)) {
          await _recordQuietly(feature);
          return decoded;
        }
        lastError = AiBadResponseException('The AI response was missing required fields.');
      } on FormatException catch (error) {
        lastError = AiBadResponseException('The AI response was not valid JSON: $error');
      } on AiUnavailableException catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? AiUnavailableException('The AI service is unavailable.');
  }

  /// Requests left today for [feature], for the UI.
  Stream<int> watchRemaining(AiFeature feature) => _usage.watchRemaining(feature);

  Future<GenerateContentResponse> _send(
    Future<GenerateContentResponse> Function() request,
  ) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException catch (error) {
      throw AiUnavailableException('The AI service took too long to respond.', error);
    } on FirebaseAIException catch (error) {
      debugPrint('Gemini request failed: $error');
      throw AiUnavailableException('The AI service is unavailable right now.', error);
    } on Exception catch (error) {
      // Anything else (network, Firebase setup) is shown with its real message.
      debugPrint('Gemini request failed: $error');
      throw AiUnavailableException('The AI service is unavailable right now.', error);
    }
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
