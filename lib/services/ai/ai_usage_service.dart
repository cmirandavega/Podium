import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/ai_feature.dart';
import 'ai_exceptions.dart';

/// Daily request limits for the AI features, stored at
/// aiUsage/{userId}_{usageDate}_{feature}.
///
/// Flow for each AI request:
///   1. [ensureAvailable] before calling the model (throws if at the limit)
///   2. call the model
///   3. [record] after a successful response
/// Failed AI calls don't count against the user. Security rules cap
/// requestCount at the feature's limit, so the client can't go over it.
class AiUsageService {
  AiUsageService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    DateTime Function()? clock,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  /// UTC date key, for example "2026-11-09". Days roll over at UTC midnight
  /// so every user's limit resets at the same moment.
  static String usageDate(DateTime now) {
    final utc = now.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  static String docId(String uid, String date, AiFeature feature) =>
      '${uid}_${date}_${feature.key}';

  /// Next UTC midnight, returned in local time for display.
  static DateTime nextReset(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day + 1).toLocal();
  }

  static int remainingFrom(int used, AiFeature feature) =>
      (feature.dailyLimit - used).clamp(0, feature.dailyLimit).toInt();

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid, AiFeature feature) =>
      _db.collection('aiUsage').doc(docId(uid, usageDate(_clock()), feature));

  /// Throws [AiLimitReachedException] if today's limit is used up.
  Future<void> ensureAvailable(AiFeature feature) async {
    final snapshot = await _doc(_uid, feature).get();
    final used = snapshot.data()?['requestCount'] as int? ?? 0;
    if (used >= feature.dailyLimit) {
      throw AiLimitReachedException(
        feature: feature,
        resetsAt: nextReset(_clock()),
      );
    }
  }

  /// Counts one successful request. Returns how many are left today.
  Future<int> record(AiFeature feature) async {
    final uid = _uid;
    final date = usageDate(_clock());
    final ref = _doc(uid, feature);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final used = snapshot.data()?['requestCount'] as int? ?? 0;

      if (used >= feature.dailyLimit) {
        throw AiLimitReachedException(
          feature: feature,
          resetsAt: nextReset(_clock()),
        );
      }

      if (snapshot.exists) {
        transaction.update(ref, {'requestCount': used + 1});
      } else {
        transaction.set(ref, {
          'userId': uid,
          'usageDate': date,
          'feature': feature.key,
          'requestCount': 1,
        });
      }
      return remainingFrom(used + 1, feature);
    });
  }

  /// Live count of requests left today, for showing "8 left today" in the UI.
  Stream<int> watchRemaining(AiFeature feature) {
    return _doc(_uid, feature).snapshots().map(
          (snapshot) => remainingFrom(
            snapshot.data()?['requestCount'] as int? ?? 0,
            feature,
          ),
        );
  }
}
