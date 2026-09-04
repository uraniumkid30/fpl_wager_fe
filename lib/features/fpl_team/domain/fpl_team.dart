class FplTeam {
  const FplTeam({
    required this.entryId,
    required this.teamName,
    required this.managerName,
    this.overallRank,
  });

  factory FplTeam.fromJson(Map<String, Object?> json) => FplTeam(
        entryId: (json['entry_id']! as num).toInt(),
        teamName: json['team_name']! as String,
        managerName: json['manager_name']! as String,
        overallRank: (json['overall_rank'] as num?)?.toInt(),
      );

  final int entryId;
  final String teamName;
  final String managerName;
  final int? overallRank;
}

class FplManager {
  const FplManager({
    required this.entryId,
    required this.teamName,
    required this.firstName,
    required this.lastName,
    required this.overallPoints,
    required this.gameweekPoints,
    this.overallRank,
    this.currentGameweek,
  });

  factory FplManager.fromJson(Map<String, Object?> json) => FplManager(
        entryId: (json['id']! as num).toInt(),
        teamName: json['name']! as String,
        firstName: json['player_first_name']! as String,
        lastName: json['player_last_name']! as String,
        overallPoints: (json['summary_overall_points']! as num).toInt(),
        gameweekPoints: (json['summary_event_points']! as num).toInt(),
        overallRank: (json['summary_overall_rank'] as num?)?.toInt(),
        currentGameweek: (json['current_event'] as num?)?.toInt(),
      );

  final int entryId;
  final String teamName;
  final String firstName;
  final String lastName;
  final int overallPoints;
  final int gameweekPoints;
  final int? overallRank;
  final int? currentGameweek;

  String get managerName => '$firstName $lastName'.trim();
}
