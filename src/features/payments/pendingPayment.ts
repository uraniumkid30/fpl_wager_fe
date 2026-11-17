import { Platform } from 'react-native';

const KEY = 'fplboardman.pending_payment';

/**
 * On the web the checkout takes over the tab. The reference of the payment
 * being made is kept in sessionStorage so the confirmation page can check it
 * even when the provider's return address does not carry it.
 */
export function rememberPendingPayment(reference: string) {
  if (Platform.OS !== 'web') return;
  try {
    window.sessionStorage.setItem(KEY, JSON.stringify({ reference, at: Date.now() }));
  } catch {}
}

/** The reference kept by rememberPendingPayment within the last 2 hours, once. */
export function takePendingPayment(): string | null {
  if (Platform.OS !== 'web') return null;
  try {
    const raw = window.sessionStorage.getItem(KEY);
    if (!raw) return null;
    const { reference, at } = JSON.parse(raw);
    if (typeof reference !== 'string' || Date.now() - Number(at) > 2 * 3600_000) return null;
    return reference;
  } catch {
    return null;
  }
}

export function forgetPendingPayment() {
  if (Platform.OS !== 'web') return;
  try {
    window.sessionStorage.removeItem(KEY);
  } catch {}
}
