/// One gameweek in a manager's history: where their FPL score placed them
/// among everyone who played on FPLboardman that gameweek, the pools they
/// entered and their money in and out.
class GameweekResult {
  const GameweekResult({
    required this.gameweek,
    required this.poolsEntered,
    required this.stakedCents,
    required this.wonCents,
    required this.isFinal,
    this.gameweekStatus = '',
    this.deadline,
    this.points,
    this.position,
    this.managers,
    this.pools = const [],
  });

  factory GameweekResult.fromJson(Map<String, Object?> json) => GameweekResult(
        gameweek: (json['gameweek']! as num).toInt(),
        gameweekStatus: json['gameweek_status'] as String? ?? '',
        deadline: json['deadline'] is String
            ? DateTime.tryParse(json['deadline']! as String)
            : null,
        points: (json['points'] as num?)?.toInt(),
        position: (json['position'] as num?)?.toInt(),
        managers: (json['managers'] as num?)?.toInt(),
        poolsEntered: (json['pools_entered'] as num? ?? 0).toInt(),
        stakedCents: (json['staked_cents'] as num? ?? 0).toInt(),
        wonCents: (json['won_cents'] as num? ?? 0).toInt(),
        isFinal: json['final'] as bool? ?? false,
        pools: (json['pools'] as List<Object?>? ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map((item) => GameweekPoolResult.fromJson(
                  Map<String, Object?>.from(item),
                ))
            .toList(),
      );

  final int gameweek;

  /// FPL's status for the gameweek: upcoming, current or finished.
  final String gameweekStatus;
  final DateTime? deadline;

  /// The manager's FPL points for the gameweek, once scoring has started.
  final int? points;

  /// Where those points placed them among [managers] on the platform
  /// (managers level on points share a position).
  final int? position;
  final int? managers;
  final int poolsEntered;
  final int stakedCents;
  final int wonCents;

  /// True when every pool they entered that gameweek has been settled.
  final bool isFinal;
  final List<GameweekPoolResult> pools;

  int get netCents => wonCents - stakedCents;
}

/// One pool the manager entered in a gameweek and how they did in it.
class GameweekPoolResult {
  const GameweekPoolResult({
    required this.id,
    required this.name,
    required this.status,
    required this.stakeCents,
    required this.entrants,
    required this.payoutCents,
    this.poolKind = 'custom',
    this.points,
    this.rank,
  });

  factory GameweekPoolResult.fromJson(Map<String, Object?> json) =>
      GameweekPoolResult(
        id: json['id']! as String,
        name: json['name'] as String? ?? '',
        poolKind: json['pool_kind'] as String? ?? 'custom',
        status: json['status'] as String? ?? '',
        stakeCents: (json['stake_cents'] as num? ?? 0).toInt(),
        entrants: (json['entrants'] as num? ?? 0).toInt(),
        points: (json['points'] as num?)?.toInt(),
        rank: (json['rank'] as num?)?.toInt(),
        payoutCents: (json['payout_cents'] as num? ?? 0).toInt(),
      );

  final String id;
  final String name;
  final String poolKind;
  final String status;
  final int stakeCents;
  final int entrants;

  /// Null until the pool has been scored.
  final int? points;
  final int? rank;
  final int payoutCents;

  bool get isSettled => status == 'settled';
  bool get isLive => status == 'locked' || status == 'scoring';
}
