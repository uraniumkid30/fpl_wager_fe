import { router } from 'expo-router';
import React from 'react';
import { Platform, View } from 'react-native';

import { money } from '@/core/format';
import { Dashboard, bankSummary, displayEmail, firstName } from '@/domain/models';
import { openLinkTeamDialog } from '@/features/team/linkTeam';
import { auth } from '@/state/auth';
import { invalidate, keys, useBankAccount, useDashboard } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { FilledButton, OutlinedButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppHeader, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AsyncContent, Divider, FitText, GradientPanel, StatusPill } from '@/ui/widgets';

/**
 * The Profile tab: who you are first, then Wallet (Top up, Withdraw), the bank
 * account, History, linked browsers and Settings.
 */
export default function ProfileScreen() {
  const dashboard = useDashboard();
  return (
    <Scaffold appBar={<AppHeader title="Profile" />}>
      <AsyncContent query={dashboard} onRetry={() => invalidate(keys.dashboard)} data={(value) => <Body value={value} />} />
    </Scaffold>
  );
}

function Body({ value }: { value: Dashboard }) {
  const s = useScheme();
  const user = value.user;
  const team = value.team;
  const fplId = team?.entryId ?? user.fplEntryId;
  const ledgerCount = value.wallet.ledger.length;
  const bankAccount = useBankAccount();
  const email = displayEmail(user);
  const initial = Array.from(firstName(user))[0]?.toUpperCase() ?? 'M';
  return (
    <RefreshScroll
      onRefresh={async () => {
        invalidate(keys.wallet, keys.bankAccount);
        await invalidate(keys.dashboard);
      }}
      contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}
    >
      {/* Account */}
      <GradientPanel colors={AppColors.heroPanel}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View
            style={{
              width: 60,
              height: 60,
              borderRadius: 30,
              backgroundColor: alpha(AppColors.lime, 0.18),
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <T v="headlineSmall" w={900} color={AppColors.lime}>
              {initial}
            </T>
          </View>
          <View style={{ width: 16 }} />
          <View style={{ flex: 1 }}>
            <T v="titleLarge" w={900} color="#FFFFFF">
              {user.fullName}
            </T>
            <View style={{ height: 4 }} />
            <T color={AppColors.heroText}>{team == null ? 'No FPL team linked' : team.teamName}</T>
          </View>
        </View>
      </GradientPanel>
      <View style={{ height: 14 }} />
      <GradientPanel padding={{ paddingHorizontal: 20, paddingVertical: 8 }}>
        <Field icon="badge_outlined" label="Account name" value={user.fullName} />
        <Divider />
        <Field
          icon="sports_soccer_rounded"
          label="FPL ID"
          value={fplId == null ? 'Not linked' : String(fplId)}
          trailing={fplId == null ? <TextButton label="Link team" onPress={() => openLinkTeamDialog()} /> : null}
        />
        <Divider />
        <Field
          icon="mail_outline_rounded"
          label="Email"
          value={email || 'Not added'}
          trailing={
            user.emailVerified ? (
              <StatusPill label="Verified" color={s.positive} />
            ) : (
              <TextButton label="Verify email" onPress={() => router.push('/verify-email')} />
            )
          }
        />
      </GradientPanel>

      {/* Wallet */}
      <View style={{ height: 26 }} />
      <T v="titleLarge">Wallet</T>
      <View style={{ height: 10 }} />
      <GradientPanel onPress={() => router.navigate('/profile/wallet')}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={{ flex: 1 }}>
            <T v="labelSmall" w={800} color={s.onSurfaceVariant} style={{ letterSpacing: 0.7 }}>
              AVAILABLE BALANCE
            </T>
            <View style={{ height: 6 }} />
            <FitText v="headlineMedium" w={900} mono color={s.secondary}>
              {money(value.wallet.availableCents)}
            </FitText>
          </View>
          <Icon name="chevron_right_rounded" />
        </View>
        <View style={{ height: 6 }} />
        <T color={s.onSurfaceVariant}>{`${money(value.wallet.lockedCents)} locked in active games`}</T>
        <View style={{ height: 16 }} />
        <View style={{ flexDirection: 'row' }}>
          <View style={{ flex: 1 }}>
            <FilledButton label="Top up" onPress={() => router.push('/wallet/top-up')} />
          </View>
          <View style={{ width: 10 }} />
          <View style={{ flex: 1 }}>
            <OutlinedButton label="Withdraw" onPress={() => router.push('/withdraw')} style={{ minHeight: 54 }} />
          </View>
        </View>
      </GradientPanel>

      {/* Bank account */}
      <View style={{ height: 12 }} />
      <LinkTile
        icon="account_balance_outlined"
        title="Bank account"
        subtitle={
          bankAccount.isError
            ? 'Tap to view your bank account'
            : bankAccount.data === undefined
              ? 'Loading…'
              : bankAccount.data == null
                ? 'Add the account your withdrawals are paid to'
                : `${bankSummary(bankAccount.data)} · ${bankAccount.data.accountName}`
        }
        onPress={() => router.push('/bank-account')}
      />

      {/* History */}
      <View style={{ height: 26 }} />
      <T v="titleLarge">History</T>
      <View style={{ height: 10 }} />
      <LinkTile
        icon="history_rounded"
        title="Stakes, winnings and withdrawals"
        subtitle={
          ledgerCount === 0
            ? 'Nothing yet — your activity appears after you play.'
            : `${ledgerCount} recent ${ledgerCount === 1 ? 'entry' : 'entries'}`
        }
        onPress={() => router.navigate('/profile/history')}
      />
      <View style={{ height: 10 }} />
      <LinkTile
        icon="leaderboard_rounded"
        title="Gameweek history"
        subtitle="Your position each gameweek, and the pools you played"
        onPress={() => router.push('/gameweeks')}
      />

      {/* Only the phone app can scan the website's sign-in code. */}
      {Platform.OS !== 'web' ? (
        <>
          <View style={{ height: 26 }} />
          <T v="titleLarge">Linked browsers</T>
          <View style={{ height: 10 }} />
          <LinkTile
            icon="qr_code_scanner_rounded"
            title="Linked browsers"
            subtitle="Sign in on the website by scanning its code"
            onPress={() => router.push('/linked-browsers')}
          />
        </>
      ) : null}

      <View style={{ height: 26 }} />
      <LinkTile icon="tune_rounded" title="Settings" subtitle="Appearance and notifications" onPress={() => router.push('/settings')} />
      <View style={{ height: 14 }} />
      <OutlinedButton
        icon="logout_rounded"
        label="Sign out"
        onPress={async () => {
          await auth.logout();
          router.replace('/welcome');
        }}
      />
    </RefreshScroll>
  );
}

/** One labelled value in the account panel, with an optional action or badge. */
function Field({ icon, label, value, trailing }: { icon: string; label: string; value: string; trailing?: React.ReactNode }) {
  const s = useScheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 12 }}>
      <Icon name={icon} color={s.primary} />
      <View style={{ width: 14 }} />
      <View style={{ flex: 1 }}>
        <T v="labelMedium" color={s.onSurfaceVariant}>
          {label}
        </T>
        <View style={{ height: 2 }} />
        <T v="titleMedium" numberOfLines={1}>
          {value}
        </T>
      </View>
      {trailing ? <View style={{ marginLeft: 8 }}>{trailing}</View> : null}
    </View>
  );
}

function LinkTile({ icon, title, subtitle, onPress }: { icon: string; title: string; subtitle: string; onPress: () => void }) {
  const s = useScheme();
  return (
    <GradientPanel onPress={onPress} padding={18}>
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
          <Icon name={icon} color={s.primary} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleMedium">{title}</T>
          <T v="bodySmall" color={s.onSurfaceVariant}>
            {subtitle}
          </T>
        </View>
        <Icon name="chevron_right_rounded" />
      </View>
    </GradientPanel>
  );
}
