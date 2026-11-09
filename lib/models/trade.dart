import 'package:cloud_firestore/cloud_firestore.dart';

/// A trade offer between two teams, stored at trades/{tradeId} (Use Case 8).
///
/// Fields from the database table: leagueId, proposerTeamId, receiverTeamId,
/// parentTradeId, status, createdAt, reviewEndsAt. proposerId and
/// receiverId (the owners' uids) are added in Sprint 4 so security rules can
/// check who may answer the offer.
class Trade {
  const Trade({
    required this.id,
    required this.leagueId,
    required this.proposerTeamId,
    required this.receiverTeamId,
    required this.proposerId,
    required this.receiverId,
    required this.status,
    this.parentTradeId,
    this.createdAt,
    this.items = const [],
  });

  final String id;
  final String leagueId;
  final String proposerTeamId;
  final String receiverTeamId;
  final String proposerId;
  final String receiverId;
  final String status;
  final String? parentTradeId;
  final DateTime? createdAt;
  final List<TradeItem> items;

  static const statuses = [
    'pending',
    'accepted',
    'rejected',
    'countered',
    'in_review',
    'completed',
    'cancelled',
  ];

  bool get isPending => status == 'pending';
  List<TradeItem> get offered => items.where((i) => i.fromTeamId == proposerTeamId).toList();
  List<TradeItem> get requested => items.where((i) => i.fromTeamId == receiverTeamId).toList();

  /// The other team in the trade.
  String otherTeam(String teamId) => teamId == proposerTeamId ? receiverTeamId : proposerTeamId;

  Trade withItems(List<TradeItem> items) => Trade(
        id: id,
        leagueId: leagueId,
        proposerTeamId: proposerTeamId,
        receiverTeamId: receiverTeamId,
        proposerId: proposerId,
        receiverId: receiverId,
        status: status,
        parentTradeId: parentTradeId,
        createdAt: createdAt,
        items: items,
      );

  String get statusLabel => switch (status) {
        'pending' => 'Pending',
        'completed' => 'Completed',
        'rejected' => 'Rejected',
        'countered' => 'Countered',
        'cancelled' => 'Cancelled',
        'in_review' => 'In review',
        'accepted' => 'Accepted',
        _ => status,
      };

  factory Trade.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Trade(
      id: doc.id,
      leagueId: data['leagueId'] as String? ?? '',
      proposerTeamId: data['proposerTeamId'] as String? ?? '',
      receiverTeamId: data['receiverTeamId'] as String? ?? '',
      proposerId: data['proposerId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      parentTradeId: data['parentTradeId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One player in a trade, stored at trades/{tradeId}/items/{playerId}.
/// playerName is copied from the roster slot (added in Sprint 4).
class TradeItem {
  const TradeItem({required this.playerId, required this.fromTeamId, required this.playerName});

  final String playerId;
  final String fromTeamId;
  final String playerName;

  factory TradeItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return TradeItem(
      playerId: data['playerId'] as String? ?? doc.id,
      fromTeamId: data['fromTeamId'] as String? ?? '',
      playerName: data['playerName'] as String? ?? doc.id,
    );
  }
}
