import 'package:cloud_firestore/cloud_firestore.dart';

/// A fantasy league, stored at leagues/{leagueId} (Use Case 2).
///
/// Fields from the Sprint 3 database table: name, commissionerId, format,
/// sports, season, maxTeams, rosterSize, tradeReviewHours, status, createdAt.
/// Added in Sprint 4: inviteCode, memberIds, starterCount, currentWeek,
/// regularSeasonWeeks, playoffTeams, lineupLocked, phase, championTeamId.
class League {
  const League({
    required this.id,
    required this.name,
    required this.commissionerId,
    required this.format,
    required this.sports,
    required this.season,
    required this.maxTeams,
    required this.rosterSize,
    required this.starterCount,
    required this.tradeReviewHours,
    required this.status,
    required this.inviteCode,
    required this.memberIds,
    required this.currentWeek,
    required this.regularSeasonWeeks,
    required this.playoffTeams,
    required this.lineupLocked,
    required this.phase,
    this.draftStatus = 'complete',
    this.championTeamId,
    this.createdAt,
  });

  final String id;
  final String name;
  final String commissionerId;
  final String format; // "single-sport" or "multi-sport"
  final List<String> sports;
  final String season; // season replayed from the sports data, e.g. "2024"
  final int maxTeams;
  final int rosterSize;
  final int starterCount;
  final int tradeReviewHours;
  final String status; // "active" or "completed"
  final String inviteCode;
  final List<String> memberIds;
  final int currentWeek; // next week to be scored, starting at 1
  final int regularSeasonWeeks;
  final int playoffTeams; // 0, 2, or 4
  final bool lineupLocked;
  final String phase; // "preseason", "regular", "playoffs", "complete"
  final String? championTeamId;

  /// "not_started", "live", or "complete". Leagues from before the live
  /// draft have no value and count as complete.
  final String draftStatus;
  bool get draftComplete => draftStatus == 'complete';
  final DateTime? createdAt;

  static const formats = ['single-sport', 'multi-sport'];

  bool isCommissioner(String uid) => commissionerId == uid;
  bool hasMember(String uid) => memberIds.contains(uid);
  bool get isFull => memberIds.length >= maxTeams;

  /// The scoringPeriods document for the week being played, matching the
  /// IDs the ingestion script writes (for example "period_2024_w3").
  String periodIdForWeek(int week) => 'period_${season}_w$week';
  String get currentPeriodId => periodIdForWeek(currentWeek);

  String get formatLabel => format == 'single-sport' ? 'Single-sport' : 'Multi-sport';

  factory League.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return League(
      id: doc.id,
      name: data['name'] as String? ?? 'League',
      commissionerId: data['commissionerId'] as String? ?? '',
      format: data['format'] as String? ?? 'multi-sport',
      sports: List<String>.from(data['sports'] as List? ?? const []),
      season: data['season']?.toString() ?? '',
      maxTeams: (data['maxTeams'] as num?)?.toInt() ?? 10,
      rosterSize: (data['rosterSize'] as num?)?.toInt() ?? 12,
      starterCount: (data['starterCount'] as num?)?.toInt() ?? 8,
      tradeReviewHours: (data['tradeReviewHours'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'active',
      inviteCode: data['inviteCode'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      currentWeek: (data['currentWeek'] as num?)?.toInt() ?? 1,
      regularSeasonWeeks: (data['regularSeasonWeeks'] as num?)?.toInt() ?? 4,
      playoffTeams: (data['playoffTeams'] as num?)?.toInt() ?? 0,
      lineupLocked: data['lineupLocked'] as bool? ?? false,
      phase: data['phase'] as String? ?? 'preseason',
      championTeamId: data['championTeamId'] as String?,
      draftStatus: data['draftStatus'] as String? ?? 'complete',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A league member, stored at leagues/{leagueId}/members/{userId}.
/// [coins] is the member's Podium currency balance for wagers in this league
/// (Use Case 13). Podium currency has no cash value.
class LeagueMember {
  const LeagueMember({
    required this.userId,
    required this.username,
    required this.isMuted,
    required this.coins,
    this.joinedAt,
  });

  final String userId;
  final String username;
  final bool isMuted;
  final int coins;
  final DateTime? joinedAt;

  static const startingCoins = 1000;

  factory LeagueMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LeagueMember(
      userId: data['userId'] as String? ?? doc.id,
      username: data['username'] as String? ?? '',
      isMuted: data['isMuted'] as bool? ?? false,
      coins: (data['coins'] as num?)?.toInt() ?? startingCoins,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A request to join a league, stored at leagues/{leagueId}/joinRequests/{userId}
/// (Use Case 2, Sprint 4). The commissioner approves or declines it; approving
/// adds the member and creates their team.
class JoinRequest {
  const JoinRequest({
    required this.userId,
    required this.username,
    required this.teamName,
    required this.status,
    this.createdAt,
  });

  final String userId;
  final String username;
  final String teamName;
  final String status; // "pending", "approved", "declined"
  final DateTime? createdAt;

  factory JoinRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return JoinRequest(
      userId: data['userId'] as String? ?? doc.id,
      username: data['username'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
