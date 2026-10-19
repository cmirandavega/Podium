import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<LeaderboardEntry>> getLeaderboard() {
    return _firestore
        .collection('leaderboard')
        .orderBy('points', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaderboardEntry.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();
    });
  }
}
