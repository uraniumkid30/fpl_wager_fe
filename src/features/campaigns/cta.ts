import * as Linking from 'expo-linking';
import { router } from 'expo-router';

import { Campaign } from '@/domain/models';

/** Does what a campaign's button says: its page, a pool, a page of the app or a web address. */
export function openCampaignAction(campaign: Campaign) {
  switch (campaign.ctaKind) {
    case 'pool':
      router.push(`/pools/${campaign.ctaTarget}`);
      return;
    case 'route':
      // The server only accepts paths that start with a single "/".
      if (campaign.ctaTarget.startsWith('/') && !campaign.ctaTarget.startsWith('//')) router.push(campaign.ctaTarget as never);
      return;
    case 'url':
      if (campaign.ctaTarget.startsWith('https://')) Linking.openURL(campaign.ctaTarget).catch(() => undefined);
      return;
    default:
      router.push(`/campaigns/${campaign.slug}`);
  }
}

/** "9d 5h", "5h 12m" or "12m". */
export function shortCountdown(to: Date, now: Date): string | null {
  const total = Math.floor((to.getTime() - now.getTime()) / 60000);
  if (total <= 0) return null;
  const days = Math.floor(total / 1440);
  const hours = Math.floor(total / 60) % 24;
  const minutes = total % 60;
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}
