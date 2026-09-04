import 'package:fpl_wager/core/network/app_gateway.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';
import 'package:fpl_wager/features/challenges/domain/challenge.dart';
import 'package:fpl_wager/features/dashboard/domain/dashboard.dart';
import 'package:fpl_wager/features/fpl_team/domain/fpl_team.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/settings/domain/app_settings.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';
import 'package:fpl_wager/features/payments/domain/payment.dart';
import 'package:uuid/uuid.dart';

class DemoGateway implements AppGateway {
  final _uuid = const Uuid();
  AuthSession? _session;
  AppSettings _settings = const AppSettings();
  FplTeam? _team;
  int _balance = 300000;
  final List<LedgerEntry> _ledger = [
    LedgerEntry(id: 'l1', kind: 'top_up', description: 'Top up', amountCents: 200000, createdAt: DateTime.now().subtract(const Duration(days: 1))),
    LedgerEntry(id: 'l2', kind: 'pool_stake', description: 'Stake · GW2 pool', amountCents: -100000, createdAt: DateTime.now().subtract(const Duration(hours: 5))),
    LedgerEntry(id: 'l3', kind: 'top_up', description: 'Top up', amountCents: 200000, createdAt: DateTime.now().subtract(const Duration(days: 3))),
  ];
  final List<Pool> _pools = [
    Pool(id: 'pool-1', name: 'GW2 · ₦1,000 pool', gameweek: 2, stakeCents: 100000, prizePoolCents: 285000, status: 'open', memberCount: 3, deadline: DateTime.now().add(const Duration(days: 3, hours: 18)), membershipStatus: 'active'),
    Pool(id: 'pool-2', name: 'GW2 · ₦2,000 pool', gameweek: 2, stakeCents: 200000, prizePoolCents: 380000, status: 'open', memberCount: 2, deadline: DateTime.now().add(const Duration(days: 3, hours: 18))),
    Pool(id: 'pool-3', name: 'Chris pool', gameweek: 2, stakeCents: 50000, prizePoolCents: 100000, status: 'open', memberCount: 1, deadline: DateTime.now().add(const Duration(days: 3, hours: 18)), membershipStatus: 'pending', approvalRequired: true),
  ];
  final List<Challenge> _challenges = [];

  Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 350));
  UserProfile _user(String email, [String name = 'Dean Miles']) => UserProfile(id: 'demo-user', fullName: name, email: email);
  AuthSession _newSession(UserProfile user) => AuthSession(user: user, accessToken: 'demo-access', refreshToken: 'demo-refresh');

  @override
  Future<AuthSession?> restoreSession() async { await _wait(); return _session; }
  @override
  Future<VerificationChallenge> requestLogin(String email, String password) async { await _wait(); return const VerificationChallenge(message: 'Enter 123456 in demo mode.', verificationPath: '/v1/auth/login/verify', expiresInSeconds: 600); }
  @override
  Future<AuthSession> verifyLogin(String email, String otp) async { await _wait(); return _session = _newSession(_user(email)); }
  @override
  Future<VerificationChallenge> requestRegistration({required String fullName, required String email, required String phone, required String password}) async { await _wait(); return const VerificationChallenge(message: 'Enter 123456 in demo mode.', verificationPath: '/v1/auth/register/verify', expiresInSeconds: 600); }
  @override
  Future<AuthSession> verifyRegistration(String email, String otp) async { await _wait(); return _session = _newSession(_user(email)); }
  @override
  Future<void> requestPasswordReset(String email) async { await _wait(); }
  @override
  Future<String> verifyPasswordOtp(String email, String otp) async { await _wait(); return 'demo-reset-token'; }
  @override
  Future<void> resetPassword({required String email, required String token, required String newPassword}) async { await _wait(); }
  @override
  Future<void> logout() async { await _wait(); _session = null; }

  @override
  Future<Dashboard> dashboard() async { await _wait(); return Dashboard(user: _session?.user ?? _user('dean@example.com'), wallet: await wallet(), activeWagers: _pools.where((p) => p.hasJoined).length, currentGameweek: 2, deadline: DateTime.now().add(const Duration(days: 3, hours: 18)), team: _team); }
  @override
  Future<FplTeam> linkTeam(int entryId) async { await _wait(); return _team = FplTeam(entryId: entryId, teamName: 'Gameweek Architects', managerName: _session?.user.fullName ?? 'Dean Miles', overallRank: 128450); }
  @override
  Future<FplManager> validateTeam(int entryId) async { await _wait(); return FplManager(entryId: entryId, teamName: 'Gameweek Architects', firstName: 'Dean', lastName: 'Miles', overallPoints: 132, gameweekPoints: 61, overallRank: 128450, currentGameweek: 2); }
  @override
  Future<List<Pool>> pools({int? gameweek}) async { await _wait(); return _pools.where((p) => gameweek == null || p.gameweek == gameweek).toList(); }
  @override
  Future<Pool> pool(String id) async { await _wait(); final item = _pools.firstWhere((p) => p.id == id); return Pool(id: item.id, name: item.name, gameweek: item.gameweek, stakeCents: item.stakeCents, prizePoolCents: item.prizePoolCents, status: item.status, memberCount: item.memberCount, deadline: item.deadline, membershipStatus: item.membershipStatus, approvalRequired: item.approvalRequired, leaderboard: const [PoolMember(displayName: 'Olawale Mosuro', rank: 1, points: 0), PoolMember(displayName: 'Chuks Paul', rank: 2, points: 0), PoolMember(displayName: 'Dean Miles (you)', rank: 3, points: 0)], prizeSplit: [Prize(place: 1, amountCents: item.prizePoolCents, percent: 100)]); }
  @override
  Future<Pool> createPool(CreatePoolCommand command) async { await _wait(); final item = Pool(id: _uuid.v4(), name: command.name, gameweek: command.gameweek, stakeCents: command.stakeCents, prizePoolCents: command.stakeCents, status: 'open', memberCount: 1, deadline: DateTime.now().add(const Duration(days: 4)), membershipStatus: 'active', approvalRequired: command.approvalRequired); _pools.insert(0, item); _balance -= command.stakeCents; return item; }
  @override
  Future<Pool> joinPool(String id) async { await _wait(); final index = _pools.indexWhere((p) => p.id == id); final old = _pools[index]; final status = old.approvalRequired ? 'pending' : 'active'; final updated = Pool(id: old.id, name: old.name, gameweek: old.gameweek, stakeCents: old.stakeCents, prizePoolCents: old.prizePoolCents + old.stakeCents, status: old.status, memberCount: old.memberCount + 1, deadline: old.deadline, membershipStatus: status, approvalRequired: old.approvalRequired); _pools[index] = updated; _balance -= old.stakeCents; return updated; }
  @override
  Future<Pool> leavePool(String id) async { await _wait(); final index = _pools.indexWhere((p) => p.id == id); final old = _pools[index]; final updated = Pool(id: old.id, name: old.name, gameweek: old.gameweek, stakeCents: old.stakeCents, prizePoolCents: old.prizePoolCents - old.stakeCents, status: old.status, memberCount: old.memberCount - 1, deadline: old.deadline, approvalRequired: old.approvalRequired); _pools[index] = updated; _balance += old.stakeCents; return updated; }
  @override
  Future<List<Challenge>> challenges() async { await _wait(); return List.unmodifiable(_challenges); }
  @override
  Future<Challenge> createChallenge({required int opponentTeamId, required int gameweek, required int stakeCents}) async { await _wait(); final item = Challenge(id: _uuid.v4(), opponentName: 'FPL manager', opponentTeamId: opponentTeamId, gameweek: gameweek, stakeCents: stakeCents, status: 'pending'); _challenges.insert(0, item); _balance -= stakeCents; return item; }
  @override
  Future<WalletSummary> wallet() async { await _wait(); return WalletSummary(availableCents: _balance, lockedCents: 100000, ledger: List.unmodifiable(_ledger)); }
  @override
  Future<WalletSummary> creditWallet(int amountCents) async { await _wait(); _balance += amountCents; _ledger.insert(0, LedgerEntry(id: _uuid.v4(), kind: 'top_up', description: 'Top up', amountCents: amountCents, createdAt: DateTime.now())); return wallet(); }
  @override
  Future<Payment> initializePayment({required int amountCents, required String provider, required String callbackUrl}) async { await _wait(); return Payment(id: _uuid.v4(), userId: 'demo-user', provider: provider, credentialMode: 'test', reference: 'demo-payment', amountCents: amountCents, currency: 'NGN', status: 'pending', checkoutUrl: callbackUrl); }
  @override
  Future<Payment> verifyPayment(String reference) async { await _wait(); return Payment(id: 'demo-payment-id', userId: 'demo-user', provider: 'paystack', credentialMode: 'test', reference: reference, amountCents: 100000, currency: 'NGN', status: 'succeeded'); }
  @override
  Future<AppSettings> updateSettings(AppSettings settings) async { await _wait(); return _settings = settings; }
}
