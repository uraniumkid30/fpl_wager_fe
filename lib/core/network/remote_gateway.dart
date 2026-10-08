import 'package:fplboardman/core/errors/app_exception.dart';
import 'package:fplboardman/core/network/api_client.dart';
import 'package:fplboardman/core/network/app_gateway.dart';
import 'package:fplboardman/core/storage/session_store.dart';
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
import 'package:uuid/uuid.dart';

class RemoteGateway implements AppGateway {
  RemoteGateway(this._client, this._sessions) {
    _client.setRefreshHandler(_refreshAccessToken);
  }
  final ApiClient _client;
  final SessionStore _sessions;
  final _uuid = const Uuid();
  StoredTokens? _tokens;

  /// Set when the server turns out not to have the balance-only endpoint
  /// (an older version of the API); the full wallet is asked for instead.
  bool _balanceEndpointMissing = false;
  Future<String?>? _refreshing;

  @override
  Future<AuthSession?> restoreSession() async {
    final stored = await _sessions.read();
    if (stored == null) return null;
    _tokens = stored;
    _client.authorize(stored.accessToken);
    try {
      final body = await _client.get('/me');
      return _session(UserProfile.fromJson(_json(body, 'user')), stored);
    } on AuthenticationException {
      await _sessions.clear();
      _client.authorize(null);
      return null;
    }
  }

  @override
  Future<AuthSession> continueWithFpl({
    required String refreshToken,
    Map<String, Object?>? session,
  }) async => _saveTokenResponse(
        await _client.post(
          '/auth/fpl',
          allowRefresh: false,
          data: {
            'refresh_token': refreshToken,
            'session': ?session,
          },
        ),
      );

  @override
  Future<VerificationChallenge> requestEmailSignIn(String email) async =>
      VerificationChallenge.fromJson(
        await _client.post(
          '/auth/email/login',
          allowRefresh: false,
          data: {'email': email},
        ),
      );

  @override
  Future<AuthSession> verifyEmailSignIn(String email, String otp) async =>
      _saveTokenResponse(
        await _client.post(
          '/auth/email/login/verify',
          allowRefresh: false,
          data: {'email': email, 'otp': otp},
        ),
      );

  @override
  Future<VerificationChallenge> requestEmailVerification(String email) async =>
      VerificationChallenge.fromJson(
        await _client.post('/me/email/verification', data: {'email': email}),
      );

  @override
  Future<UserProfile> verifyEmail(String email, String otp) async {
    final body = await _client.post(
      '/me/email/verify',
      data: {'email': email, 'otp': otp},
    );
    return UserProfile.fromJson(_json(body, 'user'));
  }

  Future<AuthSession> _saveTokenResponse(Map<String, Object?> body) async {
    final stored = StoredTokens(
      accessToken: body['access_token']! as String,
      refreshToken: body['refresh_token']! as String,
    );
    _tokens = stored;
    _client.authorize(stored.accessToken);
    final session = _session(UserProfile.fromJson(_json(body, 'user')), stored);
    await _sessions.write(stored);
    return session;
  }

  Future<String?> _refreshAccessToken() {
    final active = _refreshing;
    if (active != null) return active;
    final future = _performRefresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<String?> _performRefresh() async {
    final refresh = _tokens?.refreshToken;
    if (refresh == null) return null;
    try {
      final body = await _client.post(
        '/auth/refresh',
        allowRefresh: false,
        data: {'refresh_token': refresh},
      );
      return (await _saveTokenResponse(body)).accessToken;
    } on AppException {
      _tokens = null;
      await _sessions.clear();
      return null;
    }
  }

  AuthSession _session(UserProfile user, StoredTokens tokens) => AuthSession(
        user: user,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

  @override
  Future<void> logout() async {
    final refresh = _tokens?.refreshToken;
    if (refresh != null) {
      try {
        await _client.post('/auth/logout', allowRefresh: false, data: {'refresh_token': refresh});
      } on AppException {
        // Local logout must still succeed if the network is unavailable.
      }
    }
    _tokens = null;
    _client.authorize(null);
    await _sessions.clear();
  }

  @override
  Future<Dashboard> dashboard() async => Dashboard.fromJson(await _client.get('/dashboard'));

  @override
  Future<FplTeam> linkTeam(int entryId) async =>
      FplTeam.fromJson(await _client.post('/fpl-team/link', data: {'entry_id': entryId}));

  @override
  Future<FplManager> validateTeam(int entryId) async => FplManager.fromJson(
        await _client.post('/fpl-team/validate', data: {'entry_id': entryId}),
      );

  @override
  Future<List<Pool>> pools({int? gameweek}) async {
    final body = await _client.get('/pools', query: {
      'gameweek': ?gameweek,
    });
    return _list(body, 'items').map((item) => Pool.fromJson(item)).toList();
  }

  @override
  Future<Pool> pool(String id) async => Pool.fromJson(await _client.get('/pools/$id'));

  @override
  Future<Pool> createPool(CreatePoolCommand command) async => Pool.fromJson(
        await _client.post(
          '/pools',
          idempotencyKey: _uuid.v4(),
          data: {
            'name': command.name,
            'gameweek': command.gameweek,
            'stake_cents': command.stakeCents,
            if (command.rules.isNotEmpty) 'rules': command.rules,
            'draw_method': command.drawMethod.wireValue,
            // The server makes every pool a user creates private and lets
            // anyone with the invite code enter; these two say the same.
            'visibility': 'private',
            'approval_required': false,
            'max_members': command.maxMembers,
          },
        ),
      );

  @override
  Future<Pool> joinPool(String id) async => Pool.fromJson(
        await _client.post('/pools/$id/join', idempotencyKey: _uuid.v4()),
      );

  @override
  Future<Pool> leavePool(String id) async => Pool.fromJson(
        await _client.post('/pools/$id/leave', idempotencyKey: _uuid.v4()),
      );

  @override
  Future<Pool> poolByInvite(String code) async => Pool.fromJson(
        await _client.get('/pools/invite/${Uri.encodeComponent(code)}'),
      );

  @override
  Future<Pool> joinPoolByInvite(String code) async => Pool.fromJson(
        await _client.post(
          '/pools/invite/${Uri.encodeComponent(code)}/join',
          idempotencyKey: _uuid.v4(),
        ),
      );

  @override
  Future<Pool> updatePool(
    String id, {
    required String name,
    required int stakeCents,
    required PoolDrawMethod drawMethod,
    String? rules,
    int? maxMembers,
  }) async =>
      Pool.fromJson(
        await _client.patch(
          '/pools/$id',
          data: {
            'name': name,
            'stake_cents': stakeCents,
            'rules': ?rules,
            'draw_method': drawMethod.wireValue,
            // Zero tells the server to remove the entry limit.
            'max_members': maxMembers ?? 0,
          },
        ),
      );

  @override
  Future<void> deletePool(String id, {required int feeCents}) async {
    await _client.delete('/pools/$id?fee_cents=$feeCents');
  }

  @override
  Future<Pool> resetPoolInvite(String id) async =>
      Pool.fromJson(await _client.post('/pools/$id/invite/reset'));

  @override
  Future<List<AppNotification>> notifications() async {
    final body = await _client.get('/notifications');
    return _list(body, 'items').map(AppNotification.fromJson).toList();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _client.patch('/notifications/$id/read');
  }

  @override
  Future<List<Challenge>> challenges() async {
    final body = await _client.get('/challenges');
    return _list(body, 'items').map(Challenge.fromJson).toList();
  }

  @override
  Future<Challenge> createChallenge({
    required int opponentTeamId,
    required int gameweek,
    required int stakeCents,
  }) async =>
      Challenge.fromJson(await _client.post(
        '/challenges',
        idempotencyKey: _uuid.v4(),
        data: {
          'opponent_team_id': opponentTeamId,
          'gameweek': gameweek,
          'stake_cents': stakeCents,
        },
      ));

  @override
  Future<WalletSummary> wallet() async => WalletSummary.fromJson(await _client.get('/wallet'));

  @override
  Future<PoolTerms> poolTerms() async {
    try {
      return PoolTerms.fromJson(await _client.get('/pools/terms'));
    } on ValidationException catch (error) {
      // A server from before the fee could be changed: it charges 5%.
      if (error.code != null) rethrow;
      return const PoolTerms();
    }
  }

  @override
  Future<WalletBalance> walletBalance() async {
    if (!_balanceEndpointMissing) {
      try {
        return WalletBalance.fromJson(await _client.get('/wallet/balance'));
      } on ValidationException catch (error) {
        // A refusal with no error code is the server saying the address
        // does not exist. Anything else is a real answer and is passed on.
        if (error.code != null) rethrow;
        _balanceEndpointMissing = true;
      }
    }
    final full = await wallet();
    return WalletBalance(
      availableCents: full.availableCents,
      lockedCents: full.lockedCents,
    );
  }

  @override
  Future<WalletSummary> creditWallet(int amountCents) async => WalletSummary.fromJson(
        await _client.post(
          '/wallet/dev-credit',
          idempotencyKey: _uuid.v4(),
          data: {'amount_cents': amountCents},
        ),
      );

  @override
  Future<Payment> initializePayment({
    required int amountCents,
    required String provider,
    required String callbackUrl,
    required String cancelUrl,
  }) async => Payment.fromJson(
        await _client.post(
          '/payments',
          idempotencyKey: _uuid.v4(),
          data: {
            'provider': provider,
            'amount_cents': amountCents,
            'currency': 'NGN',
            'callback_url': callbackUrl,
            'cancel_url': cancelUrl,
          },
        ),
      );

  @override
  Future<Payment> verifyPayment(String reference) async =>
      Payment.fromJson(await _client.get('/payments/$reference'));

  @override
  Future<List<Bank>> banks() async {
    final body = await _client.get('/banks');
    return _list(body, 'items').map(Bank.fromJson).toList();
  }

  @override
  Future<BankAccount?> bankAccount() async {
    final body = await _client.get('/bank-account');
    return BankAccount.maybeFrom(body['bank_account']);
  }

  @override
  Future<BankAccount> resolveBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final body = await _client.post(
      '/bank-account/resolve',
      data: {'bank_code': bankCode, 'account_number': accountNumber},
    );
    return BankAccount.fromJson(_json(body, 'bank_account'));
  }

  @override
  Future<BankAccount> saveBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final body = await _client.put(
      '/bank-account',
      data: {'bank_code': bankCode, 'account_number': accountNumber},
    );
    return BankAccount.fromJson(_json(body, 'bank_account'));
  }

  @override
  Future<void> deleteBankAccount() async {
    await _client.delete('/bank-account');
  }

  @override
  Future<WithdrawalOverview> withdrawals() async =>
      WithdrawalOverview.fromJson(await _client.get('/withdrawals'));

  @override
  Future<Withdrawal> requestWithdrawal({
    required int amountCents,
    required String idempotencyKey,
  }) async =>
      Withdrawal.fromJson(
        await _client.post(
          '/withdrawals',
          idempotencyKey: idempotencyKey,
          data: {'amount_cents': amountCents},
        ),
      );

  @override
  Future<AppSettings> updateSettings(AppSettings settings) async =>
      AppSettings.fromJson(await _client.put('/settings', data: settings.toJson()));
}

Map<String, Object?> _json(Map<String, Object?> source, String key) =>
    Map<String, Object?>.from(source[key]! as Map<Object?, Object?>);

List<Map<String, Object?>> _list(Map<String, Object?> source, String key) =>
    (source[key] as List<Object?>? ?? const [])
        .map((item) => Map<String, Object?>.from(item! as Map<Object?, Object?>))
        .toList();
