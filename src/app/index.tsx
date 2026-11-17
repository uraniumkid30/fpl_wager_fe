import { Redirect } from 'expo-router';

/** "/" opens Home; signed-out users are sent to Welcome by the root layout. */
export default function Index() {
  return <Redirect href="/home" />;
}
