import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/chat_message.dart';
import '../models/league.dart';
import 'report_service.dart';

/// Use Case 7: league chat with moderation by the commissioner and admins.
  class ChatService {
    ChatService({FirebaseFirestore? db, FirebaseAuth? auth, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  CollectionReference<Map<String, dynamic>> _messages(String leagueId) =>
      _db.collection('leagues').doc(leagueId).collection('messages');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  /// The newest [limit] messages, newest first (the chat list is reversed).
  Stream<List<ChatMessage>> watchMessages(String leagueId, {int limit = 100}) {
    return _messages(leagueId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(ChatMessage.fromFirestore).toList());
  }

  /// Returns an error message, or null when [body] can be sent.
  static String? validateBody(String body) {
    final text = body.trim();
    if (text.isEmpty) return 'Type a message first.';
    if (text.length > ChatMessage.maxLength) {
      return 'Messages can be up to ${ChatMessage.maxLength} characters.';
    }
    return null;
  }

  Future<void> send({
    required League league,
    required LeagueMember me,
    required String body,
  }) async {
    final uid = _uid;
    if (!league.hasMember(uid)) throw StateError('Only league members can chat.');
    if (me.isMuted) throw StateError('A moderator muted you in this league.');
    final error = validateBody(body);
    if (error != null) throw ArgumentError(error);

    // The server re-checks membership, mutes and language before saving.
    try {
      await _functions
          .httpsCallable('podiumSendMessage')
          .call({'leagueId': league.id, 'body': body.trim()});
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'Message could not be sent.');
    }
  }

  /// Senders can delete their own messages; commissioners and admins can
  /// delete any message. The text is cleared and the message is marked deleted.
  Future<void> deleteMessage({required String leagueId, required String messageId}) {
    return _messages(leagueId).doc(messageId).update({'isDeleted': true, 'body': ''});
  }

  /// Commissioner or admin mutes or unmutes a member.
  Future<void> setMuted({
    required String leagueId,
    required String userId,
    required bool muted,
  }) {
    return _db
        .collection('leagues')
        .doc(leagueId)
        .collection('members')
        .doc(userId)
        .update({'isMuted': muted});
  }

  /// Sends the message to the admin report queue (Use Case 14).
  Future<void> reportMessage({required ChatMessage message, required String leagueName}) {
    return ReportService().submitReport(
      reportedUserId: message.senderId,
      reason: 'Inappropriate chat message',
      details: 'League "$leagueName" chat: "${message.body}"',
    );
  }
}
