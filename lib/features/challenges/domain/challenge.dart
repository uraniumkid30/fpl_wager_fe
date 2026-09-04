class Challenge {
  const Challenge({
    required this.id,
    required this.opponentName,
    required this.opponentTeamId,
    required this.gameweek,
    required this.stakeCents,
    required this.status,
  });

  factory Challenge.fromJson(Map<String, Object?> json) => Challenge(
        id: json['id']! as String,
        opponentName: json['opponent_name']! as String,
        opponentTeamId: (json['opponent_team_id']! as num).toInt(),
        gameweek: (json['gameweek']! as num).toInt(),
        stakeCents: (json['stake_cents']! as num).toInt(),
        status: json['status']! as String,
      );

  final String id;
  final String opponentName;
  final int opponentTeamId;
  final int gameweek;
  final int stakeCents;
  final String status;
}

