import { useLocalSearchParams } from 'expo-router';

import { JoinPoolScreen } from '@/features/pools/PoolDetailScreen';

/** Where an invite link lands: /join/CODE shows the private pool, ready to join. */
export default function JoinRoute() {
  const { code } = useLocalSearchParams<{ code: string }>();
  return <JoinPoolScreen key={code} code={String(code)} />;
}
