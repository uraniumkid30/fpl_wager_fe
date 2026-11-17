import { CampaignTheme } from '@/domain/models';
import { Brand } from '@/theme/theme';

/**
 * The look of each campaign banner, built from the brand palette. The admin
 * app's preview uses the same values (campaigns_screen.dart).
 */
export const campaignThemes: Record<
  CampaignTheme,
  { colors: [string, string, string]; accent: string; glow: string; icon: string }
> = {
  // Red Card Pink into Boardroom Purple: a fight to the last manager.
  rumble: { colors: [Brand.redCardPink, Brand.boardroomPurple, Brand.midnight], accent: Brand.pitchGreen, glow: '#FF4F8E', icon: 'sports_kabaddi' },
  pitch: { colors: ['#00B862', '#0F4B45', Brand.midnight], accent: Brand.pitchGreen, glow: Brand.pitchGreen, icon: 'sports_soccer' },
  cyan: { colors: ['#04C8D9', '#2A3E8C', Brand.midnight], accent: Brand.captainCyan, glow: Brand.captainCyan, icon: 'military_tech' },
  gold: { colors: ['#F5A524', '#8A2E3B', Brand.midnight], accent: '#FFD36B', glow: '#FFD36B', icon: 'emoji_events' },
  midnight: { colors: [Brand.boardroomPurple, '#26123A', Brand.midnight], accent: Brand.pitchGreen, glow: Brand.captainCyan, icon: 'auto_awesome' },
};
