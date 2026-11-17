import * as Linking from 'expo-linking';
import React, { useRef, useState } from 'react';
import { View } from 'react-native';
import { WebView } from 'react-native-webview';
import type { WebViewProps } from 'react-native-webview';

import { useScheme } from '@/theme/theme';
import { FilledButton, IconButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppBar, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { confirm, openPage } from '@/ui/overlay';
import { ProgressBar } from '@/ui/widgets';

// react-native-webview's class typings do not line up with React 19.3's JSX types.
const WebViewView = WebView as unknown as React.ComponentType<WebViewProps & { ref?: React.Ref<WebView> }>;

/** How a checkout session ended. */
export type CheckoutOutcome = 'completed' | 'cancelled' | 'closed';

/** Addresses the page itself may load; anything else (tel:, a bank app link) goes to the phone. */
const PAGE_SCHEMES = new Set(['http:', 'https:', 'about:', 'data:', 'blob:']);

/**
 * The provider's hosted checkout page, shown over the whole app. It watches
 * where the page goes: the callback address (finished), the cancel address,
 * or Paystack's close page (3-D Secure done), then closes and reports the
 * outcome. It never decides whether money was received: the caller asks the
 * server. No key and no card detail passes through the app.
 */
export async function openCheckout(opts: { checkoutUrl: string; callbackUrl: string; providerLabel: string }): Promise<CheckoutOutcome> {
  const backRef: { current: (() => void) | null } = { current: null };
  const outcome = await openPage<CheckoutOutcome>((close) => <CheckoutPage {...opts} close={close} backRef={backRef} />, {
    onBack: () => backRef.current?.(),
  });
  return outcome ?? 'closed';
}

function parse(url: string) {
  try {
    return new URL(url);
  } catch {
    return null;
  }
}

function CheckoutPage({
  checkoutUrl,
  callbackUrl,
  providerLabel,
  close,
  backRef,
}: {
  checkoutUrl: string;
  callbackUrl: string;
  providerLabel: string;
  close: (o?: CheckoutOutcome) => void;
  backRef: { current: (() => void) | null };
}) {
  const s = useScheme();
  const web = useRef<WebView>(null);
  const [progress, setProgress] = useState(0);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [canGoBack, setCanGoBack] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const finished = useRef(false);
  const callback = parse(callbackUrl);

  const finish = (o: CheckoutOutcome) => {
    if (finished.current) return;
    finished.current = true;
    close(o);
  };

  /** What reaching a URL means for the checkout, or null to keep going. */
  const outcomeFor = (url: string): CheckoutOutcome | null => {
    const uri = parse(url);
    if (!uri) return null;
    // Paystack sends the customer here once their bank's 3-D Secure step is done.
    if (uri.host === 'standard.paystack.co' && uri.pathname === '/close') return 'completed';
    if (!callback) return null;
    const isCallback =
      uri.protocol === callback.protocol && uri.host === callback.host && uri.pathname === callback.pathname;
    if (!isCallback) return null;
    return uri.searchParams.get('status') === 'cancelled' ? 'cancelled' : 'completed';
  };

  const confirmLeave = async () => {
    if (finished.current) return;
    const leave = await confirm({
      title: 'Leave checkout?',
      message: 'If you have already paid, your wallet is still credited as soon as the payment is confirmed.',
      cancelLabel: 'Stay',
      confirmLabel: 'Leave',
    });
    if (leave) finish('closed');
  };

  // Back first steps back inside the checkout, then offers to leave.
  backRef.current = () => {
    if (finished.current) return;
    if (canGoBack) web.current?.goBack();
    else confirmLeave();
  };

  const loading = progress < 1 && loadError == null;
  return (
    <Scaffold
      appBar={
        <View>
          <AppBar
            leading={<IconButton icon="close_rounded" tooltip="Close checkout" onPress={confirmLeave} />}
            title={
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Icon name="lock_rounded" size={18} color={s.primary} />
                <View style={{ width: 8 }} />
                <T v="titleLarge" w={800} numberOfLines={1} style={{ flexShrink: 1 }}>{`${providerLabel} checkout`}</T>
              </View>
            }
          />
          <View style={{ height: 3 }}>{loading ? <ProgressBar height={3} value={progress === 0 ? null : progress} /> : null}</View>
        </View>
      }
    >
      {loadError == null ? (
        <WebViewView
          key={attempt}
          ref={web}
          source={{ uri: checkoutUrl }}
          javaScriptEnabled
          domStorageEnabled
          // Banks' 3-D Secure pages are built for real browsers: the system user agent is kept.
          onShouldStartLoadWithRequest={(request) => {
            const outcome = outcomeFor(request.url);
            if (outcome) {
              finish(outcome);
              return false;
            }
            const uri = parse(request.url);
            if (uri && !PAGE_SCHEMES.has(uri.protocol)) {
              // Nothing may be able to open it (a bank app that is not installed); the page stays open.
              Linking.openURL(request.url).catch(() => undefined);
              return false;
            }
            return true;
          }}
          onLoadStart={(e) => {
            // A second look at every page that starts loading, in case a redirect skipped the check above.
            const outcome = outcomeFor(e.nativeEvent.url);
            if (outcome) finish(outcome);
          }}
          onNavigationStateChange={(nav) => setCanGoBack(nav.canGoBack)}
          onLoadProgress={(e) => setProgress(e.nativeEvent.progress)}
          onError={() => {
            if (finished.current) return;
            setLoadError('The checkout page could not be loaded. Check your connection and try again.');
          }}
          style={{ flex: 1 }}
        />
      ) : (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 28 }}>
          <Icon name="wifi_off_rounded" size={52} color={s.onSurfaceVariant} />
          <View style={{ height: 16 }} />
          <T center>{loadError}</T>
          <View style={{ height: 22 }} />
          <FilledButton
            style={{ alignSelf: 'stretch' }}
            label="Try again"
            onPress={() => {
              setLoadError(null);
              setProgress(0);
              setAttempt((a) => a + 1);
            }}
          />
          <View style={{ height: 8 }} />
          <TextButton label="Close" onPress={() => finish('closed')} />
        </View>
      )}
    </Scaffold>
  );
}
