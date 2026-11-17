import { router } from 'expo-router';
import React from 'react';
import { Pressable, View } from 'react-native';

import { money, moneyColor, signedMoney } from '@/core/format';
import { GameweekPoolResult, GameweekResult, gwPoolLive, gwPoolSettled, ordinalSuffix } from '@/domain/pool';
import { invalidate, keys, useGameweekHistory } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { Icon } from '@/ui/Icon';
import { AppBar, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AsyncContent, Divider, EmptyState, FitText, GradientPanel, StatusPill } from '@/ui/widgets';

/**
 * Every gameweek the user played, newest first: where their score placed them
 * among everyone on FPLboardman, the pools they entered and what they staked
 * and won. Each pool opens its standings.
 */
export default function GameweekHistoryScreen() {
  const s = useScheme();
  const history = useGameweekHistory();
  return (
    <Scaffold appBar={<AppBar title="Gameweek history" />}>
      <AsyncContent
        query={history}
        onRetry={() => invalidate(keys.gameweekHistory)}
        data={(items) => {
          const won = items.reduce((sum, g) => sum + g.wonCents, 0);
          const staked = items.reduce((sum, g) => sum + g.stakedCents, 0);
          const best = items
            .filter((g) => g.position != null)
            .reduce<number | null>((b, g) => (b == null || g.position! < b ? g.position : b), null);
          return (
            <RefreshScroll
              onRefresh={() => invalidate(keys.gameweekHistory)}
              contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 48 }}
            >
              {items.length === 0 ? (
                <EmptyState
                  icon="leaderboard_outlined"
                  title="No gameweeks yet"
                  message="Enter a pool and your gameweek results will be kept here."
                />
              ) : (
                <>
                  <View style={{ flexDirection: 'row' }}>
                    <Stat label="GAMEWEEKS" value={String(items.length)} />
                    <View style={{ width: 10 }} />
                    <Stat label="BEST FINISH" value={best == null ? '—' : `${best}${ordinalSuffix(best)}`} />
                  </View>
                  <View style={{ height: 10 }} />
                  <View style={{ flexDirection: 'row' }}>
                    <Stat label="STAKED" value={money(staked)} color={moneyColor(s, -staked)} mono />
                    <View style={{ width: 10 }} />
                    <Stat label="WON" value={money(won)} color={moneyColor(s, won)} mono />
                  </View>
                  <View style={{ height: 22 }} />
                  {items.map((item) => (
                    <View key={item.gameweek} style={{ marginBottom: 14 }}>
                      <GameweekCard item={item} />
                    </View>
                  ))}
                </>
              )}
            </RefreshScroll>
          );
        }}
      />
    </Scaffold>
  );
}

function Stat({ label, value, color, mono }: { label: string; value: string; color?: string; mono?: boolean }) {
  const s = useScheme();
  return (
    <View style={{ flex: 1 }}>
      <GradientPanel padding={{ paddingHorizontal: 16, paddingVertical: 14 }}>
        <T v="labelSmall" color={s.onSurfaceVariant} style={{ letterSpacing: 0.7 }}>
          {label}
        </T>
        <View style={{ height: 4 }} />
        <FitText v="titleLarge" w={900} color={color} mono={mono}>
          {value}
        </FitText>
      </GradientPanel>
    </View>
  );
}

function GameweekCard({ item }: { item: GameweekResult }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const position = item.position;
  const net = item.wonCents - item.stakedCents;
  return (
    <GradientPanel>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T v="titleLarge" style={{ flex: 1 }}>{`Gameweek ${item.gameweek}`}</T>
        <StatusPill label={item.isFinal ? 'Final' : 'In progress'} color={item.isFinal ? undefined : AppColors.orange} />
      </View>
      <View style={{ height: 14 }} />
      <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
        <T v="displaySmall" w={900} color={position === 1 ? s.positive : undefined}>
          {position == null ? '—' : `${position}${ordinalSuffix(position)}`}
        </T>
        <View style={{ width: 10 }} />
        <T v="bodySmall" color={muted} style={{ flex: 1, paddingBottom: 6 }}>
          {position == null
            ? 'No position yet. It shows once points are scored.'
            : `of ${item.managers} managers on FPLboardman${item.points == null ? '' : ` · ${item.points} pts`}`}
        </T>
      </View>
      <View style={{ height: 14 }} />
      <View style={{ flexDirection: 'row' }}>
        <MoneyCell label="Staked" cents={item.stakedCents} color={moneyColor(s, -item.stakedCents)} />
        <MoneyCell label="Won" cents={item.wonCents} color={moneyColor(s, item.wonCents)} />
        <MoneyCell label="Net" cents={net} signed color={moneyColor(s, net)} />
      </View>
      <View style={{ height: 12 }} />
      <Divider />
      <View style={{ height: 6 }} />
      {item.pools.map((pool) => (
        <PoolRow key={pool.id} pool={pool} />
      ))}
    </GradientPanel>
  );
}

function MoneyCell({ label, cents, color, signed }: { label: string; cents: number; color?: string; signed?: boolean }) {
  const s = useScheme();
  return (
    <View style={{ flex: 1, paddingRight: 6 }}>
      <T v="labelSmall" color={s.onSurfaceVariant}>
        {label}
      </T>
      <View style={{ height: 2 }} />
      <FitText v="titleSmall" w={800} mono color={color}>
        {signed ? signedMoney(cents) : money(cents)}
      </FitText>
    </View>
  );
}

function PoolRow({ pool }: { pool: GameweekPoolResult }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const rank = pool.rank;
  const place =
    rank == null || rank === 0
      ? gwPoolLive(pool)
        ? 'In play'
        : 'Not started'
      : `${rank}${ordinalSuffix(rank)} of ${pool.entrants}${gwPoolLive(pool) ? ' (live)' : ''}`;
  return (
    <Pressable
      onPress={() => router.push(`/pools/${pool.id}`)}
      style={({ pressed }) => ({
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 8,
        borderRadius: 12,
        backgroundColor: pressed ? alpha(s.onSurface, 0.06) : 'transparent',
      })}
    >
      <View style={{ flex: 1 }}>
        <T v="bodyMedium" w={700} numberOfLines={1}>
          {pool.name}
        </T>
        <T v="bodySmall" color={muted}>{`${place} · stake ${money(pool.stakeCents)}`}</T>
      </View>
      <T v="labelLarge" w={900} mono color={moneyColor(s, pool.payoutCents) ?? muted}>
        {pool.payoutCents > 0 ? signedMoney(pool.payoutCents) : gwPoolSettled(pool) ? '—' : ''}
      </T>
      <Icon name="chevron_right_rounded" size={18} color={muted} />
    </Pressable>
  );
}
