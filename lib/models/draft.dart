import 'package:cloud_firestore/cloud_firestore.dart';

/// A league's live snake draft, stored at drafts/{leagueId} (Use Case 3,
/// added in Sprint 4). One team is on the clock at a time; picks go in
/// order 1..N, then N..1, for [rounds] rounds.
class Draft {
  const Draft({
    required this.leagueId,
    required this.status,
    required this.order,
    required this.rounds,
    required this.pickNumber,
    required this.currentTeamId,
    this.startedAt,
  });

  final String leagueId;
  final String status; // "live" or "complete"
  final List<String> order; // team IDs in first-round order
  final int rounds;
  final int pickNumber; // 0-based number of the pick on the clock
  final String? currentTeamId; // null once complete
  final DateTime? startedAt;

  bool get isLive => status == 'live';
  bool get isComplete => status == 'complete';
  int get totalPicks => order.length * rounds;
  int get round => pickNumber ~/ order.length + 1;
  int get pickInRound => pickNumber % order.length + 1;

  /// Team on the clock for 0-based pick [n] in a snake draft.
  static String teamForPick(List<String> order, int n) {
    final size = order.length;
    final round = n ~/ size;
    final pos = n % size;
    return order[round.isEven ? pos : size - 1 - pos];
  }

  /// The next [count] picks after the current one, as team IDs.
  List<String> upcoming(int count) => [
        for (var n = pickNumber + 1; n < totalPicks && n <= pickNumber + count; n++) teamForPick(order, n),
      ];

  factory Draft.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Draft(
      leagueId: doc.id,
      status: data['status'] as String? ?? 'live',
      order: List<String>.from(data['order'] as List? ?? const []),
      rounds: (data['rounds'] as num?)?.toInt() ?? 0,
      pickNumber: (data['pickNumber'] as num?)?.toInt() ?? 0,
      currentTeamId: data['currentTeamId'] as String?,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One pick, stored at drafts/{leagueId}/picks/{pickNumber}.
class DraftPick {
  const DraftPick({
    required this.pickNumber,
    required this.round,
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.sport,
    required this.realTeam,
    required this.auto,
  });

  final int pickNumber;
  final int round;
  final String teamId;
  final String playerId;
  final String playerName;
  final String position;
  final String sport;
  final String realTeam;
  final bool auto; // made by the commissioner's auto-pick

  factory DraftPick.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return DraftPick(
      pickNumber: (data['pickNumber'] as num?)?.toInt() ?? 0,
      round: (data['round'] as num?)?.toInt() ?? 0,
      teamId: data['teamId'] as String? ?? '',
      playerId: data['playerId'] as String? ?? '',
      playerName: data['playerName'] as String? ?? '',
      position: data['position'] as String? ?? '',
      sport: data['sport'] as String? ?? '',
      realTeam: data['realTeam'] as String? ?? '',
      auto: data['auto'] as bool? ?? false,
    );
  }
}
