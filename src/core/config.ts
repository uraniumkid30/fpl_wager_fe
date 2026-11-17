import { Platform } from 'react-native';

const trim = (url: string) => url.replace(/\/+$/, '');

/**
 * Build-time settings (EXPO_PUBLIC_* variables are inlined by Metro).
 * EXPO_PUBLIC_API_BASE_URL=http://127.0.0.1:8080 points a build at a local server.
 */
export const AppConfig = {
  apiBaseUrl: trim(process.env.EXPO_PUBLIC_API_BASE_URL || 'https://api.fplboardman.com'),
  useDemoData: process.env.EXPO_PUBLIC_USE_DEMO_DATA === 'true',
  get enableDevCredit() {
    return this.useDemoData || process.env.EXPO_PUBLIC_ENABLE_DEV_CREDIT === 'true';
  },

  /**
   * Where the payment provider sends the customer when checkout finishes.
   * On a phone the checkout runs in an in-app web view that watches for this
   * address and closes itself; on the web the provider redirects the tab to
   * the app's confirmation route.
   */
  get paymentCallbackUrl(): string {
    const configured = process.env.EXPO_PUBLIC_PAYMENT_CALLBACK_URL;
    if (configured) return configured;
    if (Platform.OS === 'web') return `${window.location.origin}/payments/callback`;
    return `${this.apiBaseUrl}/v1/payments/callback`;
  },

  /** Where the provider sends the customer on cancel (Paystack only). */
  get paymentCancelUrl(): string {
    if (Platform.OS === 'web') return `${window.location.origin}/wallet/top-up`;
    const url = new URL(this.paymentCallbackUrl);
    url.searchParams.set('status', 'cancelled');
    return url.toString();
  },

  /** The link a pool's creator shares so others can join it. */
  poolInviteUrl: (code: string) => `${AppConfig.apiBaseUrl}/v1/join/${code}`,

  /** What the website's sign-in QR code holds. */
  webLinkUrl: (code: string) => `${AppConfig.apiBaseUrl}/v1/link/${code}`,
};
