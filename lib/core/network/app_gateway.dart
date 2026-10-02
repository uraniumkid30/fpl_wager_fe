import 'package:fpl_wager/features/auth/domain/auth_models.dart';
import 'package:fpl_wager/features/challenges/domain/challenge.dart';
import 'package:fpl_wager/features/dashboard/domain/dashboard.dart';
import 'package:fpl_wager/features/fpl_team/domain/fpl_team.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/settings/domain/app_settings.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';
import 'package:fpl_wager/features/payments/domain/payment.dart';
import 'package:fpl_wager/features/notifications/domain/app_notification.dart';

abstract interface class AppGateway {
  Future<AuthSession?> restoreSession();
  Future<VerificationChallenge> requestLogin(String email, String password);
  Future<AuthSession> verifyLogin(String email, String otp);

  /// Completes "Continue with FPL": exchanges the OIDC refresh token
  /// extracted from the FPL login WebView for a platform session. The
  /// backend finds-or-creates the account by the manager's FPL entry id.
  Future<AuthSession> continueWithFpl({
    required String refreshToken,
    int? entryId,
  });
  Future<VerificationChallenge> requestRegistration({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  });
  Future<AuthSession> verifyRegistration(String email, String otp);
  Future<void> requestPasswordReset(String email);
  Future<String> verifyPasswordOtp(String email, String otp);
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });
  Future<void> logout();
  Future<Dashboard> dashboard();
  Future<FplTeam> linkTeam(int entryId);
  Future<FplManager> validateTeam(int entryId);
  Future<List<Pool>> pools({int? gameweek});
  Future<Pool> pool(String id);
  Future<Pool> createPool(CreatePoolCommand command);
  Future<Pool> joinPool(String id);
  Future<Pool> leavePool(String id);
  Future<List<AppNotification>> notifications();
  Future<void> markNotificationRead(String id);
  Future<List<Challenge>> challenges();
  Future<Challenge> createChallenge({required int opponentTeamId, required int gameweek, required int stakeCents});
  Future<WalletSummary> wallet();
  Future<WalletSummary> creditWallet(int amountCents);
  Future<Payment> initializePayment({
    required int amountCents,
    required String provider,
    required String callbackUrl,
  });
  Future<Payment> verifyPayment(String reference);
  Future<AppSettings> updateSettings(AppSettings settings);
}
