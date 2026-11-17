import {
  JetBrainsMono_400Regular,
  JetBrainsMono_500Medium,
  JetBrainsMono_700Bold,
  JetBrainsMono_800ExtraBold,
} from '@expo-google-fonts/jetbrains-mono';
import {
  Outfit_400Regular,
  Outfit_500Medium,
  Outfit_600SemiBold,
  Outfit_700Bold,
  Outfit_800ExtraBold,
  Outfit_900Black,
  useFonts,
} from '@expo-google-fonts/outfit';
import { QueryClientProvider } from '@tanstack/react-query';
import { Stack, router, usePathname, useGlobalSearchParams } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import * as SystemUI from 'expo-system-ui';
import React, { useEffect, useMemo } from 'react';
import { Platform, View, useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { SplashView } from '@/features/auth/SplashScreen';
import { auth, useAuth } from '@/state/auth';
import { queryClient } from '@/state/queries';
import { useRealtimeSync, useWalletLive } from '@/state/realtime';
import { settings, useSettings } from '@/state/settings';
import { ThemeContext, schemes } from '@/theme/theme';
import { NoticeHost } from '@/ui/notice';
import { OverlayHost, closeAllOverlays } from '@/ui/overlay';

SplashScreen.preventAutoHideAsync().catch(() => undefined);


/**
 * Where to go once the app knows whether someone is signed in. An invite
 * link (/join/CODE) or a browser link (/link/CODE) opened while signed out is
 * kept until the user has signed in.
 */
let returnTo: string | null = null;
const isInvite = (p: string | null) => !!p && (p.startsWith('/join/') || p.startsWith('/link/'));
const PUBLIC = new Set(['/welcome', '/fpl-login', '/email-sign-in']);

function useAuthRedirect() {
  const { loading, session } = useAuth();
  const pathname = usePathname();
  const params = useGlobalSearchParams();
  const full = useMemo(() => {
    const q = Object.entries(params)
      .filter(([, v]) => typeof v === 'string')
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v as string)}`)
      .join('&');
    return q && !isInvite(pathname) ? `${pathname}?${q}` : pathname;
  }, [pathname, params]);

  useEffect(() => {
    const isPublic = PUBLIC.has(pathname);
    if (loading) {
      if (!isPublic && pathname !== '/') returnTo = full;
      return;
    }
    // FPL's sign-in needs the in-app browser of the mobile app.
    if (Platform.OS === 'web' && pathname === '/fpl-login') {
      router.replace('/welcome');
      return;
    }
    if (!session) {
      closeAllOverlays();
      if (isInvite(pathname)) returnTo = full;
      else if (!isInvite(returnTo)) returnTo = null;
      if (!isPublic) router.replace('/welcome');
      return;
    }
    if (isPublic || pathname === '/') {
      const target = returnTo ?? '/home';
      returnTo = null;
      router.replace(target as never);
    } else if (returnTo && returnTo === full) {
      returnTo = null;
    }
  }, [loading, session, pathname, full]);
}

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    Outfit_400Regular,
    Outfit_500Medium,
    Outfit_600SemiBold,
    Outfit_700Bold,
    Outfit_800ExtraBold,
    Outfit_900Black,
    JetBrainsMono_400Regular,
    JetBrainsMono_500Medium,
    JetBrainsMono_700Bold,
    JetBrainsMono_800ExtraBold,
  });
  const system = useColorScheme();
  const { themeMode } = useSettings();
  const scheme = (themeMode === 'system' ? system : themeMode) === 'light' ? schemes.light : schemes.dark;
  const { loading } = useAuth();

  useEffect(() => {
    settings.load();
    auth.restore();
  }, []);

  useEffect(() => {
    if (fontsLoaded) SplashScreen.hideAsync().catch(() => undefined);
  }, [fontsLoaded]);

  useEffect(() => {
    SystemUI.setBackgroundColorAsync(scheme.scaffold).catch(() => undefined);
    if (Platform.OS === 'web') document.body.style.backgroundColor = scheme.scaffold;
  }, [scheme]);

  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeContext.Provider value={scheme}>
          <StatusBar style={scheme.dark ? 'light' : 'dark'} />
          <AppBody ready={fontsLoaded} loading={loading} />
        </ThemeContext.Provider>
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}

function AppBody({ ready, loading }: { ready: boolean; loading: boolean }) {
  useAuthRedirect();
  useRealtimeSync();
  useWalletLive();
  // Pages mount only once the saved sign-in has been read, so their first
  // requests already carry it.
  const showApp = ready && !loading;
  return (
    <View style={{ flex: 1 }}>
      {showApp ? (
        <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }}>
          <Stack.Screen name="(tabs)" options={{ animation: 'none' }} />
          <Stack.Screen name="welcome" options={{ animation: 'fade' }} />
        </Stack>
      ) : (
        <SplashView />
      )}
      <OverlayHost />
      <NoticeHost />
    </View>
  );
}
