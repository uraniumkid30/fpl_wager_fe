import { router } from 'expo-router';
import React from 'react';
import { ScrollView, View, useWindowDimensions } from 'react-native';

import { money } from '@/core/format';
import { Dashboard, displayEmail, firstName } from '@/domain/models';
import { Pool, awaitingAdminApproval, canJoin, hasJoined, isLive, isPendingMember } from '@/domain/pool';
import { openLinkTeamDialog } from '@/features/team/linkTeam';
import { invalidate, keys, useDashboard, usePools } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppHeader, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { openSheet } from '@/ui/overlay';
import { CampaignCarousel } from '@/features/campaigns/CampaignBanner';
import { AsyncContent, FadeSlideIn, FitText, FlipDeadlineCountdown, GradientPanel, Loading, StatusPill } from '@/ui/widgets';

export default function DashboardScreen() {
  const dashboard = useDashboard();
  return (
    <Scaffold appBar={<AppHeader />}>
      <AsyncContent query={dashboard} onRetry={() => invalidate(keys.dashboard)} data={(value) => <Body value={value} />} />
    </Scaffold>
  );
}

function Body({ value }: { value: Dashboard }) {
  const s = useScheme();
  const pools = usePools().data ?? [];
  return (
    <RefreshScroll
      onRefresh={async () => {
        invalidate(keys.pools, keys.campaignsAll);
        await invalidate(keys.dashboard);
      }}
      contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}
    >
      <FadeSlideIn>
        <T v="headlineMedium">{`Hello, ${firstName(value.user)}`}</T>
      </FadeSlideIn>
      <View style={{ height: 4 }} />
      <T color={s.onSurfaceVariant}>{`Gameweek ${value.currentGameweek} · make every point count`}</T>
      <View style={{ height: 20 }} />
      <CampaignCarousel placement="home" bottomSpacing={20} />
      {value.team == null ? (
        <>
          <GradientPanel onPress={() => openLinkTeamDialog()} colors={AppColors.heroPanel}>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Icon name="link_rounded" color={AppColors.lime} size={30} />
              <View style={{ width: 14 }} />
              <View style={{ flex: 1 }}>
                <T v="titleMedium" color="#FFFFFF">
                  Link your FPL team
                </T>
                <View style={{ height: 4 }} />
                <T color={AppColors.heroText}>Verify your team ID to enter a pool.</T>
              </View>
              <Icon name="arrow_forward_rounded" color="#FFFFFF" />
            </View>
          </GradientPanel>
          <View style={{ height: 14 }} />
        </>
      ) : null}
      {!value.user.emailVerified ? (
        <>
          <VerifyEmailLink email={displayEmail(value.user)} />
          <View style={{ height: 14 }} />
        </>
      ) : null}
      <Metrics value={value} />
      <View style={{ height: 28 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T v="titleLarge" style={{ flex: 1 }}>
          Quick join
        </T>
        <TextButton label="See all" onPress={() => router.navigate('/pools')} />
      </View>
      <View style={{ height: 8 }} />
      {pools
        .filter(canJoin)
        .slice(0, 3)
        .map((pool) => (
          <View key={pool.id} style={{ marginBottom: 12 }}>
            <QuickPool pool={pool} />
          </View>
        ))}
      <View style={{ height: 16 }} />
      <T v="titleLarge">Built for a fair gameweek</T>
      <View style={{ height: 12 }} />
      <Principle icon="emoji_events_outlined" title="Gameweek pools" body="Fixed stakes and visible prize splits." />
      <Principle icon="compare_arrows_rounded" title="Head to head" body="Challenge any verified FPL manager from the Pools tab." />
      <Principle icon="receipt_long_outlined" title="Transparent wallet" body="Every movement has a ledger entry." />
    </RefreshScroll>
  );
}

/** Shown until the account's email address has been confirmed with a code. */
function VerifyEmailLink({ email }: { email: string }) {
  const s = useScheme();
  return (
    <GradientPanel onPress={() => router.push('/verify-email')} padding={{ paddingHorizontal: 18, paddingVertical: 14 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Icon name="mark_email_unread_outlined" color={s.primary} />
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleSmall">Your email is not verified</T>
          <View style={{ height: 2 }} />
          <T v="bodySmall" color={s.onSurfaceVariant} numberOfLines={1}>
            {email || 'Add one for receipts and important updates.'}
          </T>
        </View>
        <View style={{ width: 8 }} />
        <T v="labelLarge" w={800} color={s.primary} style={{ textDecorationLine: 'underline' }}>
          Verify email
        </T>
      </View>
    </GradientPanel>
  );
}

function Metrics({ value }: { value: Dashboard }) {
  const s = useScheme();
  return (
    <View>
      {/* The wallet balance lives in the bar at the top of the page. */}
      <Metric
        icon="bolt_rounded"
        label="Active entries"
        value={String(value.activeWagers)}
        accent={s.dark ? AppColors.lime : s.positive}
        onPress={showMyActivePools}
      />
      <View style={{ height: 12 }} />
      {value.deadline == null ? (
        <Metric icon="timer_outlined" label="FPL deadline" value="Schedule syncing" accent={s.secondary} />
      ) : (
        <FlipDeadlineCountdown deadline={value.deadline} gameweek={value.currentGameweek} />
      )}
    </View>
  );
}

function Metric({
  icon,
  label,
  value,
  accent,
  onPress,
}: {
  icon: string;
  label: string;
  value: string;
  accent: string;
  onPress?: () => void;
}) {
  const s = useScheme();
  return (
    <GradientPanel onPress={onPress}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ padding: 12, borderRadius: 15, backgroundColor: alpha(accent, 0.15) }}>
          <Icon name={icon} color={accent} />
        </View>
        <View style={{ width: 16 }} />
        <View style={{ flex: 1 }}>
          <T v="labelLarge" color={s.onSurfaceVariant}>
            {label}
          </T>
          <View style={{ height: 5 }} />
          <T v="headlineSmall" w={900} color={accent}>
            {value}
          </T>
        </View>
        {onPress ? <Icon name="chevron_right_rounded" color={s.onSurfaceVariant} /> : null}
      </View>
    </GradientPanel>
  );
}

/** Lists the pools the user is in that are still running. */
export function showMyActivePools() {
  return openSheet<void>((close) => <MyActivePoolsSheet close={close} />);
}

function MyActivePoolsSheet({ close }: { close: () => void }) {
  const s = useScheme();
  const pools = usePools();
  const { height } = useWindowDimensions();
  const muted = s.onSurfaceVariant;
  let body: React.ReactNode;
  if (pools.isError) {
    body = (
      <View style={{ padding: 16 }}>
        <T>{`Your pools could not be loaded. ${String((pools.error as Error)?.message ?? pools.error)}`}</T>
      </View>
    );
  } else if (!pools.data) {
    body = <Loading style={{ flex: 0, padding: 24 }} />;
  } else {
    const mine = pools.data.filter((p) => hasJoined(p) || isPendingMember(p)).sort((a, b) => a.gameweek - b.gameweek);
    body =
      mine.length === 0 ? (
        <View style={{ alignItems: 'center' }}>
          <View style={{ height: 12 }} />
          <T v="bodyMedium">You are not in any pool right now.</T>
          <View style={{ height: 12 }} />
          <FilledButton
            style={{ alignSelf: 'stretch' }}
            label="Browse pools"
            onPress={() => {
              close();
              router.navigate('/pools');
            }}
          />
        </View>
      ) : (
        <ScrollView style={{ flexGrow: 0 }}>
          {mine.map((pool, i) => {
            const state = isPendingMember(pool)
              ? 'Awaiting approval'
              : isLive(pool)
                ? 'In play'
                : awaitingAdminApproval(pool)
                  ? 'Awaiting admin approval'
                  : 'Open';
            return (
              <View key={pool.id} style={{ marginTop: i === 0 ? 0 : 8 }}>
                <GradientPanel
                  padding={{ paddingHorizontal: 16, paddingVertical: 12 }}
                  onPress={() => {
                    close();
                    router.push(`/pools/${pool.id}`);
                  }}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <View style={{ flex: 1 }}>
                      <T v="titleSmall" w={800} numberOfLines={1}>
                        {pool.name}
                      </T>
                      <View style={{ height: 3 }} />
                      <T v="bodySmall" color={muted} numberOfLines={1}>
                        {`GW${pool.gameweek} · ${state} · ${pool.memberCount} managers · prize ${money(pool.prizePoolCents)}`}
                      </T>
                    </View>
                    <Icon name="chevron_right_rounded" />
                  </View>
                </GradientPanel>
              </View>
            );
          })}
        </ScrollView>
      );
  }
  return (
    <View style={{ maxHeight: height * 0.75, paddingHorizontal: AppSpacing.md, paddingTop: 16, paddingBottom: 24 }}>
      <T v="titleLarge">Your active pools</T>
      <View style={{ height: 4 }} />
      <T v="bodySmall" color={muted}>
        Pools you are in that have not finished yet.
      </T>
      <View style={{ height: 14 }} />
      {body}
    </View>
  );
}

function QuickPool({ pool }: { pool: Pool }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  return (
    <GradientPanel onPress={() => router.push(`/pools/${pool.id}`)} padding={18}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <StatusPill label={pool.status} />
            {/* Auto pool names already start with their gameweek. */}
            {!pool.name.startsWith(`GW${pool.gameweek}`) ? (
              <T v="labelLarge" style={{ marginLeft: 8 }}>{`GW${pool.gameweek}`}</T>
            ) : null}
          </View>
          <View style={{ height: 10 }} />
          {/* The pool's full name, wrapping onto a second line and only then shortened. */}
          <T v="titleMedium" w={800} numberOfLines={2}>
            {pool.name}
          </T>
          <View style={{ height: 6 }} />
          <FitText v="headlineSmall" w={900} mono>
            {money(pool.stakeCents)}
          </FitText>
          <T v="bodySmall" color={muted} numberOfLines={2}>
            {`Join an open ${money(pool.prizePoolCents)} prize pool`}
          </T>
        </View>
        <View style={{ width: 12 }} />
        <Icon name="arrow_forward_rounded" />
      </View>
    </GradientPanel>
  );
}

function Principle({ icon, title, body }: { icon: string; title: string; body: string }) {
  const s = useScheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 8 }}>
      <View style={{ padding: 11, borderRadius: 14, backgroundColor: alpha(s.primary, 0.12) }}>
        <Icon name={icon} color={s.primary} />
      </View>
      <View style={{ width: 14 }} />
      <View style={{ flex: 1 }}>
        <T v="titleMedium">{title}</T>
        <T v="bodySmall" color={s.onSurfaceVariant}>
          {body}
        </T>
      </View>
    </View>
  );
}
