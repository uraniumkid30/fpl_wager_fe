import 'package:fpl_wager/core/errors/app_exception.dart';
import 'package:fpl_wager/core/network/api_client.dart';
import 'package:fpl_wager/core/network/app_gateway.dart';
import 'package:fpl_wager/core/storage/session_store.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';
import 'package:fpl_wager/features/challenges/domain/challenge.dart';
import 'package:fpl_wager/features/dashboard/domain/dashboard.dart';
import 'package:fpl_wager/features/fpl_team/domain/fpl_team.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/settings/domain/app_settings.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';
import 'package:fpl_wager/features/payments/domain/payment.dart';
import 'package:fpl_wager/features/notifications/domain/app_notification.dart';
import 'package:uuid/uuid.dart';

class RemoteGateway implements AppGateway {
  RemoteGateway(this._client, this._sessions) {
    _client.setRefreshHandler(_refreshAccessToken);
  }
  final ApiClient _client;
  final SessionStore _sessions;
  final _uuid = const Uuid();
  StoredTokens? _tokens;
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
  Future<VerificationChallenge> requestLogin(
    String email,
    String password,
  ) async => VerificationChallenge.fromJson(
        await _client.post(
          '/auth/login',
          allowRefresh: false,
          data: {'email': email, 'password': password},
        ),
      );

  @override
  Future<AuthSession> verifyLogin(String email, String otp) async =>
      _saveTokenResponse(
        await _client.post(
          '/auth/login/verify',
          allowRefresh: false,
          data: {'email': email, 'otp': otp},
        ),
      );

  @override
  Future<AuthSession> continueWithFpl({
    required String refreshToken,
    int? entryId,
  }) async => _saveTokenResponse(
        await _client.post(
          '/auth/fpl',
          allowRefresh: false,
          data: {
            'refresh_token': refreshToken,
            if (entryId != null) 'entry_id': entryId,
          },
        ),
      );

  @override
  Future<VerificationChallenge> requestRegistration({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async => VerificationChallenge.fromJson(
        await _client.post(
          '/auth/register',
          allowRefresh: false,
          data: {
            'full_name': fullName,
            'email': email,
            'phone': phone,
            'password': password,
          },
        ),
      );

  @override
  Future<AuthSession> verifyRegistration(String email, String otp) async =>
      _saveTokenResponse(
        await _client.post(
          '/auth/register/verify',
          allowRefresh: false,
          data: {'email': email, 'otp': otp},
        ),
      );

  @override
  Future<void> requestPasswordReset(String email) async {
    await _client.post(
      '/auth/password/forgot',
      allowRefresh: false,
      data: {'email': email},
    );
  }

  @override
  Future<String> verifyPasswordOtp(String email, String otp) async {
    final body = await _client.post(
      '/auth/password/otp/verify',
      allowRefresh: false,
      data: {'email': email, 'otp': otp},
    );
    return body['verification_token']! as String;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/password/reset',
      allowRefresh: false,
      data: {
        'email': email,
        'token': token,
        'new_password': newPassword,
      },
    );
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
      if (gameweek != null) 'gameweek': gameweek,
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
            'rules': command.rules,
            'draw_method': command.drawMethod.wireValue,
            'visibility': 'public',
            'approval_required': command.approvalRequired,
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
  }) async => Payment.fromJson(
        await _client.post(
          '/payments',
          idempotencyKey: _uuid.v4(),
          data: {
            'provider': provider,
            'amount_cents': amountCents,
            'currency': 'NGN',
            'callback_url': callbackUrl,
          },
        ),
      );

  @override
  Future<Payment> verifyPayment(String reference) async =>
      Payment.fromJson(await _client.get('/payments/$reference'));

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
