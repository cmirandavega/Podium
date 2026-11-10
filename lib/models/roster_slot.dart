import 'package:cloud_firestore/cloud_firestore.dart';

/// A player on a fantasy roster, stored at rosterSlots/{leagueId}_{playerId}.
/// The doc ID means a player can be on only one team per league.
///
/// Fields from the database table: leagueId, playerId, teamId, slotPosition,
/// isStarter, acquiredAt. playerName, sport, and realTeam are copied from the
/// player (added in Sprint 4) so rosters load without a read per player.
class RosterSlot {
  const RosterSlot({
    required this.id,
    required this.leagueId,
    required this.playerId,
    required this.teamId,
    required this.slotPosition,
    required this.isStarter,
    required this.playerName,
    required this.sport,
    required this.realTeam,
    this.acquiredAt,
  });

  final String id;
  final String leagueId;
  final String playerId;
  final String teamId;
  final String slotPosition;
  final bool isStarter;
  final String playerName;
  final String sport;
  final String realTeam;
  final DateTime? acquiredAt;

  static String idFor(String leagueId, String playerId) => '${leagueId}_$playerId';

  factory RosterSlot.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return RosterSlot(
      id: doc.id,
      leagueId: data['leagueId'] as String? ?? '',
      playerId: data['playerId'] as String? ?? '',
      teamId: data['teamId'] as String? ?? '',
      slotPosition: data['slotPosition'] as String? ?? '',
      isStarter: data['isStarter'] as bool? ?? false,
      playerName: data['playerName'] as String? ?? (data['playerId'] as String? ?? ''),
      sport: data['sport'] as String? ?? '',
      realTeam: data['realTeam'] as String? ?? '',
      acquiredAt: (data['acquiredAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Short label for lists and AI prompts, e.g. "Josh Allen (QB, BUF, NFL)".
  String get label {
    final details = [slotPosition, realTeam, sport].where((s) => s.isNotEmpty).join(', ');
    return details.isEmpty ? playerName : '$playerName ($details)';
  }
}
