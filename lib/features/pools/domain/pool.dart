class Pool {
  const Pool({
    required this.id,
    required this.name,
    required this.gameweek,
    required this.stakeCents,
    required this.prizePoolCents,
    required this.status,
    required this.memberCount,
    required this.deadline,
    this.membershipStatus,
    this.approvalRequired = false,
    this.leaderboard = const [],
    this.prizeSplit = const [],
  });

  factory Pool.fromJson(Map<String, Object?> json) => Pool(
        id: json['id']! as String,
        name: json['name']! as String,
        gameweek: (json['gameweek']! as num).toInt(),
        stakeCents: (json['stake_cents']! as num).toInt(),
        prizePoolCents: (json['prize_pool_cents']! as num).toInt(),
        status: json['status']! as String,
        memberCount: (json['member_count']! as num).toInt(),
        deadline: DateTime.parse(json['deadline']! as String),
        membershipStatus: json['membership_status'] as String?,
        approvalRequired: json['approval_required'] as bool? ?? false,
        leaderboard: (json['leaderboard'] as List<Object?>? ?? const [])
            .map((item) => PoolMember.fromJson(item! as Map<String, Object?>))
            .toList(),
        prizeSplit: (json['prize_split'] as List<Object?>? ?? const [])
            .map((item) => Prize.fromJson(item! as Map<String, Object?>))
            .toList(),
      );

  final String id;
  final String name;
  final int gameweek;
  final int stakeCents;
  final int prizePoolCents;
  final String status;
  final int memberCount;
  final DateTime deadline;
  final String? membershipStatus;
  final bool approvalRequired;
  final List<PoolMember> leaderboard;
  final List<Prize> prizeSplit;

  bool get hasJoined => membershipStatus == 'active';
  bool get isPending => membershipStatus == 'pending';
  bool get canJoin => status == 'open' && membershipStatus == null;
}

class PoolMember {
  const PoolMember({
    required this.displayName,
    required this.rank,
    required this.points,
  });

  factory PoolMember.fromJson(Map<String, Object?> json) => PoolMember(
        displayName: json['display_name']! as String,
        rank: (json['rank']! as num).toInt(),
        points: (json['points']! as num).toInt(),
      );

  final String displayName;
  final int rank;
  final int points;
}

class Prize {
  const Prize({required this.place, required this.amountCents, required this.percent});

  factory Prize.fromJson(Map<String, Object?> json) => Prize(
        place: (json['place']! as num).toInt(),
        amountCents: (json['amount_cents']! as num).toInt(),
        percent: (json['percent']! as num).toInt(),
      );

  final int place;
  final int amountCents;
  final int percent;
}

class CreatePoolCommand {
  const CreatePoolCommand({
    required this.name,
    required this.gameweek,
    required this.stakeCents,
    this.approvalRequired = false,
    this.maxMembers,
  });

  final String name;
  final int gameweek;
  final int stakeCents;
  final bool approvalRequired;
  final int? maxMembers;
}

