// How a pool a user creates pays out, and the limits on it.
// Mirrors the server (internal/store/payout_rules.go) exactly as the Flutter app did.

export const shareBasisPoints = 10000;

export type PayoutMode = 'winner_takes_all' | 'split';
export const payoutModeLabel: Record<PayoutMode, string> = {
  winner_takes_all: 'Winner takes all',
  split: 'Split',
};
export const payoutModeFromWire = (v?: unknown): PayoutMode => (v === 'split' ? 'split' : 'winner_takes_all');

const idiv = (a: number, b: number) => Math.trunc(a / b);

export class WinnerRule {
  constructor(
    readonly winners = 3,
    readonly entrants = 5,
    readonly maxWinners = 50,
  ) {}

  static fromJson(json?: Record<string, any> | null): WinnerRule {
    if (!json) return new WinnerRule();
    const w = json.winners ?? 3;
    const e = json.entrants ?? 5;
    const m = json.max_winners ?? 50;
    if (e < 1 || w < 1 || m < 1) return new WinnerRule();
    return new WinnerRule(Math.trunc(w), Math.trunc(e), Math.trunc(m));
  }

  /** How many places can be paid with this many managers in the pool. */
  cap(managers: number): number {
    if (managers <= 0) return 0;
    let places = idiv(managers * this.winners, this.entrants);
    if (places > this.maxWinners) places = this.maxWinners;
    if (places > managers) places = managers;
    return places < 1 ? 1 : places;
  }

  /** The fewest managers that let [places] places all be paid. */
  managersNeeded(places: number): number {
    if (places <= 1) return 2;
    const needed = idiv(places * this.entrants + this.winners - 1, this.winners);
    return needed < places ? places : needed;
  }

  /** "3 winners for every 5 managers". */
  get description(): string {
    return `${this.winners} ${this.winners === 1 ? 'winner' : 'winners'} for every ${this.entrants} ${
      this.entrants === 1 ? 'manager' : 'managers'
    }`;
  }
}

/** Suggested shares: 60/40, 50/30/20, 40/30/20/10, 35/25/20/12/8, then a straight line down. */
export function defaultShares(winners: number): number[] {
  if (winners <= 0) return [];
  if (winners === 1) return [10000];
  if (winners === 2) return [6000, 4000];
  if (winners === 3) return [5000, 3000, 2000];
  if (winners === 4) return [4000, 3000, 2000, 1000];
  if (winners === 5) return [3500, 2500, 2000, 1200, 800];
  const total = idiv(winners * (winners + 1), 2);
  const shares = Array.from({ length: winners }, (_, i) => idiv(shareBasisPoints * (winners - i), total));
  shares[0] += shareBasisPoints - shares.reduce((s, x) => s + x, 0);
  return shares;
}

export function placeLabel(place: number): string {
  const lastTwo = place % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return `${place}th`;
  switch (place % 10) {
    case 1:
      return `${place}st`;
    case 2:
      return `${place}nd`;
    case 3:
      return `${place}rd`;
    default:
      return `${place}th`;
  }
}

/** 5000 -> "50%", 3333 -> "33.33%". */
export function percentLabel(basisPoints: number): string {
  const whole = idiv(basisPoints, 100);
  const rest = basisPoints % 100;
  if (rest === 0) return `${whole}%`;
  return `${whole}.${String(rest).padStart(2, '0').replace(/0$/, '')}%`;
}

export const percentInput = (bp: number) => percentLabel(bp).replace(/%/g, '');

/** "50" or "33.33" -> basis points; null if not a percentage with at most two decimals. */
export function parsePercent(text: string): number | null {
  const m = /^\s*(\d{1,3})(?:[.,](\d{1,2}))?\s*%?\s*$/.exec(text);
  if (!m) return null;
  const whole = parseInt(m[1], 10);
  const fraction = (m[2] ?? '').padEnd(2, '0');
  return whole * 100 + (fraction ? parseInt(fraction, 10) : 0);
}

/** What is wrong with a set of shares, or null if they can be used. */
export function sharesProblem(shares: number[]): string | null {
  const total = shares.reduce((s, x) => s + x, 0);
  for (let i = 0; i < shares.length; i++) {
    if (shares[i] < 1) return `${placeLabel(i + 1)} place must get something.`;
    if (i > 0 && shares[i] > shares[i - 1]) return `${placeLabel(i + 1)} place can't get more than ${placeLabel(i)}.`;
  }
  if (total !== shareBasisPoints) {
    const diff = Math.abs(shareBasisPoints - total);
    return total < shareBasisPoints
      ? `The shares add up to ${percentLabel(total)}. ${percentLabel(diff)} still to give out.`
      : `The shares add up to ${percentLabel(total)}. Take off ${percentLabel(diff)}.`;
  }
  return null;
}

/** How one pool pays out, as the server stored it. */
export class PayoutRule {
  constructor(
    readonly mode: PayoutMode,
    readonly winners = 1,
    readonly shares: number[] = [],
    readonly limit = new WinnerRule(),
  ) {}

  static fromJson(json: Record<string, any>): PayoutRule {
    const mode = payoutModeFromWire(json.mode);
    const winners = Math.trunc(json.winners ?? 1);
    const shares = ((json.shares ?? []) as any[]).map((s) => Math.trunc(s ?? 0));
    return new PayoutRule(
      mode,
      mode === 'split' ? winners : 1,
      shares.length === winners ? shares : defaultShares(winners),
      WinnerRule.fromJson(json.limit),
    );
  }

  /** "Winner takes all" or "Top 3 share 50% · 30% · 20%". */
  get summary(): string {
    return this.mode === 'winner_takes_all'
      ? 'Winner takes all'
      : `Top ${this.winners} share ${this.shares.map(percentLabel).join(' · ')}`;
  }
}

/** What a creator chose on the form. shares is null when they kept the suggestion. */
export type PayoutChoice = { mode: PayoutMode; winners: number; shares: number[] | null };
export const defaultPayoutChoice: PayoutChoice = { mode: 'winner_takes_all', winners: 3, shares: null };

export function payoutChoiceJson(c: PayoutChoice): Record<string, unknown> {
  return {
    payout_mode: c.mode,
    ...(c.mode === 'split' ? { winners: c.winners } : {}),
    ...(c.mode === 'split' && c.shares ? { shares: c.shares } : {}),
  };
}
