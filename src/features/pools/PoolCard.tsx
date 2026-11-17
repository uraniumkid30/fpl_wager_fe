import { router } from 'expo-router';
import React from 'react';
import { View } from 'react-native';

import { money } from '@/core/format';
import {
  Pool,
  awaitingAdminApproval,
  canJoin,
  drawMethodLabel,
  hasJoined,
  isAuto,
  isLive,
  isPendingMember,
  isPrivate,
} from '@/domain/pool';
import { AppColors, useScheme } from '@/theme/theme';
import { FilledButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { T } from '@/ui/Text';
import { DeadlineCountdown, FitText, GradientPanel, StatusPill } from '@/ui/widgets';

export function PoolCard({ pool, onJoin, joining = false }: { pool: Pool; onJoin: () => void; joining?: boolean }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const membership = awaitingAdminApproval(pool)
    ? 'Awaiting admin approval'
    : isPendingMember(pool)
      ? 'Pending approval'
      : hasJoined(pool)
        ? 'Joined'
        : isLive(pool)
          ? 'In play'
          : pool.status;
  const actionLabel = hasJoined(pool)
    ? 'Joined'
    : awaitingAdminApproval(pool)
      ? 'Awaiting admin approval'
      : isPendingMember(pool)
        ? 'Pending approval'
        : !canJoin(pool)
          ? isLive(pool)
            ? 'Entries closed'
            : `Pool ${pool.status}`
          : `Join pool · ${money(pool.stakeCents)}`;
  const actionIcon = hasJoined(pool)
    ? 'check_circle_rounded'
    : isPendingMember(pool)
      ? 'hourglass_top_rounded'
      : !canJoin(pool)
        ? 'lock_clock_rounded'
        : 'login_rounded';
  return (
    <GradientPanel onPress={() => router.push(`/pools/${pool.id}`)}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <StatusPill
          label={membership}
          color={awaitingAdminApproval(pool) || isPendingMember(pool) ? AppColors.orange : undefined}
        />
        <View style={{ flex: 1 }} />
        {isPrivate(pool) ? (
          <>
            <Icon name="lock_outline_rounded" size={15} color={muted} />
            <T v="labelSmall" w={900} color={muted} style={{ marginLeft: 4, marginRight: 10 }}>
              PRIVATE
            </T>
          </>
        ) : null}
        {isAuto(pool) ? (
          <>
            <Icon name="autorenew_rounded" size={17} color={s.positive} />
            <T v="labelSmall" w={900} color={s.positive} style={{ marginLeft: 5, marginRight: 10 }}>
              AUTO
            </T>
          </>
        ) : null}
        <Icon name="groups_2_outlined" size={17} color={muted} />
        <T v="labelLarge" style={{ marginLeft: 5 }}>
          {String(pool.memberCount)}
        </T>
        {pool.maxMembers != null ? <T v="labelSmall">{` / ${pool.maxMembers}`}</T> : null}
      </View>
      <View style={{ height: 18 }} />
      <T v="titleLarge">{pool.name}</T>
      <View style={{ height: 14 }} />
      <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
        <Value label="STAKE" value={money(pool.stakeCents)} />
        <Value label="PRIZE POOL" value={money(pool.prizePoolCents)} color={s.secondary} />
        <Icon name="arrow_forward_rounded" />
      </View>
      <View style={{ height: 14 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Icon name="timer_outlined" size={16} />
        <View style={{ width: 6 }} />
        <DeadlineCountdown deadline={pool.deadline} compact />
      </View>
      <View style={{ height: 10 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Icon name="balance_rounded" size={16} />
        <View style={{ width: 6 }} />
        <T v="bodySmall">{`Draw: ${drawMethodLabel[pool.drawMethod]}`}</T>
      </View>
      <View style={{ height: 18 }} />
      <FilledButton
        icon={actionIcon}
        label={actionLabel}
        busy={joining && canJoin(pool)}
        onPress={canJoin(pool) && !joining ? onJoin : null}
      />
    </GradientPanel>
  );
}

function Value({ label, value, color }: { label: string; value: string; color?: string }) {
  const s = useScheme();
  return (
    <View style={{ flex: 1, paddingRight: 8 }}>
      <T v="labelSmall" color={s.onSurfaceVariant} style={{ letterSpacing: 0.7 }}>
        {label}
      </T>
      <View style={{ height: 3 }} />
      <FitText v="titleLarge" w={900} mono color={color}>
        {value}
      </FitText>
    </View>
  );
}
