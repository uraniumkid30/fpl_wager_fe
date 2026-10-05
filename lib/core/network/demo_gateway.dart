import 'package:fpl_wager/core/network/app_gateway.dart';
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
    Pool(id: 'auto-1000', name: 'GW2 Auto Pool · ₦1,000', gameweek: 2, stakeCents: 100000, prizePoolCents: 285000, status: 'open', memberCount: 3, maxMembers: 10000, poolKind: 'auto', drawMethod: PoolDrawMethod.split, autoSeriesNo: 1, deadline: DateTime.now().add(const Duration(days: 3, hours: 18)), membershipStatus: 'active'),
    Pool(id: 'auto-2000', name: 'GW2 Auto Pool · ₦2,000', gameweek: 2, stakeCents: 200000, prizePoolCents: 380000, status: 'open', memberCount: 2, maxMembers: 10000, poolKind: 'auto', autoSeriesNo: 1, deadline: DateTime.now().add(const Duration(days: 3, hours: 18))),
    Pool(id: 'auto-5000', name: 'GW2 Auto Pool · ₦5,000', gameweek: 2, stakeCents: 500000, prizePoolCents: 0, status: 'open', memberCount: 0, maxMembers: 10000, poolKind: 'auto', autoSeriesNo: 1, deadline: DateTime.now().add(const Duration(days: 3, hours: 18))),
    Pool(id: 'pool-3', name: 'Chris pool', gameweek: 2, stakeCents: 100000, prizePoolCents: 0, status: 'draft', memberCount: 0, rules: 'Highest score in the gameweek wins.', deadline: DateTime.now().add(const Duration(days: 3, hours: 18)), approvalRequired: true),
  ];
  BankAccount? _bankAccount;
  final List<Withdrawal> _withdrawals = [];
  static const _demoBanks = [
    Bank(name: 'Access Bank', code: '044'),
    Bank(name: 'Guaranty Trust Bank', code: '058'),
    Bank(name: 'Kuda Bank', code: '50211'),
    Bank(name: 'Zenith Bank', code: '057'),
  ];
  final List<Challenge> _challenges = [];
  final List<AppNotification> _notifications = [];

  Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 350));
  UserProfile _user(String email, [String name = 'Dean Miles']) => UserProfile(id: 'demo-user', fullName: name, email: email, fplEntryId: 1234567);
  AuthSession _newSession(UserProfile user) => AuthSession(user: user, accessToken: 'demo-access', refreshToken: 'demo-refresh');

  @override
  Future<AuthSession?> restoreSession() async { await _wait(); return _session; }
  @override
  Future<AuthSession> continueWithFpl({required String refreshToken, Map<String, Object?>? session}) async { await _wait(); return _session = _newSession(_user('demo-manager@fplwager.local', 'Demo Manager')); }
  @override
  Future<VerificationChallenge> requestEmailSignIn(String email) async { await _wait(); return VerificationChallenge(message: 'Enter 123456 in demo mode.', verificationPath: '/v1/auth/email/login/verify', expiresInSeconds: 600); }
  @override
  Future<AuthSession> verifyEmailSignIn(String email, String otp) async { await _wait(); return _session = _newSession(UserProfile(id: 'demo-user', fullName: 'Demo Manager', email: email, emailVerified: true, fplEntryId: 1234567)); }
  @override
  Future<VerificationChallenge> requestEmailVerification(String email) async { await _wait(); return VerificationChallenge(message: 'Enter 123456 in demo mode.', verificationPath: '/v1/me/email/verify', expiresInSeconds: 600); }
  @override
  Future<UserProfile> verifyEmail(String email, String otp) async { await _wait(); final current = _session?.user ?? _user(email); final updated = UserProfile(id: current.id, fullName: current.fullName, email: email, emailVerified: true, fplEntryId: current.fplEntryId); _session = _newSession(updated); return updated; }
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
  Future<Pool> pool(String id) async { await _wait(); final item = _pools.firstWhere((p) => p.id == id); return _copyPool(item, leaderboard: const [PoolMember(displayName: 'Olawale Mosuro', rank: 1, points: 0), PoolMember(displayName: 'Chuks Paul', rank: 2, points: 0), PoolMember(displayName: 'Dean Miles (you)', rank: 3, points: 0)], prizeSplit: [Prize(place: 1, amountCents: item.prizePoolCents, percent: 100)]); }
  @override
  Future<Pool> createPool(CreatePoolCommand command) async { await _wait(); final item = Pool(id: _uuid.v4(), name: command.name, gameweek: command.gameweek, stakeCents: command.stakeCents, prizePoolCents: 0, status: 'draft', memberCount: 0, deadline: DateTime.now().add(const Duration(days: 4)), rules: command.rules, drawMethod: command.drawMethod, approvalRequired: command.approvalRequired); _pools.add(item); return item; }
  @override
  Future<Pool> joinPool(String id) async { await _wait(); final index = _pools.indexWhere((p) => p.id == id); final old = _pools[index]; final status = old.approvalRequired ? 'pending' : 'active'; final updated = _copyPool(old, prizePoolCents: old.prizePoolCents + old.stakeCents, memberCount: old.memberCount + 1, membershipStatus: status); _pools[index] = updated; _balance -= old.stakeCents; return updated; }
  @override
  Future<Pool> leavePool(String id) async { await _wait(); final index = _pools.indexWhere((p) => p.id == id); final old = _pools[index]; final updated = _copyPool(old, prizePoolCents: old.prizePoolCents - old.stakeCents, memberCount: old.memberCount - 1, clearMembership: true); _pools[index] = updated; _balance += old.stakeCents; return updated; }
  @override
  Future<List<AppNotification>> notifications() async { await _wait(); return List.unmodifiable(_notifications); }
  @override
  Future<void> markNotificationRead(String id) async { await _wait(); }
  @override
  Future<List<Challenge>> challenges() async { await _wait(); return List.unmodifiable(_challenges); }
  @override
  Future<Challenge> createChallenge({required int opponentTeamId, required int gameweek, required int stakeCents}) async { await _wait(); final item = Challenge(id: _uuid.v4(), opponentName: 'FPL manager', opponentTeamId: opponentTeamId, gameweek: gameweek, stakeCents: stakeCents, status: 'pending'); _challenges.insert(0, item); _balance -= stakeCents; return item; }
  @override
  Future<WalletSummary> wallet() async { await _wait(); return WalletSummary(availableCents: _balance, lockedCents: 100000, ledger: List.unmodifiable(_ledger)); }
  @override
  Future<WalletSummary> creditWallet(int amountCents) async { await _wait(); _balance += amountCents; _ledger.insert(0, LedgerEntry(id: _uuid.v4(), kind: 'top_up', description: 'Top up', amountCents: amountCents, createdAt: DateTime.now())); return wallet(); }
  @override
  Future<Payment> initializePayment({required int amountCents, required String provider, required String callbackUrl, required String cancelUrl}) async { await _wait(); return Payment(id: _uuid.v4(), userId: 'demo-user', provider: provider, credentialMode: 'test', reference: 'demo-payment', amountCents: amountCents, currency: 'NGN', status: 'pending', checkoutUrl: callbackUrl); }
  @override
  Future<Payment> verifyPayment(String reference) async { await _wait(); return Payment(id: 'demo-payment-id', userId: 'demo-user', provider: 'paystack', credentialMode: 'test', reference: reference, amountCents: 100000, currency: 'NGN', status: 'succeeded'); }
  @override
  Future<List<Bank>> banks() async { await _wait(); return _demoBanks; }
  @override
  Future<BankAccount?> bankAccount() async { await _wait(); return _bankAccount; }
  @override
  Future<BankAccount> resolveBankAccount({required String bankCode, required String accountNumber}) async { await _wait(); return BankAccount(bankCode: bankCode, bankName: _demoBanks.firstWhere((bank) => bank.code == bankCode, orElse: () => _demoBanks.first).name, accountNumber: accountNumber, accountName: (_session?.user.fullName ?? 'Demo Manager').toUpperCase()); }
  @override
  Future<BankAccount> saveBankAccount({required String bankCode, required String accountNumber}) async => _bankAccount = await resolveBankAccount(bankCode: bankCode, accountNumber: accountNumber);
  @override
  Future<void> deleteBankAccount() async { await _wait(); _bankAccount = null; }
  @override
  Future<WithdrawalOverview> withdrawals() async { await _wait(); return WithdrawalOverview(items: List.unmodifiable(_withdrawals), minimumCents: 100000); }
  @override
  Future<Withdrawal> requestWithdrawal({required int amountCents, required String idempotencyKey}) async { await _wait(); final item = Withdrawal(id: _uuid.v4(), reference: 'wd_demo', amountCents: amountCents, status: 'pending_approval', createdAt: DateTime.now(), bank: _bankAccount); _withdrawals.insert(0, item); _balance -= amountCents; _ledger.insert(0, LedgerEntry(id: _uuid.v4(), kind: 'withdrawal', description: 'Withdrawal to ${_bankAccount?.summary ?? 'bank'}', amountCents: -amountCents, createdAt: DateTime.now())); return item; }
  @override
  Future<AppSettings> updateSettings(AppSettings settings) async { await _wait(); return _settings = settings; }
}

Pool _copyPool(
  Pool source, {
  int? prizePoolCents,
  int? memberCount,
  String? membershipStatus,
  bool clearMembership = false,
  List<PoolMember>? leaderboard,
  List<Prize>? prizeSplit,
}) =>
    Pool(
      id: source.id,
      name: source.name,
      gameweek: source.gameweek,
      stakeCents: source.stakeCents,
      prizePoolCents: prizePoolCents ?? source.prizePoolCents,
      status: source.status,
      memberCount: memberCount ?? source.memberCount,
      deadline: source.deadline,
      membershipStatus:
          clearMembership ? null : membershipStatus ?? source.membershipStatus,
      approvalRequired: source.approvalRequired,
      poolKind: source.poolKind,
      rules: source.rules,
      drawMethod: source.drawMethod,
      inviteCode: source.inviteCode,
      maxMembers: source.maxMembers,
      autoSeriesNo: source.autoSeriesNo,
      leaderboard: leaderboard ?? source.leaderboard,
      prizeSplit: prizeSplit ?? source.prizeSplit,
    );
