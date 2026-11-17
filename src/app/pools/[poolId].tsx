import { useLocalSearchParams } from 'expo-router';

import { PoolDetailScreen } from '@/features/pools/PoolDetailScreen';

export default function PoolRoute() {
  const { poolId } = useLocalSearchParams<{ poolId: string }>();
  return <PoolDetailScreen key={poolId} poolId={String(poolId)} />;
}
