import { router } from 'expo-router';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Platform, View } from 'react-native';
import { WebView, WebViewMessageEvent } from 'react-native-webview';
import type { WebViewProps } from 'react-native-webview';

// react-native-webview's class typings do not line up with React 19.3's JSX types.
const WebViewView = WebView as unknown as React.ComponentType<WebViewProps & { ref?: React.Ref<WebView> }>;

import { AppException } from '@/core/errors';
import { auth } from '@/state/auth';
import { gateway } from '@/state/gateway';
import { AppSpacing, useScheme } from '@/theme/theme';
import { AppBar, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';

const FPL_HOME = 'https://fantasy.premierleague.com/';

/** Reads the OIDC session FPL's web app keeps in localStorage and posts it back (or null). */
const readSessionScript = (id: number) => `
  (function() {
    try {
      var key = Object.keys(localStorage).find(function (k) { return k.indexOf('oidc.user:') === 0; });
      window.ReactNativeWebView.postMessage(JSON.stringify({ id: ${id}, value: key ? localStorage.getItem(key) : null }));
    } catch (e) {
      window.ReactNativeWebView.postMessage(JSON.stringify({ id: ${id}, value: null }));
    }
  })();
  true;
`;

/** Drops that session from the page without logging out of FPL itself. */
const forgetSessionScript = `
  Object.keys(localStorage)
    .filter(function (k) { return k.indexOf('oidc.user:') === 0; })
    .forEach(function (k) { localStorage.removeItem(k); });
  true;
`;

/**
 * Keys of FPL's stored login that are credentials. They are stripped before
 * the rest is sent anywhere; only the refresh token is ever sent, on its
 * own, to complete the sign-in.
 */
const TOKEN_KEYS = new Set(['access_token', 'refresh_token', 'id_token', 'session_state', 'code_verifier']);
const withoutTokens = (source: Record<string, unknown>) =>
  Object.fromEntries(Object.entries(source).filter(([k]) => !TOKEN_KEYS.has(k)));

const isFplPage = (url: string) => {
  try {
    return new URL(url).hostname === 'fantasy.premierleague.com';
  } catch {
    return false;
  }
};

/**
 * "Sign in with FPL" — the sole account entry point.
 *
 * Opens FPL's real login page in a web view. The user types their FPL email
 * and password into fantasy.premierleague.com's own page; this app never sees
 * the password. Once login completes, the screen reads the OIDC refresh token
 * FPL's web app leaves in localStorage and sends it to our backend, together
 * with the non-secret part of the stored login. The access and id tokens never
 * leave the web view. The web view uses incognito storage, so nothing it holds
 * outlives this screen (signing out therefore also signs FPL out on the phone).
 */
export default function FplLoginScreen() {
  const s = useScheme();
  const web = useRef<WebView>(null);
  const [completing, setCompleting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const mounted = useRef(true);
  /** Bumped on every page load so an older poll loop stops when a newer page takes over. */
  const pageLoad = useRef(0);
  /** True while a sign-in attempt is in flight. */
  const submitting = useRef(false);
  /** FPL refresh tokens are single-use, so the same one is never sent twice. */
  const lastSubmitted = useRef<string | null>(null);
  const pending = useRef(new Map<number, (v: string | null) => void>());
  const seq = useRef(0);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  /** Runs the read script and waits (up to 2 s) for the page to answer. */
  const readSession = useCallback(
    () =>
      new Promise<string | null>((resolve) => {
        const id = ++seq.current;
        const timer = setTimeout(() => {
          pending.current.delete(id);
          resolve(null);
        }, 2000);
        pending.current.set(id, (v) => {
          clearTimeout(timer);
          resolve(v);
        });
        web.current?.injectJavaScript(readSessionScript(id));
      }),
    [],
  );

  const onMessage = (event: WebViewMessageEvent) => {
    // Only FPL's own page may hand over a session.
    if (!isFplPage(event.nativeEvent.url)) return;
    try {
      const data = JSON.parse(event.nativeEvent.data);
      const resolve = pending.current.get(data.id);
      if (resolve) {
        pending.current.delete(data.id);
        resolve(typeof data.value === 'string' ? data.value : null);
      }
    } catch {}
  };

  /** True once a session was found and handled; false if the page has none yet. */
  const trySignIn = async (): Promise<boolean> => {
    if (submitting.current) return true;
    const decoded = await readSession();
    if (decoded == null) return false;
    let refreshToken: string | null;
    let session: Record<string, unknown>;
    try {
      const oidcUser = JSON.parse(decoded);
      refreshToken = typeof oidcUser.refresh_token === 'string' ? oidcUser.refresh_token : null;
      session = withoutTokens(oidcUser);
    } catch {
      return false;
    }
    if (refreshToken == null || refreshToken === lastSubmitted.current) return refreshToken != null;

    submitting.current = true;
    lastSubmitted.current = refreshToken;
    if (mounted.current) {
      setCompleting(true);
      setError(null);
    }
    try {
      const signedIn = await gateway.continueWithFpl(refreshToken, session);
      if (!mounted.current) return true;
      auth.accept(signedIn);
      // The root layout takes the user on: to an invite they opened, or Home.
    } catch (e) {
      const expired = e instanceof AppException && e.code === 'FPL_SESSION_EXPIRED';
      if (expired) {
        // The token this page holds is dead. Forget it and reload so the user
        // can log in to FPL again and hand over a fresh one.
        web.current?.injectJavaScript(forgetSessionScript);
        web.current?.reload();
      }
      if (!mounted.current) return true;
      setCompleting(false);
      setError(
        expired
          ? 'Your FPL login has expired. Please log in to FPL again.'
          : 'Could not complete FPL sign-in. Please try again.',
      );
    } finally {
      submitting.current = false;
    }
    return true;
  };

  const onPageFinished = async (url: string) => {
    const load = ++pageLoad.current;
    // FPL's login pages never hold the session.
    if (!isFplPage(url) || url.includes('account.premierleague.com') || url.includes('as/authorization')) return;
    // FPL's web app finishes its login callback a moment after the page loads,
    // so look for the session a few times before giving up.
    for (let attempt = 0; attempt < 20; attempt++) {
      if (!mounted.current || load !== pageLoad.current) return;
      if (await trySignIn()) return;
      await new Promise((r) => setTimeout(r, 500));
    }
  };

  return (
    <Scaffold
      appBar={<AppBar title="Sign in with FPL" backIcon="close_rounded" onBack={() => router.replace('/welcome')} />}
    >
      {Platform.OS === 'web' ? null : (
        <WebViewView
          ref={web}
          source={{ uri: FPL_HOME }}
          incognito
          javaScriptEnabled
          domStorageEnabled
          sharedCookiesEnabled={false}
          onMessage={onMessage}
          onLoadEnd={(e: { nativeEvent: { url: string } }) => onPageFinished(e.nativeEvent.url)}
          startInLoadingState
          renderLoading={() => (
            <View style={{ position: 'absolute', top: 0, bottom: 0, left: 0, right: 0, alignItems: 'center', justifyContent: 'center' }}>
              <ActivityIndicator color={s.primary} />
            </View>
          )}
          style={{ flex: 1 }}
        />
      )}
      {completing ? (
        <View
          style={{
            position: 'absolute',
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            backgroundColor: 'rgba(0,0,0,0.45)',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <ActivityIndicator size="large" color={s.primary} />
        </View>
      ) : null}
      {error ? (
        <View
          style={{
            position: 'absolute',
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            backgroundColor: s.dark ? '#5C0A2A' : '#FFD9E3',
            borderRadius: 12,
            padding: 14,
          }}
        >
          <T color={s.dark ? '#FFD9E3' : '#5C0A2A'}>{error}</T>
        </View>
      ) : null}
    </Scaffold>
  );
}
