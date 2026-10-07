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
    this.poolKind = 'custom',
    this.rules = '',
    this.drawMethod = PoolDrawMethod.split,
    this.inviteCode,
    this.maxMembers,
    this.autoSeriesNo,
    this.leaderboard = const [],
    this.prizeSplit = const [],
    this.payout,
    this.visibility = 'public',
    this.creatorName = '',
    this.isCreator = false,
    this.manage,
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
        poolKind: json['pool_kind'] as String? ?? 'custom',
        rules: json['rules'] as String? ?? '',
        drawMethod: PoolDrawMethod.fromWireValue(
          json['draw_method'] as String? ?? 'split',
        ),
        inviteCode: json['invite_code'] as String?,
        maxMembers: (json['max_members'] as num?)?.toInt(),
        autoSeriesNo: (json['auto_series_no'] as num?)?.toInt(),
        leaderboard: (json['leaderboard'] as List<Object?>? ?? const [])
            .map((item) => PoolMember.fromJson(item! as Map<String, Object?>))
            .toList(),
        prizeSplit: (json['prize_split'] as List<Object?>? ?? const [])
            .map((item) => Prize.fromJson(item! as Map<String, Object?>))
            .toList(),
        payout: json['payout'] is Map<String, Object?>
            ? PayoutPlan.fromJson(json['payout']! as Map<String, Object?>)
            : null,
        visibility: json['visibility'] as String? ?? 'public',
        creatorName: json['creator_name'] as String? ?? '',
        isCreator: json['is_creator'] as bool? ?? false,
        manage: json['manage'] is Map<Object?, Object?>
            ? PoolManage.fromJson(
                Map<String, Object?>.from(json['manage']! as Map<Object?, Object?>),
              )
            : null,
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
  final String poolKind;
  final String rules;
  final PoolDrawMethod drawMethod;
  final String? inviteCode;
  final int? maxMembers;
  final int? autoSeriesNo;
  final List<PoolMember> leaderboard;
  final List<Prize> prizeSplit;

  /// How the pot is shared at the pool's current size. Only present on a
  /// pool's detail, not in lists.
  final PayoutPlan? payout;

  /// "private" for a pool a user created: only its creator and the managers
  /// they invite can see or enter it. Auto pools are "public".
  final String visibility;

  /// Who created a custom pool; empty for auto pools.
  final String creatorName;

  /// True when the signed-in user created this pool.
  final bool isCreator;

  /// What the creator may still do with the pool. Only sent to the creator,
  /// and only on a pool's detail.
  final PoolManage? manage;

  bool get isPrivate => visibility == 'private';

  /// True for a pool the signed-in user created. Lists do not carry
  /// [isCreator], but only the creator is ever sent the invite code.
  bool get isMine => isCreator || (inviteCode?.isNotEmpty ?? false);

  bool get hasJoined => membershipStatus == 'active';
  bool get isPending => membershipStatus == 'pending';
  /// An open pool can be entered by anyone who is not in it, including a
  /// manager who left earlier and wants back in.
  bool get canJoin =>
      status == 'open' && (membershipStatus == null || hasLeft);

  /// True for a manager who was in the pool and left it (their stake was
  /// returned).
  bool get hasLeft =>
      membershipStatus == 'left' || membershipStatus == 'refunded';
  bool get isAuto => poolKind == 'auto';
  bool get awaitingAdminApproval => poolKind == 'custom' && status == 'draft';
}

/// What a pool's creator can do with it right now.
///
/// A pool can be edited only while nobody has entered it. It can be deleted
/// until it closes at the gameweek deadline; everyone who entered is then
/// refunded, and if anyone other than the creator had entered, the creator
/// pays a fee of [deleteFeePercent] of the pot.
class PoolManage {
  const PoolManage({
    required this.entries,
    required this.otherEntries,
    required this.canEdit,
    required this.canDelete,
    required this.deleteFeeCents,
    this.deleteFeePercent = 5,
  });

  factory PoolManage.fromJson(Map<String, Object?> json) => PoolManage(
        entries: (json['entries'] as num? ?? 0).toInt(),
        otherEntries: (json['other_entries'] as num? ?? 0).toInt(),
        canEdit: json['can_edit'] as bool? ?? false,
        canDelete: json['can_delete'] as bool? ?? false,
        deleteFeeCents: (json['delete_fee_cents'] as num? ?? 0).toInt(),
        deleteFeePercent: (json['delete_fee_percent'] as num? ?? 5).toDouble(),
      );

  /// Paid entries in the pool, the creator's own included.
  final int entries;

  /// How many of those entries belong to other managers.
  final int otherEntries;
  final bool canEdit;
  final bool canDelete;

  /// What deleting the pool now would cost the creator. Zero until another
  /// manager has entered.
  final int deleteFeeCents;
  final double deleteFeePercent;

  /// "5" or "2.5" — the fee percentage without a trailing ".0".
  String get deleteFeePercentLabel =>
      deleteFeePercent == deleteFeePercent.roundToDouble()
          ? deleteFeePercent.toStringAsFixed(0)
          : deleteFeePercent.toString();
}

class PoolMember {
  const PoolMember({
    required this.displayName,
    required this.rank,
    required this.points,
    this.payoutCents = 0,
  });

  factory PoolMember.fromJson(Map<String, Object?> json) => PoolMember(
        displayName: json['display_name']! as String,
        rank: (json['rank']! as num).toInt(),
        points: (json['points']! as num).toInt(),
        payoutCents: (json['payout_cents'] as num?)?.toInt() ?? 0,
      );

  final String displayName;
  final int rank;
  final int points;

  /// What this entry won once the pool was settled; zero until then, and for
  /// entries that finished outside the paid places.
  final int payoutCents;
}

/// One paid place. [percent] is that place's share of the prize pool (the
/// pot after the platform fee), to two decimal places.
class Prize {
  const Prize({required this.place, required this.amountCents, required this.percent});

  factory Prize.fromJson(Map<String, Object?> json) => Prize(
        place: (json['place']! as num).toInt(),
        amountCents: (json['amount_cents']! as num).toInt(),
        percent: (json['percent']! as num).toDouble(),
      );

  final int place;
  final int amountCents;
  final double percent;

  /// "100" for a whole number, otherwise two decimals such as "5.42".
  String get percentLabel => percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toStringAsFixed(2);
}

/// The prize structure for a pool at a given size.
///
/// Everyone stakes the same amount. A platform fee comes off the top, the
/// rest is the prize pool. One manager wins for every ten who enter (at
/// least one, at most fifty), and each place wins a fixed share of the place
/// above it, so the prizes fall away smoothly from first to last. The last
/// winner is never paid less than 130% of the stake.
class PayoutPlan {
  const PayoutPlan({
    required this.entrants,
    required this.stakeCents,
    required this.totalStakedCents,
    required this.houseCutCents,
    required this.houseCutPercent,
    required this.totalWinningCents,
    required this.winners,
    required this.commonRatio,
    required this.floorMet,
  });

  factory PayoutPlan.fromJson(Map<String, Object?> json) => PayoutPlan(
        entrants: (json['entrants'] as num? ?? 0).toInt(),
        stakeCents: (json['stake_cents'] as num? ?? 0).toInt(),
        totalStakedCents: (json['total_staked_cents'] as num? ?? 0).toInt(),
        houseCutCents: (json['house_cut_cents'] as num? ?? 0).toInt(),
        houseCutPercent: (json['house_cut_percent'] as num? ?? 0).toDouble(),
        totalWinningCents: (json['total_winning_cents'] as num? ?? 0).toInt(),
        winners: (json['winners'] as num? ?? 0).toInt(),
        commonRatio: (json['common_ratio'] as num? ?? 0).toDouble(),
        floorMet: json['floor_met'] as bool? ?? true,
      );

  final int entrants;
  final int stakeCents;
  final int totalStakedCents;
  final int houseCutCents;
  final double houseCutPercent;
  final int totalWinningCents;
  final int winners;
  final double commonRatio;
  final bool floorMet;

  /// "5" or "2.5" — the platform fee without a trailing ".0".
  String get houseCutPercentLabel =>
      houseCutPercent == houseCutPercent.roundToDouble()
          ? houseCutPercent.toStringAsFixed(0)
          : houseCutPercent.toString();
}

class CreatePoolCommand {
  const CreatePoolCommand({
    required this.name,
    required this.gameweek,
    required this.stakeCents,
    required this.rules,
    required this.drawMethod,
    this.approvalRequired = false,
    this.maxMembers,
  });

  final String name;
  final int gameweek;
  final int stakeCents;
  final String rules;
  final PoolDrawMethod drawMethod;
  final bool approvalRequired;
  final int? maxMembers;
}

enum PoolDrawMethod {
  split,
  captains,
  number;

  factory PoolDrawMethod.fromWireValue(String value) => switch (value) {
        'captains' => PoolDrawMethod.captains,
        'number' => PoolDrawMethod.number,
        _ => PoolDrawMethod.split,
      };

  String get wireValue => name;

  String get label => switch (this) {
        PoolDrawMethod.split => 'SPLIT',
        PoolDrawMethod.captains => 'CAPTAINS',
        PoolDrawMethod.number => 'NUMBER',
      };

  String get description => switch (this) {
        PoolDrawMethod.split =>
          'Combine the tied prize positions and divide the money equally.',
        PoolDrawMethod.captains =>
          'Use captain gameweek points to break a tie.',
        PoolDrawMethod.number =>
          'Use the numeric tie-break stated in the custom pool rules.',
      };
}
