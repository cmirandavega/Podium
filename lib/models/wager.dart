import 'package:cloud_firestore/cloud_firestore.dart';

/// A head-to-head prediction wager between two league members on a matchup
/// winner, stored at wagers/{wagerId} (Use Case 13, new in Sprint 4).
///
/// The creator picks a team and stakes Podium currency; another member takes
/// the other side for the same amount. When the week is scored the winner
/// collects both stakes. Podium currency has no cash value and can't be
/// purchased or withdrawn.
class Wager {
  const Wager({
    required this.id,
    required this.leagueId,
    required this.matchupId,
    required this.week,
    required this.creatorId,
    required this.creatorName,
    required this.pickTeamId,
    required this.amount,
    required this.status,
    this.opponentId,
    this.opponentName,
    this.winnerId,
    this.createdAt,
  });

  final String id;
  final String leagueId;
  final String matchupId;
  final int week;
  final String creatorId;
  final String creatorName;
  final String pickTeamId; // the creator's pick; the opponent has the other team
  final int amount;
  final String status; // "open", "matched", "won", "push", "void", "cancelled"
  final String? opponentId;
  final String? opponentName;
  final String? winnerId;
  final DateTime? createdAt;

  static const minAmount = 10;

  bool get isOpen => status == 'open';
  bool get isMatched => status == 'matched';
  bool get isSettled => ['won', 'push', 'void'].contains(status);
  bool involves(String uid) => creatorId == uid || opponentId == uid;

  factory Wager.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Wager(
      id: doc.id,
      leagueId: data['leagueId'] as String? ?? '',
      matchupId: data['matchupId'] as String? ?? '',
      week: (data['week'] as num?)?.toInt() ?? 0,
      creatorId: data['creatorId'] as String? ?? '',
      creatorName: data['creatorName'] as String? ?? '',
      pickTeamId: data['pickTeamId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'open',
      opponentId: data['opponentId'] as String?,
      opponentName: data['opponentName'] as String?,
      winnerId: data['winnerId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// How a wager settles once its matchup is final.
typedef WagerOutcome = ({String status, String? winnerId, Map<String, int> payouts});
