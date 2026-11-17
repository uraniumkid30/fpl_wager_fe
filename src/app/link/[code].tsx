import { useLocalSearchParams } from 'expo-router';

import { LinkBrowserScreen } from '@/features/linkedBrowsers/LinkBrowserScreen';

/** The phone camera's link to the website code opens the app here: /link/CODE. */
export default function LinkRoute() {
  const { code } = useLocalSearchParams<{ code: string }>();
  return <LinkBrowserScreen key={code} code={String(code)} />;
}
