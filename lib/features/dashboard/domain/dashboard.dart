import 'package:fpl_wager/features/auth/domain/auth_models.dart';
import 'package:fpl_wager/features/fpl_team/domain/fpl_team.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';

class Dashboard {
  const Dashboard({
    required this.user,
    required this.wallet,
    required this.activeWagers,
    required this.currentGameweek,
    required this.deadline,
    this.team,
  });

  factory Dashboard.fromJson(Map<String, Object?> json) => Dashboard(
        user: UserProfile.fromJson(json['user']! as Map<String, Object?>),
        wallet: WalletSummary.fromJson(json['wallet']! as Map<String, Object?>),
        activeWagers: (json['active_wagers']! as num).toInt(),
        currentGameweek: (json['current_gameweek']! as num).toInt(),
        deadline: json['deadline'] == null
            ? null
            : DateTime.parse(json['deadline']! as String),
        team: json['team'] == null
            ? null
            : FplTeam.fromJson(json['team']! as Map<String, Object?>),
      );

  final UserProfile user;
  final FplTeam? team;
  final WalletSummary wallet;
  final int activeWagers;
  final int currentGameweek;
  final DateTime? deadline;
}

