import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Firestore reads + authenticated server-side mutations for use cases 2, 3, 7.
class LeagueFeatureService {
  LeagueFeatureService._();
  static final instance = LeagueFeatureService._();
  final db = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instance;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? (throw StateError('Please sign in.'));

  Future<Map<String, dynamic>> invoke(String name, Map<String, dynamic> input) async {
    try {
      final response = await functions.httpsCallable(name).call(input);
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Unable to complete the request.');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> leagues() =>
      db.collection('leagues').snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> league(String id) =>
      db.collection('leagues').doc(id).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> sports() =>
      db.collection('sports').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> members(String id) =>
      db.collection('leagues').doc(id).collection('members').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> players() =>
      db.collection('players').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> roster(String leagueId, String teamId) =>
      db.collection('rosterSlots').where('teamId', isEqualTo: teamId).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> periods() =>
      db.collection('scoringPeriods').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> chat(String leagueId) =>
      db.collection('leagues').doc(leagueId).collection('messages')
          .orderBy('createdAt', descending: true).limit(75).snapshots();

  Future<String> createLeague({required String name, required List<String> sports,
    required String season, required int maxTeams, required int rosterSize}) async {
    final r = await invoke('podiumCreateLeague', {
      'name': name, 'sports': sports, 'season': season,
      'maxTeams': maxTeams, 'rosterSize': rosterSize,
    });
    return r['leagueId'] as String;
  }
  Future<void> updateSports(String leagueId, List<String> sports) async {
    await invoke('podiumUpdateSports', {'leagueId': leagueId, 'sports': sports});
  }
  Future<void> joinLeague(String leagueId) async {
    await invoke('podiumJoinLeague', {'leagueId': leagueId});
  }
  Future<void> rosterAction(String leagueId, String operation, {String? playerId,
      String? replacementId, String? periodId, bool? isStarter}) async {
      await invoke('podiumRosterAction', {
        'leagueId': leagueId, 'operation': operation,
        if (playerId != null) 'playerId': playerId,
        if (replacementId != null) 'replacementId': replacementId,
        if (periodId != null) 'periodId': periodId,
        if (isStarter != null) 'isStarter': isStarter,
      });
  }
  Future<void> sendMessage(String leagueId, String body, {String? tradeId}) async {
    await invoke('podiumSendMessage', {'leagueId': leagueId, 'body': body,
        if (tradeId != null) 'tradeId': tradeId});
  }
  Future<void> proposeTrade(String leagueId, String receiverId,
    List<String> offeredIds, List<String> requestedIds) async {
    await invoke('podiumProposeTrade', {'leagueId': leagueId,'receiverId': receiverId,
      'offeredIds':offeredIds,'requestedIds':requestedIds});
  }
  Future<void> respondTrade(String tradeId, String decision) async {
    await invoke('podiumRespondTrade', {'tradeId':tradeId,'decision':decision});
  }
  Future<void> deleteMessage(String leagueId, String messageId) async {
    await invoke('podiumModerateChat', {'leagueId': leagueId, 'action': 'delete', 'messageId': messageId});
  }
  Future<void> muteMember(String leagueId, String userId, bool muted) async {
    await invoke('podiumModerateChat', {'leagueId': leagueId,
        'action': 'mute', 'userId': userId, 'muted': muted});
  }
}
