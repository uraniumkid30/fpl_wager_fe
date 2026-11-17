// Ports of the Flutter domain models (auth, dashboard, team, challenges,
// notifications, payments, settings, wallet, withdrawals, web links).

const int = (v: unknown, d = 0) => (typeof v === 'number' ? Math.trunc(v) : d);
const intOrNull = (v: unknown) => (typeof v === 'number' ? Math.trunc(v) : null);
const parseDate = (v: unknown): Date | null => (typeof v === 'string' && !isNaN(Date.parse(v)) ? new Date(v) : null);

// ---------------------------------------------------------------- auth
export type UserProfile = {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  status: string;
  role: string;
  emailVerified: boolean;
  fplEntryId: number | null;
};
export const parseUser = (j: any): UserProfile => ({
  id: j.id,
  fullName: j.full_name,
  email: j.email,
  phone: j.phone ?? '',
  status: j.status ?? 'active',
  role: j.role ?? 'user',
  emailVerified: j.email_verified ?? false,
  fplEntryId: intOrNull(j.fpl_entry_id),
});
export const hasPlaceholderEmail = (u: UserProfile) => u.email.toLowerCase().endsWith('@fpl.fplboardman.internal');
export const displayEmail = (u: UserProfile) => (hasPlaceholderEmail(u) ? '' : u.email);
export const firstName = (u: UserProfile) => {
  const v = u.fullName.trim();
  return v ? v.split(/\s+/)[0] : 'Manager';
};
export const isAdmin = (u: UserProfile) => u.role === 'admin' || u.role === 'superadmin';

export type VerificationChallenge = { message: string; verificationPath: string; expiresInSeconds: number };
export const parseVerification = (j: any): VerificationChallenge => ({
  message: j.message ?? 'Enter the code sent to you.',
  verificationPath: j.verification_path,
  expiresInSeconds: int(j.expires_in_seconds),
});

export type AuthSession = { user: UserProfile; accessToken: string; refreshToken: string };

// ------------------------------------------------------------ web links / QR
export type QrLogin = { id: string; code: string; pollToken: string; expiresAt: Date; linkDays: number };
export const parseQrLogin = (j: any): QrLogin => ({
  id: j.id,
  code: j.code,
  pollToken: j.poll_token,
  expiresAt: parseDate(j.expires_at) ?? new Date(Date.now() + 2 * 60_000),
  linkDays: int(j.link_days, 90),
});
export type QrStatus = 'pending' | 'scanned' | 'approved' | 'consumed' | 'declined' | 'expired';
const qrStatuses: QrStatus[] = ['pending', 'scanned', 'approved', 'consumed', 'declined', 'expired'];
export const parseQrStatus = (v: unknown): QrStatus =>
  qrStatuses.includes(v as QrStatus) ? (v as QrStatus) : 'expired';
export type QrPoll = { status: QrStatus; session: AuthSession | null };
export type QrRequest = { label: string; linkDays: number };
export const parseQrRequest = (j: any): QrRequest => ({ label: j.label ?? 'Web browser', linkDays: int(j.link_days, 90) });

export type WebLink = { id: string; label: string; createdAt: Date; expiresAt: Date; lastUsedAt: Date };
export const parseWebLink = (j: any): WebLink => {
  const created = new Date(j.created_at);
  return {
    id: j.id,
    label: j.label ?? 'Web browser',
    createdAt: created,
    expiresAt: new Date(j.expires_at),
    lastUsedAt: parseDate(j.last_used_at) ?? created,
  };
};

/** The code in a scanned QR: a full link (".../v1/link/CODE") or the bare code. */
export function webLinkCodeFrom(scanned?: string | null): string | null {
  let text = (scanned ?? '').trim();
  if (!text) return null;
  const index = text.lastIndexOf('/link/');
  if (index >= 0) text = text.substring(index + '/link/'.length);
  text = text.split(/[?#]/)[0];
  return /^[A-Za-z0-9_-]{16,64}$/.test(text) ? text : null;
}

// ---------------------------------------------------------------- team
export type FplTeam = { entryId: number; teamName: string; managerName: string; overallRank: number | null };
export const parseTeam = (j: any): FplTeam => ({
  entryId: int(j.entry_id),
  teamName: j.team_name,
  managerName: j.manager_name,
  overallRank: intOrNull(j.overall_rank),
});
export type FplManager = {
  entryId: number;
  teamName: string;
  firstName: string;
  lastName: string;
  overallPoints: number;
  gameweekPoints: number;
  overallRank: number | null;
  currentGameweek: number | null;
};
export const parseManager = (j: any): FplManager => ({
  entryId: int(j.id),
  teamName: j.name,
  firstName: j.player_first_name,
  lastName: j.player_last_name,
  overallPoints: int(j.summary_overall_points),
  gameweekPoints: int(j.summary_event_points),
  overallRank: intOrNull(j.summary_overall_rank),
  currentGameweek: intOrNull(j.current_event),
});
export const managerName = (m: FplManager) => `${m.firstName} ${m.lastName}`.trim();

// ---------------------------------------------------------------- wallet
export type BankAccount = {
  provider: string;
  bankCode: string;
  bankName: string;
  accountNumber: string;
  accountName: string;
};
export const parseBankAccount = (j: any): BankAccount => ({
  provider: j.provider ?? '',
  bankCode: j.bank_code ?? '',
  bankName: j.bank_name ?? '',
  accountNumber: j.account_number ?? '',
  accountName: j.account_name ?? '',
});
export function maybeBankAccount(v: unknown): BankAccount | null {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
  const a = parseBankAccount(v);
  return a.accountNumber ? a : null;
}
export const maskedNumber = (a: BankAccount) =>
  a.accountNumber.length <= 4 ? a.accountNumber : `••••${a.accountNumber.substring(a.accountNumber.length - 4)}`;
export const bankSummary = (a: BankAccount) => `${a.bankName} · ${maskedNumber(a)}`;

export type LedgerEntry = {
  id: string;
  kind: string;
  description: string;
  amountCents: number;
  createdAt: Date;
  meta: Record<string, unknown>;
};
export const parseLedger = (j: any): LedgerEntry => ({
  id: j.id,
  kind: j.kind,
  description: j.description,
  amountCents: int(j.amount_cents),
  createdAt: new Date(j.created_at),
  meta: j.meta && typeof j.meta === 'object' ? j.meta : {},
});
export const ledgerBank = (e: LedgerEntry) => maybeBankAccount(e.meta.bank_details);
export const ledgerReason = (e: LedgerEntry) => (typeof e.meta.reason === 'string' ? e.meta.reason : '');

export type WalletSummary = { availableCents: number; lockedCents: number; ledger: LedgerEntry[] };
export const parseWallet = (j: any): WalletSummary => ({
  availableCents: int(j.available_cents),
  lockedCents: int(j.locked_cents),
  ledger: (j.ledger ?? []).map(parseLedger),
});
export type WalletBalance = { availableCents: number; lockedCents: number };
export const parseBalance = (j: any): WalletBalance => ({
  availableCents: int(j.available_cents),
  lockedCents: int(j.locked_cents),
});

// ---------------------------------------------------------------- dashboard
export type Dashboard = {
  user: UserProfile;
  team: FplTeam | null;
  wallet: WalletSummary;
  activeWagers: number;
  currentGameweek: number;
  deadline: Date | null;
};
export const parseDashboard = (j: any): Dashboard => ({
  user: parseUser(j.user),
  wallet: parseWallet(j.wallet),
  activeWagers: int(j.active_wagers),
  currentGameweek: int(j.current_gameweek),
  deadline: j.deadline == null ? null : new Date(j.deadline),
  team: j.team == null ? null : parseTeam(j.team),
});

// ---------------------------------------------------------------- challenges
export type Challenge = {
  id: string;
  opponentName: string;
  opponentTeamId: number;
  gameweek: number;
  stakeCents: number;
  status: string;
};
export const parseChallenge = (j: any): Challenge => ({
  id: j.id,
  opponentName: j.opponent_name,
  opponentTeamId: int(j.opponent_team_id),
  gameweek: int(j.gameweek),
  stakeCents: int(j.stake_cents),
  status: j.status,
});
/** A head-to-head is live as soon as it is created ("accepted"); older ones may say "pending". */
export const challengeStatusLabel = (s: string) =>
  s === 'accepted' || s === 'pending' ? 'Active' : s === 'scoring' ? 'Live' : s;

// ---------------------------------------------------------------- notifications
export type AppNotification = {
  id: string;
  kind: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  readAt: Date | null;
  createdAt: Date;
};
export const parseNotification = (j: any): AppNotification => ({
  id: j.id,
  kind: j.kind,
  title: j.title,
  body: j.body,
  data: j.data && typeof j.data === 'object' ? j.data : {},
  readAt: j.read_at == null ? null : new Date(j.read_at),
  createdAt: new Date(j.created_at),
});
export const isUnread = (n: AppNotification) => n.readAt == null;
export const notificationRoute = (n: AppNotification) => (typeof n.data.route === 'string' ? n.data.route : null);

// ---------------------------------------------------------------- payments
export type Payment = {
  id: string;
  userId: string;
  provider: string;
  credentialMode: string;
  reference: string;
  amountCents: number;
  currency: string;
  status: string;
  checkoutUrl: string | null;
};
export const parsePayment = (j: any): Payment => ({
  id: j.id,
  userId: j.user_id,
  provider: j.provider,
  credentialMode: j.credential_mode,
  reference: j.reference,
  amountCents: int(j.amount_cents),
  currency: j.currency,
  status: j.status,
  checkoutUrl: j.checkout_url ?? null,
});
export const paymentSuccessful = (p: Payment) => p.status === 'succeeded';
export const paymentFinal = (p: Payment) => paymentSuccessful(p) || p.status === 'failed' || p.status === 'cancelled';

// ---------------------------------------------------------------- settings
export type ThemeMode = 'system' | 'light' | 'dark';
export type AppSettings = {
  themeMode: ThemeMode;
  pushNotifications: boolean;
  poolNotifications: boolean;
  challengeNotifications: boolean;
  marketingNotifications: boolean;
};
export const defaultSettings: AppSettings = {
  themeMode: 'system',
  pushNotifications: true,
  poolNotifications: true,
  challengeNotifications: true,
  marketingNotifications: false,
};
export const parseSettings = (j: any): AppSettings => ({
  themeMode: j.theme_mode === 'light' ? 'light' : j.theme_mode === 'dark' ? 'dark' : 'system',
  pushNotifications: j.push_notifications ?? true,
  poolNotifications: j.pool_notifications ?? true,
  challengeNotifications: j.challenge_notifications ?? true,
  marketingNotifications: j.marketing_notifications ?? false,
});
export const settingsJson = (s: AppSettings) => ({
  theme_mode: s.themeMode,
  push_notifications: s.pushNotifications,
  pool_notifications: s.poolNotifications,
  challenge_notifications: s.challengeNotifications,
  marketing_notifications: s.marketingNotifications,
});

// ---------------------------------------------------------------- withdrawals
export type Bank = { name: string; code: string };
export const parseBank = (j: any): Bank => ({ name: j.name ?? '', code: j.code ?? '' });

export type Withdrawal = {
  id: string;
  reference: string;
  amountCents: number;
  status: string;
  createdAt: Date;
  bank: BankAccount | null;
  reason: string;
};
export const parseWithdrawal = (j: any): Withdrawal => ({
  id: j.id,
  reference: j.reference ?? '',
  amountCents: int(j.amount_cents),
  status: j.status ?? 'pending_approval',
  createdAt: new Date(j.created_at),
  bank: maybeBankAccount(j.bank_details),
  reason: j.reason ?? '',
});
export const withdrawalOpen = (w: Withdrawal) => w.status === 'pending_approval' || w.status === 'approved';
export const withdrawalPaid = (w: Withdrawal) => w.status === 'successful';
export const withdrawalRefunded = (w: Withdrawal) =>
  w.status === 'rejected' || w.status === 'failed' || w.status === 'reversed';
export const withdrawalStatusLabel = (w: Withdrawal) =>
  ({
    pending_approval: 'Awaiting approval',
    approved: 'Processing',
    successful: 'Paid',
    rejected: 'Rejected',
    failed: 'Failed',
    reversed: 'Reversed',
  })[w.status] ?? w.status.replace(/_/g, ' ');
export const withdrawalStatusNote = (w: Withdrawal) =>
  ({
    pending_approval: 'An administrator reviews every withdrawal before it is paid.',
    approved: 'Approved. Your bank transfer is on its way.',
    successful: 'Paid to your bank account.',
    rejected: 'Not approved. The money is back in your wallet.',
    failed: 'The transfer failed. The money is back in your wallet.',
    reversed: 'Your bank returned the transfer. The money is back in your wallet.',
  })[w.status] ?? '';

export type WithdrawalOverview = { items: Withdrawal[]; minimumCents: number };
export const parseWithdrawalOverview = (j: any): WithdrawalOverview => ({
  items: (j.items ?? []).map(parseWithdrawal),
  minimumCents: intOrNull(j.minimum_cents) ?? 100000,
});

/** "5000", "5,000", "5000.50" -> kobo; null when not a positive amount with ≤ 2 decimals. */
export function nairaToCents(input: string): number | null {
  const text = input.replace(/,/g, '').replace(/₦/g, '').trim();
  const m = /^(\d{1,9})(?:\.(\d{1,2}))?$/.exec(text);
  if (!m) return null;
  const cents = parseInt(m[1], 10) * 100 + parseInt((m[2] ?? '').padEnd(2, '0'), 10);
  return cents > 0 ? cents : null;
}

// ---------------------------------------------------------------- top-up provider
/** Which provider the next top-up uses. Administrators choose it; users do not. */
export type PaymentOptions = { provider: string; label: string; available: boolean; minCents: number; maxCents: number };
export const parsePaymentOptions = (j: any): PaymentOptions => ({
  provider: typeof j.provider === 'string' ? j.provider : 'globalpay',
  label: typeof j.label === 'string' && j.label ? j.label : 'Zenith GlobalPay',
  available: j.available !== false,
  minCents: int(j.min_cents, 10000),
  maxCents: int(j.max_cents, 100000000),
});

// ---------------------------------------------------------------- campaigns
export type CampaignTheme = 'rumble' | 'pitch' | 'cyan' | 'gold' | 'midnight';
export type CampaignFact = { label: string; value: string };
/** A marketing entry (the Royal Rumble first) shown at the top of Home and Pools. */
export type Campaign = {
  id: string;
  slug: string;
  badge: string;
  title: string;
  tagline: string;
  body: string;
  rules: string[];
  highlights: CampaignFact[];
  theme: CampaignTheme;
  ctaLabel: string;
  ctaKind: 'none' | 'pool' | 'route' | 'url';
  ctaTarget: string;
  placements: string[];
  countdownTo: Date | null;
  countdownLabel: string;
};
const themes: CampaignTheme[] = ['rumble', 'pitch', 'cyan', 'gold', 'midnight'];
export const parseCampaign = (j: any): Campaign => ({
  id: String(j.id ?? ''),
  slug: String(j.slug ?? ''),
  badge: j.badge ?? '',
  title: j.title ?? '',
  tagline: j.tagline ?? '',
  body: j.body ?? '',
  rules: Array.isArray(j.rules) ? j.rules.filter((r: unknown) => typeof r === 'string') : [],
  highlights: Array.isArray(j.highlights)
    ? j.highlights
        .filter((h: any) => h && typeof h.label === 'string' && typeof h.value === 'string')
        .slice(0, 4)
    : [],
  theme: themes.includes(j.theme) ? j.theme : 'rumble',
  ctaLabel: j.cta_label || 'See how it works',
  ctaKind: ['pool', 'route', 'url'].includes(j.cta_kind) ? j.cta_kind : 'none',
  ctaTarget: j.cta_target ?? '',
  placements: Array.isArray(j.placements) ? j.placements : ['home', 'pools'],
  countdownTo: parseDate(j.countdown_to),
  countdownLabel: j.countdown_label ?? '',
});
