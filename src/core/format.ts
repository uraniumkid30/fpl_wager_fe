import { Scheme } from '@/theme/theme';

const nf = new Intl.NumberFormat('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/**
 * An amount of money as people read it: "₦10.00" for 1000.
 * Every amount is held in kobo, 100 to the naira; this is the one place that
 * turns one into text. It always shows two decimals.
 */
export function money(cents: number): string {
  const naira = cents / 100;
  const text = nf.format(Math.abs(naira));
  return `${naira < 0 ? '-' : ''}₦${text}`;
}

/** "+ ₦300.00" for money coming in, "− ₦300.00" for money going out. */
export function signedMoney(cents: number): string {
  if (cents === 0) return money(0);
  return `${cents > 0 ? '+' : '−'} ${money(Math.abs(cents))}`;
}

/** Green for money coming in, red for money going out (undefined for nothing). */
export function moneyColor(scheme: Scheme, cents: number): string | undefined {
  if (cents === 0) return undefined;
  return cents > 0 ? scheme.positive : scheme.error;
}

/** Whole numbers with thousands separators ("12,345"). */
export const grouped = (n: number) => new Intl.NumberFormat('en-NG').format(n);

const pad = (n: number) => String(n).padStart(2, '0');
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** A tiny subset of intl's DateFormat patterns: EEE, d, dd, MMM, y, yyyy, HH, mm, ss. */
export function formatDate(date: Date, pattern: string): string {
  const tokens: Record<string, () => string> = {
    EEE: () => DAYS[date.getDay()],
    yyyy: () => String(date.getFullYear()),
    y: () => String(date.getFullYear()),
    MMM: () => MONTHS[date.getMonth()],
    MM: () => pad(date.getMonth() + 1),
    dd: () => pad(date.getDate()),
    d: () => String(date.getDate()),
    HH: () => pad(date.getHours()),
    mm: () => pad(date.getMinutes()),
    ss: () => pad(date.getSeconds()),
  };
  return pattern.replace(/EEE|yyyy|y|MMM|MM|dd|d|HH|mm|ss/g, (t) => tokens[t]());
}
