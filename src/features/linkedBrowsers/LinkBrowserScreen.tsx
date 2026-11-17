import { useQuery } from '@tanstack/react-query';
import { router } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView, View } from 'react-native';

import { AppException, errorMessage } from '@/core/errors';
import { gateway } from '@/state/gateway';
import { invalidate, keys } from '@/state/queries';
import { AppSpacing, useScheme } from '@/theme/theme';
import { FilledButton, OutlinedButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppBar, Scaffold, goBack } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { GradientPanel, Loading } from '@/ui/widgets';

/** Approve signing a browser in, after scanning its QR code (in the app, or with the phone's camera). */
export function LinkBrowserScreen({ code }: { code: string }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const request = useQuery({ queryKey: ['qrRequest', code], queryFn: () => gateway.scanQrLogin(code), gcTime: 0 });
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const leave = () => goBack('/linked-browsers');

  const answer = async (approve: boolean) => {
    setBusy(true);
    try {
      if (approve) {
        await gateway.approveQrLogin(code);
        invalidate(keys.webLinks);
        setDone(true);
      } else {
        await gateway.declineQrLogin(code);
        AppNotice.info('Sign-in declined. That browser was not signed in.');
        leave();
      }
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  let content: React.ReactNode;
  if (request.isError) {
    const expired = request.error instanceof AppException && request.error.code === 'QR_EXPIRED';
    content = (
      <GradientPanel>
        <View style={{ alignItems: 'center' }}>
          <Icon name="qr_code_2_rounded" size={44} color={s.error} />
        </View>
        <View style={{ height: 12 }} />
        <T center>
          {expired ? 'This code has expired or was already used. Scan the new code on the website.' : errorMessage(request.error)}
        </T>
        <View style={{ height: 18 }} />
        <FilledButton icon="qr_code_scanner_rounded" label="Scan again" onPress={() => router.replace('/linked-browsers/scan')} />
      </GradientPanel>
    );
  } else if (!request.data) {
    content = <Loading style={{ flex: 0 }} />;
  } else if (done) {
    const value = request.data;
    content = (
      <GradientPanel>
        <View style={{ alignItems: 'center' }}>
          <Icon name="check_circle_rounded" size={52} color={s.positive} />
        </View>
        <View style={{ height: 14 }} />
        <T v="titleLarge" w={800} center>{`${value.label} is signed in`}</T>
        <View style={{ height: 8 }} />
        <T center color={muted} style={{ lineHeight: 20 }}>
          {`It stays signed in for ${value.linkDays} days. You can sign it out any time from Profile, Linked browsers.`}
        </T>
        <View style={{ height: 20 }} />
        <FilledButton label="Done" onPress={leave} />
      </GradientPanel>
    );
  } else {
    const value = request.data;
    content = (
      <GradientPanel>
        <View style={{ alignItems: 'center' }}>
          <Icon name="computer_rounded" size={44} color={s.primary} />
        </View>
        <View style={{ height: 14 }} />
        <T v="titleLarge" w={800} center>{`Sign in on ${value.label}?`}</T>
        <View style={{ height: 8 }} />
        <T center color={muted} style={{ lineHeight: 20 }}>
          {`That browser will be signed in to your FPLboardman account, wallet included, for ${value.linkDays} days. Only approve it if you are signing in there yourself right now.`}
        </T>
        <View style={{ height: 22 }} />
        <FilledButton icon="check_rounded" label="Yes, sign it in" busy={busy} onPress={() => answer(true)} />
        <View style={{ height: 10 }} />
        <OutlinedButton label="No, it wasn’t me" onPress={busy ? null : () => answer(false)} />
      </GradientPanel>
    );
  }

  return (
    <Scaffold appBar={<AppBar title="Sign in on a browser" onBack={leave} />}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: AppSpacing.lg }}>
        <View style={{ width: '100%', maxWidth: 440, alignSelf: 'center' }}>{content}</View>
      </ScrollView>
    </Scaffold>
  );
}
