import { useQueryClient } from '@tanstack/react-query';
import { router } from 'expo-router';
import React from 'react';
import { ScrollView, View } from 'react-native';

import { AppSettings, Dashboard, ThemeMode, displayEmail, firstName } from '@/domain/models';
import { auth, useAuth } from '@/state/auth';
import { keys, useDashboard } from '@/state/queries';
import { settings as settingsStore, useSettings } from '@/state/settings';
import { AppSpacing, alpha, useScheme } from '@/theme/theme';
import { OutlinedButton } from '@/ui/Buttons';
import { SegmentedButton, SwitchTile } from '@/ui/Inputs';
import { AppBar, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { GradientPanel, StatusPill } from '@/ui/widgets';

export default function SettingsScreen() {
  const s = useScheme();
  const settings = useSettings();
  const dashboard = useDashboard();
  const { session } = useAuth();
  const profile = dashboard.data?.user ?? session?.user ?? null;
  const update = (next: AppSettings) => settingsStore.save(next);
  const push = settings.pushNotifications;
  return (
    <Scaffold appBar={<AppBar title="Settings" />}>
      <ScrollView contentContainerStyle={{ padding: AppSpacing.md }}>
        {profile ? (
          <GradientPanel>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <View
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: 28,
                  backgroundColor: alpha(s.primary, 0.15),
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <T v="titleLarge">{Array.from(firstName(profile))[0]?.toUpperCase() ?? 'M'}</T>
              </View>
              <View style={{ width: 14 }} />
              <View style={{ flex: 1 }}>
                <T v="titleMedium">{profile.fullName}</T>
                {displayEmail(profile) ? <T color={s.onSurfaceVariant}>{displayEmail(profile)}</T> : null}
                <View style={{ height: 6 }} />
                <StatusPill label={profile.status} />
              </View>
            </View>
          </GradientPanel>
        ) : null}
        <View style={{ height: 24 }} />
        <T v="titleLarge">Appearance</T>
        <View style={{ height: 10 }} />
        <SegmentedButton<ThemeMode>
          segments={[
            { value: 'system', label: 'System', icon: 'brightness_auto_rounded' },
            { value: 'light', label: 'Light', icon: 'light_mode_outlined' },
            { value: 'dark', label: 'Dark', icon: 'dark_mode_outlined' },
          ]}
          selected={settings.themeMode}
          onChange={(themeMode) => update({ ...settings, themeMode })}
        />
        <View style={{ height: 26 }} />
        <T v="titleLarge">Notifications</T>
        <View style={{ height: 8 }} />
        <GradientPanel padding={{ paddingHorizontal: 16, paddingVertical: 6 }}>
          <SwitchTile
            inset={0}
            title="Push notifications"
            subtitle="Master switch for device alerts"
            value={push}
            onChange={(v) => update({ ...settings, pushNotifications: v })}
          />
          <SwitchTile
            inset={0}
            title="Pool updates"
            subtitle="Entries, deadlines and settlements"
            value={settings.poolNotifications}
            disabled={!push}
            onChange={(v) => update({ ...settings, poolNotifications: v })}
          />
          <SwitchTile
            inset={0}
            title="Challenges"
            subtitle="Requests, results and refunds"
            value={settings.challengeNotifications}
            disabled={!push}
            onChange={(v) => update({ ...settings, challengeNotifications: v })}
          />
          <SwitchTile
            inset={0}
            title="Product news"
            subtitle="Occasional feature announcements"
            value={settings.marketingNotifications}
            disabled={!push}
            onChange={(v) => update({ ...settings, marketingNotifications: v })}
          />
        </GradientPanel>
        <View style={{ height: 26 }} />
        <OutlinedButton
          icon="logout_rounded"
          label="Sign out"
          onPress={async () => {
            await auth.logout();
            router.replace('/welcome');
          }}
        />
        <View style={{ height: 12 }} />
        <T v="labelSmall" center color={s.onSurfaceVariant}>
          FPLboardman is not affiliated with the Premier League. 18+ · Play responsibly.
        </T>
      </ScrollView>
    </Scaffold>
  );
}
