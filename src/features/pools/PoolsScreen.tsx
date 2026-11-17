import { router } from 'expo-router';
import React, { useState } from 'react';
import { View } from 'react-native';

import { money, moneyColor, signedMoney } from '@/core/format';
import {
  Pool,
  hasJoined,
  inviteCodeFrom,
  isAuto,
  isLive,
  isMine,
  isPendingMember,
  ordinalSuffix,
} from '@/domain/pool';
import { requireLinkedFplTeam } from '@/features/team/linkTeam';
import { openTopUpIfInsufficientFunds } from '@/features/wallet/insufficientFunds';
import { gateway } from '@/state/gateway';
import { afterPoolAction, invalidate, keys, useDashboard, usePastPools, usePools } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { FilledButton, OutlinedButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { CampaignCarousel } from '@/features/campaigns/CampaignBanner';
import { SegmentedButton, TextField } from '@/ui/Inputs';
import { AppHeader, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { AlertDialogView, openDialog } from '@/ui/overlay';
import { AsyncContent, EmptyState, FadeSlideIn, GradientPanel, Spinner, StatusPill } from '@/ui/widgets';
import { openCreatePoolDialog } from './CreatePoolDialog';
import { PoolCard } from './PoolCard';

type Tab = 'active' | 'past';

/**
 * The Pools tab. "Active": the user's custom pools (with Create / Join), head
 * to head, then the auto pools by gameweek. "Past": settled pools the user
 * played, with their result, and the way into their gameweek history.
 */
export default function PoolsScreen() {
  const [tab, setTab] = useState<Tab>('active');
  return (
    <Scaffold appBar={<AppHeader title="Gameweek pools" />}>
      <View style={{ paddingHorizontal: AppSpacing.md, paddingTop: 4, paddingBottom: 10 }}>
        <SegmentedButton<Tab>
          segments={[
            { value: 'active', label: 'Active', icon: 'sports_soccer_rounded' },
            { value: 'past', label: 'Past', icon: 'history_rounded' },
          ]}
          selected={tab}
          onChange={setTab}
        />
      </View>
      <View style={{ flex: 1 }}>{tab === 'active' ? <ActivePools onShowPast={() => setTab('past')} /> : <PastPools />}</View>
    </Scaffold>
  );
}

async function createPool() {
  if (!(await requireLinkedFplTeam('pool'))) return;
  // The form closes with the new pool's id.
  const createdId = await openCreatePoolDialog();
  if (!createdId) return;
  invalidate(keys.pools);
  // Straight to the new pool, where its invite link is waiting to be shared.
  router.push(`/pools/${createdId}`);
}

async function joinWithCode() {
  const code = await openDialog<string>((close) => <JoinWithCodeDialog close={close} />);
  if (code) router.push(`/join/${code}`);
}

/** What can still be joined or is being played. */
function ActivePools({ onShowPast }: { onShowPast: () => void }) {
  const pools = usePools();
  const currentGameweek = useDashboard().data?.currentGameweek;
  const [joining, setJoining] = useState(false);

  const joinPool = async (pool: Pool) => {
    if (!(await requireLinkedFplTeam('pool'))) return;
    setJoining(true);
    try {
      const joined = await gateway.joinPool(pool.id);
      afterPoolAction();
      AppNotice.success(
        isPendingMember(joined)
          ? `Your request to join ${joined.name} is awaiting approval.`
          : `You joined ${joined.name}.`,
      );
    } catch (error) {
      afterPoolAction();
      if (openTopUpIfInsufficientFunds(error)) return;
      AppNotice.error(error ?? 'The pool could not be joined.');
    } finally {
      setJoining(false);
    }
  };

  return (
    <AsyncContent
      query={pools}
      onRetry={() => invalidate(keys.pools)}
      data={(items) => {
        const customPools = items.filter((p) => !isAuto(p)).sort(byGameweekThenJoined);
        // Auto pools by gameweek, earliest first.
        const byGameweek = new Map<number, Pool[]>();
        for (const pool of items.filter(isAuto)) {
          if (!byGameweek.has(pool.gameweek)) byGameweek.set(pool.gameweek, []);
          byGameweek.get(pool.gameweek)!.push(pool);
        }
        const gameweeks = [...byGameweek.keys()].sort((a, b) => a - b);
        // A manager may run one pool of their own per gameweek.
        const myPool =
          currentGameweek == null ? null : (customPools.find((p) => isMine(p) && p.gameweek === currentGameweek) ?? null);
        let index = 0;
        const card = (pool: Pool) => {
          // Only the first few cards ease in one after another.
          const step = Math.min(index, 8);
          index++;
          return (
            <View key={pool.id} style={{ marginBottom: 14 }}>
              <FadeSlideIn delay={step * 55}>
                <PoolCard pool={pool} joining={joining} onJoin={() => joinPool(pool)} />
              </FadeSlideIn>
            </View>
          );
        };
        return (
          <RefreshScroll
            onRefresh={() => invalidate(keys.pools, keys.campaignsAll)}
            contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 6, paddingBottom: 120 }}
          >
            <CampaignCarousel placement="pools" />
            <SectionTitle
              title="Custom pools"
              subtitle="Private pools: yours, and the ones you were invited to"
              count={customPools.length}
            />
            <View style={{ height: 12 }} />
            <CustomPoolActions
              onCreate={myPool == null ? createPool : null}
              onJoin={joinWithCode}
              note={
                myPool == null
                  ? null
                  : `You can run one pool of your own per gameweek. To start another for Gameweek ${myPool.gameweek}, delete ${myPool.name} first.`
              }
            />
            <View style={{ height: 10 }} />
            {/* Head to head sits with the other ways to start a game. */}
            <HeadToHeadCard onPress={() => router.push('/challenges')} />
            <View style={{ height: 14 }} />
            {customPools.map(card)}
            <View style={{ height: 14 }} />
            {gameweeks.length === 0 ? (
              <>
                <SectionTitle title="Auto pools" subtitle="Open to every manager" count={0} />
                <View style={{ height: 12 }} />
                <GradientPanel>
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <Spinner />
                    <View style={{ width: 16 }} />
                    <T style={{ flex: 1 }}>The standard auto pools are being prepared. Pull down to refresh.</T>
                  </View>
                </GradientPanel>
              </>
            ) : null}
            {gameweeks.map((gw) => (
              <View key={gw}>
                <GameweekTitle gameweek={gw} pools={byGameweek.get(gw)!} />
                <View style={{ height: 12 }} />
                {[...byGameweek.get(gw)!].sort(joinedThenStake).map(card)}
                <View style={{ height: 14 }} />
              </View>
            ))}
            <View style={{ height: 4 }} />
            <TextButton icon="history_rounded" label="Finished pools and results" onPress={onShowPast} />
          </RefreshScroll>
        );
      }}
    />
  );
}

const inOrPending = (p: Pool) => (hasJoined(p) || isPendingMember(p) ? 0 : 1);
/** Pools the user is in first, then by stake. */
function joinedThenStake(a: Pool, b: Pool) {
  const d = inOrPending(a) - inOrPending(b);
  return d !== 0 ? d : a.stakeCents - b.stakeCents;
}
function byGameweekThenJoined(a: Pool, b: Pool) {
  const d = a.gameweek - b.gameweek;
  return d !== 0 ? d : joinedThenStake(a, b);
}

/** "₦1,000 · ₦2,000 · ₦5,000" from the auto pools on offer. */
function stakesLabel(autoPools: Pool[]) {
  const stakes = [...new Set(autoPools.map((p) => p.stakeCents))].sort((a, b) => a - b);
  return stakes.length === 0 ? 'Open to every manager' : stakes.map(money).join(' · ');
}

function GameweekTitle({ gameweek, pools }: { gameweek: number; pools: Pool[] }) {
  const s = useScheme();
  const live = pools.some(isLive);
  const joined = pools.filter(hasJoined).length;
  const subtitle = live
    ? joined > 0
      ? `Entries closed · you are in ${joined}. Tap one for live standings.`
      : 'Entries closed. Tap a pool for live standings.'
    : `Open for entries · ${stakesLabel(pools)}`;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <View style={{ flex: 1 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <T v="titleLarge" style={{ flexShrink: 1 }}>{`Gameweek ${gameweek}`}</T>
          <View style={{ width: 8 }} />
          <StatusPill label={live ? 'In play' : 'Open'} color={live ? AppColors.orange : s.positive} />
        </View>
        <View style={{ height: 2 }} />
        <T v="bodySmall" color={s.onSurfaceVariant}>
          {subtitle}
        </T>
      </View>
      <StatusPill label={String(pools.length)} />
    </View>
  );
}

/** Settled pools the user played, newest gameweek first. */
function PastPools() {
  const past = usePastPools();
  return (
    <AsyncContent
      query={past}
      onRetry={() => invalidate(keys.pastPools)}
      data={(items) => {
        const byGameweek = new Map<number, Pool[]>();
        for (const pool of items) {
          if (!byGameweek.has(pool.gameweek)) byGameweek.set(pool.gameweek, []);
          byGameweek.get(pool.gameweek)!.push(pool);
        }
        const gameweeks = [...byGameweek.keys()].sort((a, b) => b - a);
        return (
          <RefreshScroll
            onRefresh={() => invalidate(keys.pastPools)}
            contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 6, paddingBottom: 120 }}
          >
            <GradientPanel onPress={() => router.push('/gameweeks')} colors={AppColors.heroPanel}>
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <View
                  style={{
                    width: 48,
                    height: 48,
                    borderRadius: 24,
                    backgroundColor: alpha(AppColors.lime, 0.14),
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Icon name="leaderboard_rounded" color={AppColors.lime} />
                </View>
                <View style={{ width: 14 }} />
                <View style={{ flex: 1 }}>
                  <T v="titleMedium" w={900} color="#FFFFFF">
                    Gameweek history
                  </T>
                  <View style={{ height: 3 }} />
                  <T color={AppColors.heroText}>Where you finished each gameweek, and what you staked and won.</T>
                </View>
                <Icon name="arrow_forward_rounded" color="#FFFFFF" />
              </View>
            </GradientPanel>
            <View style={{ height: 22 }} />
            {items.length === 0 ? (
              <EmptyState
                icon="emoji_events_outlined"
                title="No finished pools yet"
                message="Pools you play in appear here once they are settled, with your result."
              />
            ) : null}
            {gameweeks.map((gw) => (
              <View key={gw}>
                <PastGameweekHeader gameweek={gw} pools={byGameweek.get(gw)!} />
                <View style={{ height: 10 }} />
                {byGameweek.get(gw)!.map((pool) => (
                  <View key={pool.id} style={{ marginBottom: 10 }}>
                    <PastPoolTile pool={pool} />
                  </View>
                ))}
                <View style={{ height: 14 }} />
              </View>
            ))}
          </RefreshScroll>
        );
      }}
    />
  );
}

function PastGameweekHeader({ gameweek, pools }: { gameweek: number; pools: Pool[] }) {
  const s = useScheme();
  const won = pools.reduce((sum, p) => sum + (p.myPayoutCents ?? 0), 0);
  const staked = pools.reduce((sum, p) => sum + p.stakeCents, 0);
  const net = won - staked;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <T v="titleLarge" style={{ flex: 1 }}>{`Gameweek ${gameweek}`}</T>
      <T v="labelLarge" w={900} mono color={moneyColor(s, net) ?? s.onSurfaceVariant}>
        {signedMoney(net)}
      </T>
    </View>
  );
}

/** One finished pool: where the user finished and what they won. */
export function PastPoolTile({ pool }: { pool: Pool }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const rank = pool.myRank ?? 0;
  const won = pool.myPayoutCents ?? 0;
  const place = rank > 0 ? `${rank}${ordinalSuffix(rank)} of ${pool.memberCount}` : `${pool.memberCount} managers`;
  const points = pool.myPoints == null ? '' : ` · ${pool.myPoints} pts`;
  const winColor = s.positive;
  return (
    <GradientPanel onPress={() => router.push(`/pools/${pool.id}`)} padding={{ paddingHorizontal: 16, paddingVertical: 14 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View
          style={{
            width: 46,
            height: 46,
            borderRadius: 14,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: alpha(won > 0 ? winColor : muted, 0.15),
          }}
        >
          {won > 0 ? (
            <Icon name="emoji_events_rounded" color={winColor} />
          ) : (
            <T v="labelLarge" w={900} color={muted}>
              {rank > 0 ? `${rank}${ordinalSuffix(rank)}` : '—'}
            </T>
          )}
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleSmall" w={800} numberOfLines={1}>
            {pool.name}
          </T>
          <View style={{ height: 3 }} />
          <T v="bodySmall" color={muted} numberOfLines={1}>
            {`${place}${points} · stake ${money(pool.stakeCents)}`}
          </T>
        </View>
        <View style={{ width: 10 }} />
        <View style={{ alignItems: 'flex-end' }}>
          <T v="labelLarge" w={900} mono={won > 0} color={moneyColor(s, won) ?? muted}>
            {won > 0 ? signedMoney(won) : 'No prize'}
          </T>
          <View style={{ height: 2 }} />
          <Icon name="chevron_right_rounded" size={18} color={muted} />
        </View>
      </View>
    </GradientPanel>
  );
}

function JoinWithCodeDialog({ close }: { close: (code?: string) => void }) {
  const [input, setInput] = useState('');
  const [error, setError] = useState<string | null>(null);
  const submit = () => {
    const code = inviteCodeFrom(input);
    if (!code) {
      setError('That does not look like an invite code or link.');
      return;
    }
    close(code);
  };
  return (
    <AlertDialogView
      title="Join a private pool"
      content={
        <View style={{ width: '100%', maxWidth: 420 }}>
          <T>{"Enter the code the pool's creator gave you, or paste their invite link."}</T>
          <View style={{ height: 16 }} />
          <TextField
            value={input}
            autoFocus
            autoCapitalize="characters"
            returnKeyType="done"
            label="Invite code or link"
            prefixIcon="vpn_key_outlined"
            error={error}
            onChangeText={(v) => {
              setInput(v);
              if (error) setError(null);
            }}
            onSubmitEditing={submit}
          />
        </View>
      }
      actions={
        <>
          <TextButton label="Cancel" onPress={() => close()} />
          <FilledButton compact height={40} label="Find pool" onPress={submit} />
        </>
      }
    />
  );
}

function SectionTitle({ title, subtitle, count }: { title: string; subtitle: string; count: number }) {
  const s = useScheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <View style={{ flex: 1 }}>
        <T v="titleLarge">{title}</T>
        <View style={{ height: 2 }} />
        <T v="bodySmall" color={s.onSurfaceVariant}>
          {subtitle}
        </T>
      </View>
      <StatusPill label={String(count)} />
    </View>
  );
}

function HeadToHeadCard({ onPress }: { onPress: () => void }) {
  return (
    <GradientPanel onPress={onPress} padding={{ paddingHorizontal: 16, paddingVertical: 14 }} colors={AppColors.heroPanel}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View
          style={{
            width: 40,
            height: 40,
            borderRadius: 20,
            backgroundColor: alpha(AppColors.lime, 0.14),
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="compare_arrows_rounded" color={AppColors.lime} size={20} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleMedium" w={900} color="#FFFFFF">
            Create a head-to-head
          </T>
          <View style={{ height: 2 }} />
          <T color={AppColors.heroText} style={{ fontSize: 13 }}>
            Challenge one verified FPL manager, winner takes the pot.
          </T>
        </View>
        <Icon name="arrow_forward_rounded" color="#FFFFFF" />
      </View>
    </GradientPanel>
  );
}

/** The two ways into a custom pool: start one, or join one with its code. */
function CustomPoolActions({
  onCreate,
  onJoin,
  note,
}: {
  onCreate: (() => void) | null;
  onJoin: () => void;
  note: string | null;
}) {
  const s = useScheme();
  return (
    <GradientPanel padding={14}>
      <View style={{ flexDirection: 'row' }}>
        <View style={{ flex: 1 }}>
          <FilledButton icon="add_circle_outline_rounded" label="Create new pool" onPress={onCreate} style={{ paddingHorizontal: 12 }} />
        </View>
        <View style={{ width: 10 }} />
        <View style={{ flex: 1 }}>
          <OutlinedButton icon="vpn_key_outlined" label="Join pool" onPress={onJoin} style={{ minHeight: 54, paddingHorizontal: 12 }} />
        </View>
      </View>
      <View style={{ height: 10 }} />
      <T v="bodySmall" center color={s.onSurfaceVariant}>
        {note ?? "Create a pool and share its link, or join a friend's pool with the code or link they sent you."}
      </T>
    </GradientPanel>
  );
}
