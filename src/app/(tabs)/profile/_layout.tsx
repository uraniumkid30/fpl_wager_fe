import { Stack } from 'expo-router';

/** Wallet and History live under Profile, so Back returns to it. */
export default function ProfileStack() {
  return <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }} />;
}
