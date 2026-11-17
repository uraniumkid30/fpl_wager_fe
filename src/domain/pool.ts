import { PayoutChoice, PayoutRule, WinnerRule } from './payout';

export * from './payout';

export type PoolView = 'active' | 'past';

export type PoolDrawMethod = 'split' | 'captains' | 'number';
export const drawMethods: PoolDrawMethod[] = ['split', 'captains', 'number'];
export const drawMethodFromWire = (v: unknown): PoolDrawMethod =>
  v === 'captains' ? 'captains' : v === 'number' ? 'number' : 'split';
export const drawMethodLabel: Record<PoolDrawMethod, string> = {
  split: 'SPLIT',
  captains: 'CAPTAINS',
  // "Number of goals" in full; short enough here for a phone.
  number: 'GOALS',
};
export const drawMethodLongLabel: Record<PoolDrawMethod, string> = {
  split: 'Split',
  captains: 'Captains',
  number: 'Number of goals',
};
export const drawMethodDescription: Record<PoolDrawMethod, string> = {
  split: 'Managers level on points share the prize money of the places they cover equally.',
  captains:
    "Managers level on points are put in order by their captain's gameweek points. Still level? They share.",
  number:
    'Number of goals: managers level on points are put in order by the goals their players scored in the gameweek. Still level? They share.',
};

const int = (v: unknown, d = 0) => (typeof v === 'number' ? Math.trunc(v) : d);
const intOrNull = (v: unknown) => (typeof v === 'number' ? Math.trunc(v) : null);
const date = (v: unknown) => (typeof v === 'string' && !isNaN(Date.parse(v)) ? new Date(v) : null);

/** "5" or "2.5" — a percentage without a trailing ".0". */
export const percentNumberLabel = (p: number) => (p === Math.round(p) ? p.toFixed(0) : String(p));

export type PoolManage = {
  entries: number;
  otherEntries: number;
  canEdit: boolean;
  canDelete: boolean;
  deleteFeeCents: number;
  deleteFeePercent: number;
};
const parseManage = (j: any): PoolManage => ({
  entries: int(j.entries),
  otherEntries: int(j.other_entries),
  canEdit: j.can_edit ?? false,
  canDelete: j.can_delete ?? false,
  deleteFeeCents: int(j.delete_fee_cents),
  deleteFeePercent: typeof j.delete_fee_percent === 'number' ? j.delete_fee_percent : 5,
});

export type PoolMember = {
  displayName: string;
  /** Position, level managers share one (1, 2, 2, 4). Zero when there are none yet. */
  rank: number;
  points: number;
  userId: string;
  status: string;
  payoutCents: number;
  projectedCents: number;
  isMe: boolean;
};
const parseMember = (j: any): PoolMember => ({
  displayName: j.display_name,
  rank: int(j.rank),
  points: int(j.points),
  userId: j.user_id ?? '',
  status: j.status ?? 'active',
  payoutCents: int(j.payout_cents),
  projectedCents: int(j.projected_cents),
  isMe: j.is_me ?? false,
});

export type Prize = { place: number; amountCents: number; percent: number };
export const prizePercentLabel = (p: Prize) =>
  p.percent === Math.round(p.percent) ? p.percent.toFixed(0) : p.percent.toFixed(2);

export type PayoutPlan = {
  entrants: number;
  stakeCents: number;
  totalStakedCents: number;
  houseCutCents: number;
  houseCutPercent: number;
  totalWinningCents: number;
  winners: number;
  commonRatio: number;
  floorMet: boolean;
  mode: string;
  chosenWinners: number;
};
const parsePlan = (j: any): PayoutPlan => ({
  mode: j.mode ?? 'standard',
  chosenWinners: int(j.chosen_winners),
  entrants: int(j.entrants),
  stakeCents: int(j.stake_cents),
  totalStakedCents: int(j.total_staked_cents),
  houseCutCents: int(j.house_cut_cents),
  houseCutPercent: typeof j.house_cut_percent === 'number' ? j.house_cut_percent : 0,
  totalWinningCents: int(j.total_winning_cents),
  winners: int(j.winners),
  commonRatio: typeof j.common_ratio === 'number' ? j.common_ratio : 0,
  floorMet: j.floor_met ?? true,
});

export type Pool = {
  id: string;
  name: string;
  gameweek: number;
  stakeCents: number;
  prizePoolCents: number;
  status: string;
  memberCount: number;
  deadline: Date;
  membershipStatus: string | null;
  approvalRequired: boolean;
  poolKind: string;
  rules: string;
  drawMethod: PoolDrawMethod;
  inviteCode: string | null;
  maxMembers: number | null;
  autoSeriesNo: number | null;
  leaderboard: PoolMember[];
  prizeSplit: Prize[];
  payout: PayoutPlan | null;
  visibility: string;
  creatorName: string;
  isCreator: boolean;
  manage: PoolManage | null;
  ranked: boolean;
  scoredAt: Date | null;
  payoutRule: PayoutRule | null;
  myPoints: number | null;
  myRank: number | null;
  myPayoutCents: number | null;
};

export function parsePool(j: any): Pool {
  return {
    id: j.id,
    name: j.name,
    gameweek: int(j.gameweek),
    stakeCents: int(j.stake_cents),
    prizePoolCents: int(j.prize_pool_cents),
    status: j.status,
    memberCount: int(j.member_count),
    deadline: new Date(j.deadline),
    membershipStatus: j.membership_status ?? null,
    approvalRequired: j.approval_required ?? false,
    poolKind: j.pool_kind ?? 'custom',
    rules: j.rules ?? '',
    drawMethod: drawMethodFromWire(j.draw_method ?? 'split'),
    inviteCode: j.invite_code ?? null,
    maxMembers: intOrNull(j.max_members),
    autoSeriesNo: intOrNull(j.auto_series_no),
    leaderboard: (j.leaderboard ?? []).map(parseMember),
    prizeSplit: (j.prize_split ?? []).map((p: any) => ({
      place: int(p.place),
      amountCents: int(p.amount_cents),
      percent: p.percent ?? 0,
    })),
    payout: j.payout && typeof j.payout === 'object' ? parsePlan(j.payout) : null,
    visibility: j.visibility ?? 'public',
    creatorName: j.creator_name ?? '',
    isCreator: j.is_creator ?? false,
    // An older server does not say; a settled pool always has positions.
    ranked: j.ranked ?? j.status === 'settled',
    scoredAt: date(j.scored_at),
    payoutRule: j.payout_rule && typeof j.payout_rule === 'object' ? PayoutRule.fromJson(j.payout_rule) : null,
    myPoints: intOrNull(j.my_points),
    myRank: intOrNull(j.my_rank),
    myPayoutCents: intOrNull(j.my_payout_cents),
    manage: j.manage && typeof j.manage === 'object' ? parseManage(j.manage) : null,
  };
}

// The Flutter getters, as functions.
export const isFinished = (p: Pool) => p.status === 'settled' || p.status === 'cancelled';
export const isLive = (p: Pool) => p.status === 'locked' || p.status === 'scoring';
export const isPrivate = (p: Pool) => p.visibility === 'private';
export const isMine = (p: Pool) => p.isCreator || !!p.inviteCode;
export const hasJoined = (p: Pool) => p.membershipStatus === 'active';
export const isPendingMember = (p: Pool) => p.membershipStatus === 'pending';
export const hasLeft = (p: Pool) => p.membershipStatus === 'left' || p.membershipStatus === 'refunded';
export const canJoin = (p: Pool) => p.status === 'open' && (p.membershipStatus == null || hasLeft(p));
export const isAuto = (p: Pool) => p.poolKind === 'auto';
export const awaitingAdminApproval = (p: Pool) => p.poolKind === 'custom' && p.status === 'draft';
export const manageFeeLabel = (m: PoolManage) => percentNumberLabel(m.deleteFeePercent);
export const houseCutPercentLabel = (p: PayoutPlan) => percentNumberLabel(p.houseCutPercent);

/** "st", "nd", "rd" or "th" for a position. */
export function ordinalSuffix(place: number): string {
  const lastTwo = place % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return 'th';
  switch (place % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

export type CreatePoolCommand = {
  name: string;
  gameweek: number;
  stakeCents: number;
  drawMethod: PoolDrawMethod;
  payout: PayoutChoice;
  rules?: string;
  approvalRequired?: boolean;
  maxMembers?: number | null;
};

/** The terms the server sets for pools users create. */
export class PoolTerms {
  constructor(
    readonly deleteFeeBasisPoints = 500,
    readonly winnerRule = new WinnerRule(),
  ) {}

  static fromJson(j: any): PoolTerms {
    const bp = j?.delete_fee_basis_points;
    const percent = j?.delete_fee_percent;
    return new PoolTerms(
      typeof bp === 'number' ? Math.trunc(bp) : typeof percent === 'number' ? Math.round(percent * 100) : 500,
      j?.winner_rule && typeof j.winner_rule === 'object' ? WinnerRule.fromJson(j.winner_rule) : new WinnerRule(),
    );
  }

  get deleteFeePercentLabel(): string {
    return percentNumberLabel(this.deleteFeeBasisPoints / 100);
  }

  deleteFeeFor(stakeCents: number): number {
    return Math.trunc((stakeCents * this.deleteFeeBasisPoints) / 10000);
  }
}

// ------------------------------------------------------------ gameweek history

export type GameweekPoolResult = {
  id: string;
  name: string;
  poolKind: string;
  status: string;
  stakeCents: number;
  entrants: number;
  points: number | null;
  rank: number | null;
  payoutCents: number;
};
export type GameweekResult = {
  gameweek: number;
  gameweekStatus: string;
  deadline: Date | null;
  points: number | null;
  position: number | null;
  managers: number | null;
  poolsEntered: number;
  stakedCents: number;
  wonCents: number;
  isFinal: boolean;
  pools: GameweekPoolResult[];
};
export function parseGameweekResult(j: any): GameweekResult {
  return {
    gameweek: int(j.gameweek),
    gameweekStatus: j.gameweek_status ?? '',
    deadline: date(j.deadline),
    points: intOrNull(j.points),
    position: intOrNull(j.position),
    managers: intOrNull(j.managers),
    poolsEntered: int(j.pools_entered),
    stakedCents: int(j.staked_cents),
    wonCents: int(j.won_cents),
    isFinal: j.final ?? false,
    pools: (j.pools ?? [])
      .filter((x: unknown) => x && typeof x === 'object')
      .map((p: any) => ({
        id: p.id,
        name: p.name ?? '',
        poolKind: p.pool_kind ?? 'custom',
        status: p.status ?? '',
        stakeCents: int(p.stake_cents),
        entrants: int(p.entrants),
        points: intOrNull(p.points),
        rank: intOrNull(p.rank),
        payoutCents: int(p.payout_cents),
      })),
  };
}
export const gwPoolSettled = (p: GameweekPoolResult) => p.status === 'settled';
export const gwPoolLive = (p: GameweekPoolResult) => p.status === 'locked' || p.status === 'scoring';

/**
 * Pulls the invite code out of whatever was typed or pasted: the code on its
 * own, or a whole invite link (or message) that contains it.
 */
export function inviteCodeFrom(input: string): string | null {
  let text = input.trim();
  if (!text) return null;
  const link = /join\/([A-Za-z0-9-]+)/.exec(text);
  if (link) text = link[1];
  const code = text.toUpperCase().replace(/[\s-]/g, '');
  return /^[A-Z0-9]{6,16}$/.test(code) ? code : null;
}
