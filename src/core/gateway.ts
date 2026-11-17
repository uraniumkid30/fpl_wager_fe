import * as Crypto from 'expo-crypto';

import {
  Campaign,
  PaymentOptions,
  parseCampaign,
  parsePaymentOptions,
  AppNotification,
  AppSettings,
  AuthSession,
  Bank,
  BankAccount,
  Challenge,
  Dashboard,
  FplManager,
  FplTeam,
  Payment,
  QrLogin,
  QrPoll,
  QrRequest,
  UserProfile,
  VerificationChallenge,
  WalletBalance,
  WalletSummary,
  WebLink,
  Withdrawal,
  WithdrawalOverview,
  maybeBankAccount,
  parseBank,
  parseBankAccount,
  parseBalance,
  parseChallenge,
  parseDashboard,
  parseManager,
  parseNotification,
  parsePayment,
  parseQrLogin,
  parseQrRequest,
  parseQrStatus,
  parseSettings,
  parseTeam,
  parseUser,
  parseVerification,
  parseWallet,
  parseWebLink,
  parseWithdrawal,
  parseWithdrawalOverview,
  settingsJson,
} from '@/domain/models';
import {
  CreatePoolCommand,
  GameweekResult,
  PayoutChoice,
  Pool,
  PoolDrawMethod,
  PoolTerms,
  PoolView,
  parseGameweekResult,
  parsePool,
  payoutChoiceJson,
} from '@/domain/pool';
import { ApiClient, apiClient } from './api';
import { AppException } from './errors';
import { SessionStore, StoredTokens } from './storage';

/** Everything the app asks of the server. */
export interface AppGateway {
  restoreSession(): Promise<AuthSession | null>;
  continueWithFpl(refreshToken: string, session?: Record<string, unknown> | null): Promise<AuthSession>;
  requestEmailSignIn(email: string): Promise<VerificationChallenge>;
  verifyEmailSignIn(email: string, otp: string): Promise<AuthSession>;
  requestEmailVerification(email: string): Promise<VerificationChallenge>;
  verifyEmail(email: string, otp: string): Promise<UserProfile>;
  createQrLogin(): Promise<QrLogin>;
  pollQrLogin(login: QrLogin): Promise<QrPoll>;
  scanQrLogin(code: string): Promise<QrRequest>;
  approveQrLogin(code: string): Promise<void>;
  declineQrLogin(code: string): Promise<void>;
  webLinks(): Promise<WebLink[]>;
  revokeWebLink(id: string): Promise<void>;
  logout(): Promise<void>;
  dashboard(): Promise<Dashboard>;
  linkTeam(entryId: number): Promise<FplTeam>;
  validateTeam(entryId: number): Promise<FplManager>;
  pools(opts?: { gameweek?: number; view?: PoolView }): Promise<Pool[]>;
  gameweekHistory(): Promise<GameweekResult[]>;
  pool(id: string): Promise<Pool>;
  createPool(command: CreatePoolCommand): Promise<Pool>;
  joinPool(id: string): Promise<Pool>;
  leavePool(id: string): Promise<Pool>;
  poolByInvite(code: string): Promise<Pool>;
  joinPoolByInvite(code: string): Promise<Pool>;
  updatePool(
    id: string,
    args: {
      name: string;
      stakeCents: number;
      drawMethod: PoolDrawMethod;
      rules?: string;
      maxMembers?: number | null;
      payout?: PayoutChoice;
    },
  ): Promise<Pool>;
  deletePool(id: string, feeCents: number): Promise<void>;
  resetPoolInvite(id: string): Promise<Pool>;
  poolTerms(): Promise<PoolTerms>;
  notifications(): Promise<AppNotification[]>;
  markNotificationRead(id: string): Promise<void>;
  challenges(): Promise<Challenge[]>;
  createChallenge(args: { opponentTeamId: number; gameweek: number; stakeCents: number }): Promise<Challenge>;
  wallet(): Promise<WalletSummary>;
  walletBalance(): Promise<WalletBalance>;
  creditWallet(amountCents: number): Promise<WalletSummary>;
  /** The provider administrators chose for top-ups (users do not choose). */
  paymentOptions(): Promise<PaymentOptions>;
  initializePayment(args: { amountCents: number; callbackUrl: string; cancelUrl: string }): Promise<Payment>;
  /** Live marketing campaigns for a place in the app. */
  campaigns(placement: 'home' | 'pools'): Promise<Campaign[]>;
  campaign(slug: string): Promise<Campaign>;
  verifyPayment(reference: string): Promise<Payment>;
  banks(): Promise<Bank[]>;
  bankAccount(): Promise<BankAccount | null>;
  resolveBankAccount(args: { bankCode: string; accountNumber: string }): Promise<BankAccount>;
  saveBankAccount(args: { bankCode: string; accountNumber: string }): Promise<BankAccount>;
  deleteBankAccount(): Promise<void>;
  withdrawals(): Promise<WithdrawalOverview>;
  requestWithdrawal(args: { amountCents: number; idempotencyKey: string }): Promise<Withdrawal>;
  updateSettings(settings: AppSettings): Promise<AppSettings>;
}

export const newIdempotencyKey = () => Crypto.randomUUID();

const list = (body: Record<string, any>, key: string): any[] =>
  Array.isArray(body[key]) ? body[key].filter((x: unknown) => x && typeof x === 'object') : [];

export class RemoteGateway implements AppGateway {
  private tokens: StoredTokens | null = null;
  /** Set when the server has no balance-only endpoint (an older API). */
  private balanceEndpointMissing = false;
  private refreshing: Promise<string | null> | null = null;

  constructor(private readonly client: ApiClient = apiClient) {
    client.setRefreshHandler(() => this.refreshAccessToken());
  }

  /** The current access token, for the realtime connection. */
  get signedIn() {
    return this.tokens != null;
  }

  async restoreSession() {
    const stored = await SessionStore.read();
    if (!stored) return null;
    this.tokens = stored;
    this.client.authorize(stored.accessToken);
    try {
      const body = await this.client.get('/me');
      return this.session(parseUser(body.user), this.tokens ?? stored);
    } catch (e) {
      if (e instanceof AppException && e.kind === 'authentication') {
        await SessionStore.clear();
        this.client.authorize(null);
        return null;
      }
      throw e;
    }
  }

  async continueWithFpl(refreshToken: string, session?: Record<string, unknown> | null) {
    return this.saveTokenResponse(
      await this.client.post(
        '/auth/fpl',
        { refresh_token: refreshToken, ...(session ? { session } : {}) },
        { allowRefresh: false },
      ),
    );
  }

  async requestEmailSignIn(email: string) {
    return parseVerification(await this.client.post('/auth/email/login', { email }, { allowRefresh: false }));
  }

  async verifyEmailSignIn(email: string, otp: string) {
    return this.saveTokenResponse(
      await this.client.post('/auth/email/login/verify', { email, otp }, { allowRefresh: false }),
    );
  }

  async requestEmailVerification(email: string) {
    return parseVerification(await this.client.post('/me/email/verification', { email }));
  }

  async verifyEmail(email: string, otp: string) {
    return parseUser((await this.client.post('/me/email/verify', { email, otp })).user);
  }

  async createQrLogin() {
    return parseQrLogin(await this.client.post('/auth/qr', {}, { allowRefresh: false }));
  }

  async pollQrLogin(login: QrLogin): Promise<QrPoll> {
    const body = await this.client.post(
      `/auth/qr/${login.id}/poll`,
      { poll_token: login.pollToken },
      { allowRefresh: false },
    );
    const status = parseQrStatus(String(body.status));
    if (status === 'approved' && typeof body.access_token === 'string') {
      return { status, session: await this.saveTokenResponse(body) };
    }
    return { status, session: null };
  }

  async scanQrLogin(code: string) {
    return parseQrRequest(await this.client.post('/auth/qr/scan', { code }));
  }
  async approveQrLogin(code: string) {
    await this.client.post('/auth/qr/approve', { code });
  }
  async declineQrLogin(code: string) {
    await this.client.post('/auth/qr/decline', { code });
  }
  async webLinks() {
    return list(await this.client.get('/me/web-links'), 'items').map(parseWebLink);
  }
  async revokeWebLink(id: string) {
    await this.client.delete(`/me/web-links/${id}`);
  }

  private async saveTokenResponse(body: Record<string, any>): Promise<AuthSession> {
    const stored: StoredTokens = { accessToken: body.access_token, refreshToken: body.refresh_token };
    this.tokens = stored;
    this.client.authorize(stored.accessToken);
    const session = this.session(parseUser(body.user), stored);
    await SessionStore.write(stored);
    return session;
  }

  private refreshAccessToken(): Promise<string | null> {
    if (this.refreshing) return this.refreshing;
    this.refreshing = this.performRefresh().finally(() => {
      this.refreshing = null;
    });
    return this.refreshing;
  }

  private async performRefresh(): Promise<string | null> {
    const refresh = this.tokens?.refreshToken;
    if (!refresh) return null;
    try {
      const body = await this.client.post('/auth/refresh', { refresh_token: refresh }, { allowRefresh: false });
      return (await this.saveTokenResponse(body)).accessToken;
    } catch (e) {
      if (!(e instanceof AppException)) throw e;
      this.tokens = null;
      await SessionStore.clear();
      return null;
    }
  }

  private session(user: UserProfile, tokens: StoredTokens): AuthSession {
    return { user, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken };
  }

  async logout() {
    const refresh = this.tokens?.refreshToken;
    if (refresh) {
      try {
        await this.client.post('/auth/logout', { refresh_token: refresh }, { allowRefresh: false });
      } catch {
        // Local logout must still succeed if the network is unavailable.
      }
    }
    this.tokens = null;
    this.client.authorize(null);
    await SessionStore.clear();
  }

  async dashboard() {
    return parseDashboard(await this.client.get('/dashboard'));
  }
  async linkTeam(entryId: number) {
    return parseTeam(await this.client.post('/fpl-team/link', { entry_id: entryId }));
  }
  async validateTeam(entryId: number) {
    return parseManager(await this.client.post('/fpl-team/validate', { entry_id: entryId }));
  }
  async pools(opts: { gameweek?: number; view?: PoolView } = {}) {
    const body = await this.client.get('/pools', { gameweek: opts.gameweek, view: opts.view ?? 'active' });
    return list(body, 'items').map(parsePool);
  }
  async gameweekHistory() {
    return list(await this.client.get('/me/gameweeks'), 'items').map(parseGameweekResult);
  }
  async pool(id: string) {
    return parsePool(await this.client.get(`/pools/${id}`));
  }
  async createPool(c: CreatePoolCommand) {
    return parsePool(
      await this.client.post(
        '/pools',
        {
          name: c.name,
          gameweek: c.gameweek,
          stake_cents: c.stakeCents,
          ...(c.rules ? { rules: c.rules } : {}),
          draw_method: c.drawMethod,
          ...payoutChoiceJson(c.payout),
          // The server makes every pool a user creates private and lets
          // anyone with the invite code enter; these two say the same.
          visibility: 'private',
          approval_required: false,
          max_members: c.maxMembers ?? null,
        },
        { idempotencyKey: newIdempotencyKey() },
      ),
    );
  }
  async joinPool(id: string) {
    return parsePool(await this.client.post(`/pools/${id}/join`, undefined, { idempotencyKey: newIdempotencyKey() }));
  }
  async leavePool(id: string) {
    return parsePool(await this.client.post(`/pools/${id}/leave`, undefined, { idempotencyKey: newIdempotencyKey() }));
  }
  async poolByInvite(code: string) {
    return parsePool(await this.client.get(`/pools/invite/${encodeURIComponent(code)}`));
  }
  async joinPoolByInvite(code: string) {
    return parsePool(
      await this.client.post(`/pools/invite/${encodeURIComponent(code)}/join`, undefined, {
        idempotencyKey: newIdempotencyKey(),
      }),
    );
  }
  async updatePool(
    id: string,
    a: {
      name: string;
      stakeCents: number;
      drawMethod: PoolDrawMethod;
      rules?: string;
      maxMembers?: number | null;
      payout?: PayoutChoice;
    },
  ) {
    return parsePool(
      await this.client.patch(`/pools/${id}`, {
        name: a.name,
        stake_cents: a.stakeCents,
        ...(a.rules != null ? { rules: a.rules } : {}),
        ...(a.payout ? payoutChoiceJson(a.payout) : {}),
        draw_method: a.drawMethod,
        // Zero tells the server to remove the entry limit.
        max_members: a.maxMembers ?? 0,
      }),
    );
  }
  async deletePool(id: string, feeCents: number) {
    await this.client.delete(`/pools/${id}`, { fee_cents: feeCents });
  }
  async resetPoolInvite(id: string) {
    return parsePool(await this.client.post(`/pools/${id}/invite/reset`));
  }
  async poolTerms() {
    try {
      return PoolTerms.fromJson(await this.client.get('/pools/terms'));
    } catch (e) {
      // A server from before the fee could be changed: it charges 5%.
      if (e instanceof AppException && e.kind === 'validation' && e.code == null) return new PoolTerms();
      throw e;
    }
  }
  async notifications() {
    return list(await this.client.get('/notifications'), 'items').map(parseNotification);
  }
  async markNotificationRead(id: string) {
    await this.client.patch(`/notifications/${id}/read`);
  }
  async challenges() {
    return list(await this.client.get('/challenges'), 'items').map(parseChallenge);
  }
  async createChallenge(a: { opponentTeamId: number; gameweek: number; stakeCents: number }) {
    return parseChallenge(
      await this.client.post(
        '/challenges',
        { opponent_team_id: a.opponentTeamId, gameweek: a.gameweek, stake_cents: a.stakeCents },
        { idempotencyKey: newIdempotencyKey() },
      ),
    );
  }
  async wallet() {
    return parseWallet(await this.client.get('/wallet'));
  }
  async walletBalance(): Promise<WalletBalance> {
    if (!this.balanceEndpointMissing) {
      try {
        return parseBalance(await this.client.get('/wallet/balance'));
      } catch (e) {
        // A refusal with no error code means the address does not exist.
        if (!(e instanceof AppException && e.kind === 'validation' && e.code == null)) throw e;
        this.balanceEndpointMissing = true;
      }
    }
    const full = await this.wallet();
    return { availableCents: full.availableCents, lockedCents: full.lockedCents };
  }
  async creditWallet(amountCents: number) {
    return parseWallet(
      await this.client.post('/wallet/dev-credit', { amount_cents: amountCents }, { idempotencyKey: newIdempotencyKey() }),
    );
  }
  async paymentOptions() {
    try {
      return parsePaymentOptions(await this.client.get('/payments/options'));
    } catch (e) {
      // A server from before the admin switch: it used Paystack by default.
      if (e instanceof AppException && e.kind === 'validation' && e.code === 'ROUTE_NOT_FOUND') {
        return parsePaymentOptions({ provider: 'paystack', label: 'Paystack' });
      }
      throw e;
    }
  }
  async campaigns(placement: 'home' | 'pools') {
    try {
      return list(await this.client.get('/campaigns', { placement }), 'items').map(parseCampaign);
    } catch (e) {
      // No campaigns on a server that does not have them yet.
      if (e instanceof AppException && e.code === 'ROUTE_NOT_FOUND') return [];
      throw e;
    }
  }
  async campaign(slug: string) {
    return parseCampaign(await this.client.get(`/campaigns/${encodeURIComponent(slug)}`));
  }
  async initializePayment(a: { amountCents: number; callbackUrl: string; cancelUrl: string }) {
    return parsePayment(
      await this.client.post(
        '/payments',
        {
          // No provider: the server uses the one administrators chose.
          amount_cents: a.amountCents,
          currency: 'NGN',
          callback_url: a.callbackUrl,
          cancel_url: a.cancelUrl,
        },
        { idempotencyKey: newIdempotencyKey() },
      ),
    );
  }
  async verifyPayment(reference: string) {
    return parsePayment(await this.client.get(`/payments/${reference}`));
  }
  async banks() {
    return list(await this.client.get('/banks'), 'items').map(parseBank);
  }
  async bankAccount() {
    return maybeBankAccount((await this.client.get('/bank-account')).bank_account);
  }
  async resolveBankAccount(a: { bankCode: string; accountNumber: string }) {
    const body = await this.client.post('/bank-account/resolve', {
      bank_code: a.bankCode,
      account_number: a.accountNumber,
    });
    return parseBankAccount(body.bank_account);
  }
  async saveBankAccount(a: { bankCode: string; accountNumber: string }) {
    const body = await this.client.put('/bank-account', { bank_code: a.bankCode, account_number: a.accountNumber });
    return parseBankAccount(body.bank_account);
  }
  async deleteBankAccount() {
    await this.client.delete('/bank-account');
  }
  async withdrawals() {
    return parseWithdrawalOverview(await this.client.get('/withdrawals'));
  }
  async requestWithdrawal(a: { amountCents: number; idempotencyKey: string }) {
    return parseWithdrawal(
      await this.client.post('/withdrawals', { amount_cents: a.amountCents }, { idempotencyKey: a.idempotencyKey }),
    );
  }
  async updateSettings(settings: AppSettings) {
    return parseSettings(await this.client.put('/settings', settingsJson(settings)));
  }
}
