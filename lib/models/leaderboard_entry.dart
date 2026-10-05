class LeaderboardEntry {
  final String id;
  final String teamName;
  final double points;
  final String sport;
  final String season;

  LeaderboardEntry({
    required this.id,
    required this.teamName,
    required this.points,
    required this.sport,
    required this.season,
  });

  factory LeaderboardEntry.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return LeaderboardEntry(
      id: id,
      teamName: data['teamName'] ?? 'Unknown Team',
      points: (data['points'] ?? 0).toDouble(),
      sport: data['sport'] ?? 'All',
      season: data['season'] ?? '2026',
    );
  }
}
