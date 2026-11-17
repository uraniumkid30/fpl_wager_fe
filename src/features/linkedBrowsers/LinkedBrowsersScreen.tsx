import { router } from 'expo-router';
import React, { useState } from 'react';
import { View } from 'react-native';

import { errorMessage } from '@/core/errors';
import { formatDate } from '@/core/format';
import { WebLink } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, useWebLinks } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppBar, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { confirm } from '@/ui/overlay';
import { GradientPanel, Loading } from '@/ui/widgets';

/** Profile → Linked browsers: browsers signed in by scanning their QR code, and the scanner. */
export default function LinkedBrowsersScreen() {
  const s = useScheme();
  const links = useWebLinks();
  return (
    <Scaffold appBar={<AppBar title="Linked browsers" />}>
      <RefreshScroll
        onRefresh={() => invalidate(keys.webLinks)}
        contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 48 }}
      >
        <GradientPanel colors={AppColors.heroPanel}>
          <Icon name="qr_code_scanner_rounded" color={AppColors.lime} size={34} />
          <View style={{ height: 12 }} />
          <T v="titleLarge" w={900} color="#FFFFFF">
            Use FPLboardman on a computer
          </T>
          <View style={{ height: 6 }} />
          <T color={AppColors.heroText} style={{ lineHeight: 20 }}>
            Open the FPLboardman website, then scan the code it shows. That browser stays signed in to your account for 90 days.
          </T>
          <View style={{ height: 16 }} />
          <FilledButton icon="qr_code_scanner_rounded" label="Link a browser" onPress={() => router.push('/linked-browsers/scan')} />
        </GradientPanel>
        <View style={{ height: 24 }} />
        <T v="titleLarge">Signed in</T>
        <View style={{ height: 10 }} />
        {links.isError ? (
          <T>{errorMessage(links.error)}</T>
        ) : !links.data ? (
          <Loading style={{ flex: 0, padding: 24 }} />
        ) : links.data.length === 0 ? (
          <T color={s.onSurfaceVariant}>No browsers are signed in to your account.</T>
        ) : (
          links.data.map((link) => (
            <View key={link.id} style={{ marginBottom: 10 }}>
              <LinkTile link={link} />
            </View>
          ))
        )}
      </RefreshScroll>
    </Scaffold>
  );
}

function LinkTile({ link }: { link: WebLink }) {
  const s = useScheme();
  const [busy, setBusy] = useState(false);
  const daysLeft = Math.floor((link.expiresAt.getTime() - Date.now()) / 86400_000);
  const unlink = async () => {
    const ok = await confirm({
      title: `Sign out ${link.label}?`,
      message: 'That browser is signed out of your account within a few minutes. You can link it again by scanning its code.',
      confirmLabel: 'Sign out',
    });
    if (!ok) return;
    setBusy(true);
    try {
      await gateway.revokeWebLink(link.id);
      invalidate(keys.webLinks);
      AppNotice.success(`${link.label} was signed out.`);
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };
  return (
    <GradientPanel padding={{ paddingLeft: 16, paddingRight: 8, paddingVertical: 12 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View
          style={{
            width: 40,
            height: 40,
            borderRadius: 20,
            backgroundColor: alpha(s.primary, 0.13),
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="computer_rounded" color={s.primary} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleSmall">{link.label}</T>
          <View style={{ height: 2 }} />
          <T v="bodySmall" color={s.onSurfaceVariant}>
            {`Linked ${formatDate(link.createdAt, 'd MMM y')} · ${
              daysLeft <= 0 ? 'expires today' : `expires in ${daysLeft} ${daysLeft === 1 ? 'day' : 'days'}`
            }`}
          </T>
        </View>
        <TextButton label="Sign out" busy={busy} onPress={busy ? null : unlink} />
      </View>
    </GradientPanel>
  );
}
