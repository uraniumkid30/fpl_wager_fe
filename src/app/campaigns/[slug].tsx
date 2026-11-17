import { useLocalSearchParams } from 'expo-router';

import { CampaignScreen } from '@/features/campaigns/CampaignScreen';

export default function CampaignRoute() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  return <CampaignScreen key={slug} slug={String(slug)} />;
}
