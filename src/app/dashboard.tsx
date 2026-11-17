import { Redirect } from 'expo-router';

// The home page used to be called the dashboard; old links still work.
export default function Dashboard() {
  return <Redirect href="/home" />;
}
