import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import QRCode from 'react-native-qrcode-svg';

import { AppConfig } from '@/core/config';
import { errorMessage } from '@/core/errors';
import { QrLogin, QrStatus } from '@/domain/models';
import { auth } from '@/state/auth';
import { gateway } from '@/state/gateway';
import { Brand, alpha, useScheme } from '@/theme/theme';
import { FilledButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { T } from '@/ui/Text';

/** New codes made without anyone touching the page before it waits (about 20 minutes). */
const AUTO_RENEWALS = 10;
const POLL_EVERY = 2000;

/**
 * "Scan with your phone" on the website, like WhatsApp Web. A code lasts two
 * minutes; a new one replaces it on its own for a while. Once the phone
 * approves, this browser is signed in for 90 days.
 */
export function WebQrSignIn() {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const [login, setLogin] = useState<QrLogin | null>(null);
  const [status, setStatus] = useState<QrStatus>('pending');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const polling = useRef(false);
  const renewals = useRef(0);
  const mounted = useRef(true);
  const loginRef = useRef<QrLogin | null>(null);
  const statusRef = useRef<QrStatus>('pending');

  const stop = () => {
    if (timer.current) clearInterval(timer.current);
    timer.current = null;
  };

  const newCode = useCallback(async (byUser = false) => {
    if (byUser) renewals.current = 0;
    stop();
    setLoading(true);
    setError(null);
    try {
      const next = await gateway.createQrLogin();
      if (!mounted.current) return;
      loginRef.current = next;
      statusRef.current = 'pending';
      setLogin(next);
      setStatus('pending');
      setLoading(false);
      timer.current = setInterval(poll, POLL_EVERY);
    } catch (e) {
      if (!mounted.current) return;
      setLoading(false);
      setError(errorMessage(e));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const poll = async () => {
    const current = loginRef.current;
    if (!current || polling.current || !mounted.current) return;
    polling.current = true;
    try {
      const result = await gateway.pollQrLogin(current);
      if (!mounted.current) return;
      if (result.session) {
        stop();
        // Signed in: the root layout takes the browser into the app.
        auth.accept(result.session);
        return;
      }
      switch (result.status) {
        case 'expired':
        case 'consumed':
          stop();
          if (renewals.current < AUTO_RENEWALS) {
            renewals.current++;
            newCode();
          } else {
            statusRef.current = 'expired';
            setStatus('expired');
          }
          break;
        case 'declined':
          stop();
          statusRef.current = 'declined';
          setStatus('declined');
          break;
        default:
          if (result.status !== statusRef.current) {
            statusRef.current = result.status;
            setStatus(result.status);
          }
      }
    } catch {
      // A missed poll is tried again two seconds later.
    } finally {
      polling.current = false;
    }
  };

  useEffect(() => {
    mounted.current = true;
    newCode();
    return () => {
      mounted.current = false;
      stop();
    };
  }, [newCode]);

  const days = login?.linkDays ?? 90;
  const cover = status === 'expired' ? 'The code expired.' : status === 'declined' ? 'The sign-in was declined on the phone.' : null;

  let code: React.ReactNode = null;
  if (loading && !login) {
    code = <ActivityIndicator color={Brand.boardroomPurple} />;
  } else if (error && !login) {
    code = <Overlay text="Could not get a sign-in code." action="Try again" onAction={() => newCode(true)} />;
  } else if (login) {
    const qr = <QRCode value={AppConfig.webLinkUrl(login.code)} size={202} color={Brand.midnight} backgroundColor="#FFFFFF" />;
    code =
      cover == null && !loading ? (
        qr
      ) : (
        <View style={{ width: 202, height: 202, alignItems: 'center', justifyContent: 'center' }}>
          <View style={{ position: 'absolute', opacity: 0.12 }}>{qr}</View>
          {loading ? (
            <ActivityIndicator color={Brand.boardroomPurple} />
          ) : (
            <Overlay text={cover!} action="Show a new code" onAction={() => newCode(true)} />
          )}
        </View>
      );
  }

  return (
    <View>
      <T v="headlineSmall" w={800} center style={{ letterSpacing: -0.4 }}>
        Sign in with your phone
      </T>
      <View style={{ height: 14 }} />
      <View style={{ alignItems: 'center' }}>
        <View
          style={{
            width: 232,
            height: 232,
            backgroundColor: '#FFFFFF',
            borderRadius: 18,
            borderWidth: 1,
            borderColor: alpha(s.outlineVariant, 0.6),
            padding: 14,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {code}
        </View>
      </View>
      <View style={{ height: 16 }} />
      {status === 'scanned' ? (
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            paddingHorizontal: 14,
            paddingVertical: 12,
            borderRadius: 14,
            backgroundColor: alpha(s.primary, 0.1),
          }}
        >
          <Icon name="phonelink_lock_rounded" color={s.primary} />
          <View style={{ width: 10 }} />
          <T style={{ flex: 1 }}>Code scanned. Approve the sign-in on your phone.</T>
        </View>
      ) : (
        <>
          <Step n={1} text="Open FPLboardman on your phone." />
          <Step n={2} text="Go to Profile, then Linked browsers." />
          <Step n={3} text="Tap Link a browser and point your phone at this code." />
        </>
      )}
      <View style={{ height: 8 }} />
      <T v="bodySmall" center color={muted}>
        {`This browser then stays signed in for ${days} days, or until you unlink it from your phone.`}
      </T>
    </View>
  );
}

function Overlay({ text, action, onAction }: { text: string; action: string; onAction: () => void }) {
  return (
    <View style={{ alignItems: 'center' }}>
      <T center w={600} color={Brand.midnight}>
        {text}
      </T>
      <View style={{ height: 10 }} />
      <FilledButton icon="refresh_rounded" label={action} onPress={onAction} style={{ alignSelf: "stretch" }} />
    </View>
  );
}

function Step({ n, text }: { n: number; text: string }) {
  const s = useScheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 4 }}>
      <View
        style={{
          width: 22,
          height: 22,
          borderRadius: 11,
          backgroundColor: alpha(s.primary, 0.14),
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <T w={800} color={s.primary} style={{ fontSize: 12, lineHeight: 16 }}>
          {String(n)}
        </T>
      </View>
      <View style={{ width: 10 }} />
      <T v="bodyMedium" style={{ flex: 1 }}>
        {text}
      </T>
    </View>
  );
}
