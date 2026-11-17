import * as Crypto from 'expo-crypto';

import { AppException } from './errors';
import {
  Campaign,
  parseCampaign,
  AppNotification,
  AppSettings,
  AuthSession,
  Bank,
  BankAccount,
  Challenge,
  FplTeam,
  LedgerEntry,
  QrLogin,
  QrPoll,
  UserProfile,
  WebLink,
  Withdrawal,
  bankSummary,
} from '@/domain/models';
import { CreatePoolCommand, Pool, PoolTerms, PoolView, hasJoined, isFinished, parsePool } from '@/domain/pool';
import { AppGateway } from './gateway';

const uuid = () => Crypto.randomUUID();
const wait = () => new Promise((r) => setTimeout(r, 350));
const inDays = (d: number, h = 0) => new Date(Date.now() + (d * 24 + h) * 3600_000).toISOString();
const ago = (h: number) => new Date(Date.now() - h * 3600_000);

const banks: Bank[] = [
  { name: 'Access Bank', code: '044' },
  { name: 'Guaranty Trust Bank', code: '058' },
  { name: 'Kuda Bank', code: '50211' },
  { name: 'Zenith Bank', code: '057' },
];

/** The Royal Rumble as the API seeds it (migration 000016). */
const demoCampaigns: Campaign[] = [
  parseCampaign({
    id: 'c-rumble',
    slug: 'royal-rumble',
    badge: 'Season challenge',
    title: 'Royal Rumble',
    tagline: 'One pool. 38 gameweeks. The lowest score drops out until one manager is left standing.',
    body:
      "The Royal Rumble is FPLboardman's season-long elimination game. Every manager enters before the season starts, and each gameweek the lowest-scoring manager is knocked out.\n\nSurvive the drop week after week and be the last manager standing at Gameweek 38.",
    rules: [
      'Weekly elimination until there is a last manager standing at Gameweek 38.',
      'Everyone must be in the pool at the start of the season. Entries close at the Gameweek 1 deadline.',
      "Hits don't count: make as many transfers as you want.",
      'Tie-breakers: captain points, then goals scored by your team, then overall rank. The lower manager drops.',
    ],
    highlights: [
      { label: 'Format', value: 'Elimination' },
      { label: 'Runs', value: 'GW1 – GW38' },
      { label: 'Transfers', value: 'No hits' },
    ],
    theme: 'rumble',
    cta_label: 'See how it works',
    cta_kind: 'none',
    placements: ['home', 'pools'],
    countdown_to: inDays(9, 5),
    countdown_label: 'Entries close in',
  }),
];

const pool = (j: Record<string, unknown>) =>
  parsePool({ prize_pool_cents: 0, member_count: 0, status: 'open', deadline: inDays(3, 18), ...j });

/** In-memory data for USE_DEMO_DATA builds (a port of the Flutter DemoGateway). */
export class DemoGateway implements AppGateway {
  private session: AuthSession | null = null;
  private team: FplTeam | null = null;
  private balance = 300000;
  private ledger: LedgerEntry[] = [
    { id: 'l1', kind: 'top_up', description: 'Top up', amountCents: 200000, createdAt: ago(24), meta: {} },
    { id: 'l2', kind: 'pool_stake', description: 'Stake · GW2 pool', amountCents: -100000, createdAt: ago(5), meta: {} },
    { id: 'l3', kind: 'top_up', description: 'Top up', amountCents: 200000, createdAt: ago(72), meta: {} },
  ];
  private poolItems: Pool[] = [
    pool({ id: 'auto-1000', name: 'GW2 Auto Pool - Starter', gameweek: 2, stake_cents: 100000, prize_pool_cents: 285000, member_count: 3, max_members: 10000, pool_kind: 'auto', auto_series_no: 1, membership_status: 'active' }),
    pool({ id: 'auto-2000', name: 'GW2 Auto Pool - Novice', gameweek: 2, stake_cents: 200000, prize_pool_cents: 380000, member_count: 2, max_members: 10000, pool_kind: 'auto', auto_series_no: 1 }),
    pool({ id: 'auto-5000', name: 'GW2 Auto Pool - Expert', gameweek: 2, stake_cents: 500000, max_members: 10000, pool_kind: 'auto', auto_series_no: 1 }),
    pool({ id: 'pool-3', name: 'Chris pool', gameweek: 2, stake_cents: 100000, status: 'draft', rules: 'Highest score in the gameweek wins.', approval_required: true }),
  ];
  private bank: BankAccount | null = null;
  private withdrawalItems: Withdrawal[] = [];
  private challengeItems: Challenge[] = [];
  private notificationItems: AppNotification[] = [];
  private links: WebLink[] = [];

  private user(email: string, name = 'Dean Miles'): UserProfile {
    return { id: 'demo-user', fullName: name, email, phone: '', status: 'active', role: 'user', emailVerified: false, fplEntryId: 1234567 };
  }
  private newSession(user: UserProfile): AuthSession {
    return { user, accessToken: 'demo-access', refreshToken: 'demo-refresh' };
  }

  async restoreSession() {
    await wait();
    return this.session;
  }
  async continueWithFpl() {
    await wait();
    return (this.session = this.newSession(this.user('demo-manager@fplboardman.local', 'Demo Manager')));
  }
  async requestEmailSignIn() {
    await wait();
    return { message: 'Enter 123456 in demo mode.', verificationPath: '/v1/auth/email/login/verify', expiresInSeconds: 600 };
  }
  async verifyEmailSignIn(email: string) {
    await wait();
    return (this.session = this.newSession({ ...this.user(email, 'Demo Manager'), emailVerified: true }));
  }
  async requestEmailVerification() {
    await wait();
    return { message: 'Enter 123456 in demo mode.', verificationPath: '/v1/me/email/verify', expiresInSeconds: 600 };
  }
  async verifyEmail(email: string) {
    await wait();
    const updated = { ...(this.session?.user ?? this.user(email)), email, emailVerified: true };
    this.session = this.newSession(updated);
    return updated;
  }
  async createQrLogin(): Promise<QrLogin> {
    await wait();
    return { id: uuid(), code: uuid().replace(/-/g, ''), pollToken: 'demo', expiresAt: new Date(Date.now() + 120_000), linkDays: 90 };
  }
  async pollQrLogin(): Promise<QrPoll> {
    await wait();
    return { status: 'pending', session: null };
  }
  async scanQrLogin() {
    await wait();
    return { label: 'Chrome on macOS', linkDays: 90 };
  }
  async approveQrLogin() {
    await wait();
    const now = new Date();
    this.links.unshift({ id: uuid(), label: 'Chrome on macOS', createdAt: now, expiresAt: new Date(Date.now() + 90 * 86400_000), lastUsedAt: now });
  }
  async declineQrLogin() {
    await wait();
  }
  async webLinks() {
    await wait();
    return [...this.links];
  }
  async revokeWebLink(id: string) {
    await wait();
    this.links = this.links.filter((l) => l.id !== id);
  }
  async logout() {
    await wait();
    this.session = null;
  }
  async dashboard() {
    await wait();
    return {
      user: this.session?.user ?? this.user('dean@example.com'),
      wallet: await this.wallet(),
      activeWagers: this.poolItems.filter(hasJoined).length,
      currentGameweek: 2,
      deadline: new Date(inDays(3, 18)),
      team: this.team,
    };
  }
  async linkTeam(entryId: number) {
    await wait();
    return (this.team = { entryId, teamName: 'Gameweek Architects', managerName: this.session?.user.fullName ?? 'Dean Miles', overallRank: 128450 });
  }
  async validateTeam(entryId: number) {
    await wait();
    return { entryId, teamName: 'Gameweek Architects', firstName: 'Dean', lastName: 'Miles', overallPoints: 132, gameweekPoints: 61, overallRank: 128450, currentGameweek: 2 };
  }
  async pools(opts: { gameweek?: number; view?: PoolView } = {}) {
    await wait();
    return this.poolItems.filter(
      (p) =>
        (opts.gameweek == null || p.gameweek === opts.gameweek) &&
        (opts.view === 'past' ? p.status === 'settled' && hasJoined(p) : !isFinished(p)),
    );
  }
  async gameweekHistory() {
    await wait();
    return [
      {
        gameweek: 1, gameweekStatus: 'finished', deadline: null, points: 74, position: 3, managers: 41, poolsEntered: 1,
        stakedCents: 100000, wonCents: 185000, isFinal: true,
        pools: [{ id: 'past-1', name: 'GW1 Auto Pool · ₦1,000', poolKind: 'auto', status: 'settled', stakeCents: 100000, entrants: 41, points: 74, rank: 3, payoutCents: 185000 }],
      },
    ];
  }
  async pool(id: string) {
    await wait();
    const item = this.poolItems.find((p) => p.id === id) ?? this.poolItems[0];
    const member = (displayName: string, rank: number) => ({ displayName, rank, points: 0, userId: displayName, status: 'active', payoutCents: 0, projectedCents: 0, isMe: displayName.includes('(you)') });
    return {
      ...item,
      leaderboard: [member('Olawale Mosuro', 1), member('Chuks Paul', 2), member('Dean Miles (you)', 3)],
      prizeSplit: [{ place: 1, amountCents: item.prizePoolCents, percent: 100 }],
    };
  }
  async createPool(c: CreatePoolCommand) {
    await wait();
    const item = pool({ id: uuid(), name: c.name, gameweek: c.gameweek, stake_cents: c.stakeCents, status: 'draft', deadline: inDays(4), rules: c.rules ?? '', draw_method: c.drawMethod, approval_required: c.approvalRequired ?? false });
    this.poolItems.push(item);
    return item;
  }
  async joinPool(id: string) {
    await wait();
    const i = this.poolItems.findIndex((p) => p.id === id);
    const old = this.poolItems[i];
    const updated = { ...old, prizePoolCents: old.prizePoolCents + old.stakeCents, memberCount: old.memberCount + 1, membershipStatus: old.approvalRequired ? 'pending' : 'active' };
    this.poolItems[i] = updated;
    this.balance -= old.stakeCents;
    return updated;
  }
  async leavePool(id: string) {
    await wait();
    const i = this.poolItems.findIndex((p) => p.id === id);
    const old = this.poolItems[i];
    const updated = { ...old, prizePoolCents: old.prizePoolCents - old.stakeCents, memberCount: old.memberCount - 1, membershipStatus: null };
    this.poolItems[i] = updated;
    this.balance += old.stakeCents;
    return updated;
  }
  async poolByInvite() {
    await wait();
    return this.pool(this.poolItems[this.poolItems.length - 1].id);
  }
  async joinPoolByInvite() {
    return this.joinPool(this.poolItems[this.poolItems.length - 1].id);
  }
  async updatePool(id: string, a: Parameters<AppGateway['updatePool']>[1]) {
    await wait();
    const i = this.poolItems.findIndex((p) => p.id === id);
    const old = this.poolItems[i];
    return (this.poolItems[i] = { ...old, name: a.name, stakeCents: a.stakeCents, rules: a.rules ?? old.rules, drawMethod: a.drawMethod, maxMembers: a.maxMembers ?? null });
  }
  async deletePool(id: string, feeCents: number) {
    await wait();
    this.poolItems = this.poolItems.filter((p) => p.id !== id);
    this.balance -= feeCents;
  }
  async resetPoolInvite(id: string) {
    return this.pool(id);
  }
  async poolTerms() {
    return new PoolTerms();
  }
  async notifications() {
    await wait();
    return [...this.notificationItems];
  }
  async markNotificationRead() {
    await wait();
  }
  async challenges() {
    await wait();
    return [...this.challengeItems];
  }
  async createChallenge(a: { opponentTeamId: number; gameweek: number; stakeCents: number }) {
    await wait();
    const item = { id: uuid(), opponentName: 'FPL manager', opponentTeamId: a.opponentTeamId, gameweek: a.gameweek, stakeCents: a.stakeCents, status: 'accepted' };
    this.challengeItems.unshift(item);
    this.balance -= a.stakeCents;
    return item;
  }
  async wallet() {
    await wait();
    return { availableCents: this.balance, lockedCents: 100000, ledger: [...this.ledger] };
  }
  async walletBalance() {
    await wait();
    return { availableCents: this.balance, lockedCents: 100000 };
  }
  async creditWallet(amountCents: number) {
    await wait();
    this.balance += amountCents;
    this.ledger.unshift({ id: uuid(), kind: 'top_up', description: 'Top up', amountCents, createdAt: new Date(), meta: {} });
    return this.wallet();
  }
  async paymentOptions() {
    await wait();
    return { provider: 'globalpay', label: 'Zenith GlobalPay', available: true, minCents: 10000, maxCents: 100000000 };
  }
  async campaigns(placement: 'home' | 'pools') {
    await wait();
    return demoCampaigns.filter((c) => c.placements.includes(placement));
  }
  async campaign(slug: string) {
    await wait();
    const found = demoCampaigns.find((c) => c.slug === slug);
    if (!found) throw new AppException('Resource not found', 'validation', 'NOT_FOUND');
    return found;
  }
  async initializePayment(a: { amountCents: number; callbackUrl: string }) {
    await wait();
    return { id: uuid(), userId: 'demo-user', provider: 'globalpay', credentialMode: 'test', reference: 'demo-payment', amountCents: a.amountCents, currency: 'NGN', status: 'pending', checkoutUrl: a.callbackUrl };
  }
  async verifyPayment(reference: string) {
    await wait();
    return { id: 'demo-payment-id', userId: 'demo-user', provider: 'paystack', credentialMode: 'test', reference, amountCents: 100000, currency: 'NGN', status: 'succeeded', checkoutUrl: null };
  }
  async banks() {
    await wait();
    return banks;
  }
  async bankAccount() {
    await wait();
    return this.bank;
  }
  async resolveBankAccount(a: { bankCode: string; accountNumber: string }) {
    await wait();
    return {
      provider: '',
      bankCode: a.bankCode,
      bankName: (banks.find((b) => b.code === a.bankCode) ?? banks[0]).name,
      accountNumber: a.accountNumber,
      accountName: (this.session?.user.fullName ?? 'Demo Manager').toUpperCase(),
    };
  }
  async saveBankAccount(a: { bankCode: string; accountNumber: string }) {
    return (this.bank = await this.resolveBankAccount(a));
  }
  async deleteBankAccount() {
    await wait();
    this.bank = null;
  }
  async withdrawals() {
    await wait();
    return { items: [...this.withdrawalItems], minimumCents: 100000 };
  }
  async requestWithdrawal(a: { amountCents: number }) {
    await wait();
    const item: Withdrawal = { id: uuid(), reference: 'wd_demo', amountCents: a.amountCents, status: 'pending_approval', createdAt: new Date(), bank: this.bank, reason: '' };
    this.withdrawalItems.unshift(item);
    this.balance -= a.amountCents;
    this.ledger.unshift({ id: uuid(), kind: 'withdrawal', description: `Withdrawal to ${this.bank ? bankSummary(this.bank) : 'bank'}`, amountCents: -a.amountCents, createdAt: new Date(), meta: {} });
    return item;
  }
  async updateSettings(settings: AppSettings) {
    await wait();
    return settings;
  }
}
