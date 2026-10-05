import 'package:fpl_wager/features/auth/domain/auth_models.dart';
import 'package:fpl_wager/features/challenges/domain/challenge.dart';
import 'package:fpl_wager/features/dashboard/domain/dashboard.dart';
import 'package:fpl_wager/features/fpl_team/domain/fpl_team.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/settings/domain/app_settings.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';
import 'package:fpl_wager/features/payments/domain/payment.dart';
import 'package:fpl_wager/features/notifications/domain/app_notification.dart';
import 'package:fpl_wager/features/withdrawals/domain/withdrawal_models.dart';

abstract interface class AppGateway {
  Future<AuthSession?> restoreSession();

  /// Completes "Sign in with FPL": exchanges the OIDC refresh token
  /// extracted from the FPL login WebView for a platform session. The
  /// backend finds-or-creates the account by the manager's FPL entry id.
  ///
  /// [session] is the rest of what FPL's web app stored for the login
  /// (profile claims, scope, expiry) with every token removed. The server
  /// only records it, so an operator can see what FPL exposes at sign-in.
  Future<AuthSession> continueWithFpl({
    required String refreshToken,
    Map<String, Object?>? session,
  });

  /// "Sign in with email", step one: emails a six-digit code to [email].
  ///
  /// Only works for an account that already exists (accounts are created by
  /// signing in with FPL) and whose email has been verified. Otherwise the
  /// server answers with the code `EMAIL_SIGN_IN_UNAVAILABLE` and a message
  /// telling the person to use "Sign in with FPL".
  Future<VerificationChallenge> requestEmailSignIn(String email);

  /// "Sign in with email", step two: exchanges the code for a session.
  Future<AuthSession> verifyEmailSignIn(String email, String otp);

  /// "Verify email", step one: sends a six-digit code to [email].
  Future<VerificationChallenge> requestEmailVerification(String email);

  /// "Verify email", step two: confirms the code. On success [email] becomes
  /// the account's verified address and the updated profile is returned.
  Future<UserProfile> verifyEmail(String email, String otp);

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
    required String cancelUrl,
  });
  Future<Payment> verifyPayment(String reference);

  /// The banks a user can pick from, from the payment provider's own list.
  Future<List<Bank>> banks();

  /// The user's saved bank account, or null if they have not added one.
  Future<BankAccount?> bankAccount();

  /// Looks up who owns an account number, without saving anything, so the
  /// user can confirm the name before they save.
  Future<BankAccount> resolveBankAccount({
    required String bankCode,
    required String accountNumber,
  });

  /// Adds the user's bank account, or replaces the one they have. The
  /// account name is looked up by the server; it is never sent from here.
  Future<BankAccount> saveBankAccount({
    required String bankCode,
    required String accountNumber,
  });

  Future<void> deleteBankAccount();

  Future<WithdrawalOverview> withdrawals();

  /// Asks to withdraw [amountCents] to the saved bank account. The same
  /// [idempotencyKey] sent twice returns the first request instead of
  /// creating a second one.
  Future<Withdrawal> requestWithdrawal({
    required int amountCents,
    required String idempotencyKey,
  });
  Future<AppSettings> updateSettings(AppSettings settings);
}
