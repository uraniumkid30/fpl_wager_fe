import 'package:fplboardman/features/auth/domain/auth_models.dart';
import 'package:fplboardman/features/challenges/domain/challenge.dart';
import 'package:fplboardman/features/dashboard/domain/dashboard.dart';
import 'package:fplboardman/features/fpl_team/domain/fpl_team.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:fplboardman/features/settings/domain/app_settings.dart';
import 'package:fplboardman/features/wallet/domain/wallet_models.dart';
import 'package:fplboardman/features/payments/domain/payment.dart';
import 'package:fplboardman/features/notifications/domain/app_notification.dart';
import 'package:fplboardman/features/withdrawals/domain/withdrawal_models.dart';

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

  /// The private pool an invite code belongs to, for someone who was sent
  /// the link. Anyone holding the code may see the pool and enter it.
  Future<Pool> poolByInvite(String code);

  /// Enters the signed-in manager into the pool the code belongs to.
  Future<Pool> joinPoolByInvite(String code);

  /// Changes the user's own pool. Only allowed while nobody has entered it.
  /// [rules] is left as it is when null.
  Future<Pool> updatePool(
    String id, {
    required String name,
    required int stakeCents,
    required PoolDrawMethod drawMethod,
    String? rules,
    int? maxMembers,
    PayoutChoice? payout,
  });

  /// The terms the server sets for pools users create, such as the fee for
  /// deleting one after other managers have joined.
  Future<PoolTerms> poolTerms();

  /// Deletes the user's own pool, refunding everyone in it. [feeCents] is
  /// the fee the creator was shown and agreed to; if it has changed since,
  /// the server refuses with the code `DELETE_FEE_CHANGED` and nothing is
  /// deleted.
  Future<void> deletePool(String id, {required int feeCents});

  /// Gives the user's own pool a new invite code, so the old link stops
  /// working. Returns the pool with the new code.
  Future<Pool> resetPoolInvite(String id);
  Future<List<AppNotification>> notifications();
  Future<void> markNotificationRead(String id);
  Future<List<Challenge>> challenges();
  Future<Challenge> createChallenge({required int opponentTeamId, required int gameweek, required int stakeCents});
  Future<WalletSummary> wallet();

  /// The wallet's balances without its history. It is a small request the
  /// app repeats to keep the balance on screen current.
  Future<WalletBalance> walletBalance();
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
