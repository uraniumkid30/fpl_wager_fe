import { router } from 'expo-router';

import { AppException } from '@/core/errors';
import { AppNotice } from '@/ui/notice';

export const isInsufficientFunds = (error: unknown) =>
  error instanceof AppException && error.code === 'INSUFFICIENT_FUNDS';

/** When the wallet is too low for what was tried, says so and opens Top up. */
export function openTopUpIfInsufficientFunds(error: unknown): boolean {
  if (!isInsufficientFunds(error)) return false;
  AppNotice.info('Your wallet balance is too low for this. Top up to continue.');
  router.push('/wallet/top-up');
  return true;
}
