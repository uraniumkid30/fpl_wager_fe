import { LinearGradient } from 'expo-linear-gradient';
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Platform, View } from 'react-native';

import { formatDate, grouped, money } from '@/core/format';
import { Pool, PoolMember, isLive, ordinalSuffix } from '@/domain/pool';
import { AppColors, alpha, font, useScheme } from '@/theme/theme';
import { TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { useAnimatedNumber } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { GradientPanel } from '@/ui/widgets';

/** Rows shown before "Show all" is pressed. */
const COLLAPSED = 10;
const ROW_HEIGHT = 64;
const native = Platform.OS !== 'web';

/**
 * A pool's table: every manager with their position, points and, for the
 * positions that pay, the prize. While the gameweek is played the page
 * reloads it, so rows count up to their new points and slide to new positions.
 */
export function PoolLeaderboard({ pool }: { pool: Pool }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const [showAll, setShowAll] = useState(false);
  const all = pool.leaderboard;
  // The first rows, and the reader's own row if it is further down.
  const rows =
    showAll || all.length <= COLLAPSED ? all : [...all.slice(0, COLLAPSED), ...all.slice(COLLAPSED).filter((m) => m.isMe)];
  const hidden = all.length - rows.length;
  // The server sends the top of a very large pool, not all of it.
  const beyond = pool.memberCount - all.length;

  return (
    <View>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T v="titleLarge" style={{ flexShrink: 1 }}>
          {pool.status === 'settled' ? 'Final standings' : 'Leaderboard'}
        </T>
        {isLive(pool) ? (
          <View style={{ marginLeft: 10 }}>
            <LiveBadge />
          </View>
        ) : null}
      </View>
      <View style={{ height: 4 }} />
      <T v="bodyMedium" color={muted}>
        {caption(pool)}
      </T>
      <View style={{ height: 12 }} />
      <GradientPanel padding={8}>
        {all.length === 0 ? (
          <View style={{ padding: 14 }}>
            <T color={muted}>{pool.status === 'settled' ? 'Nobody was in this pool.' : 'Nobody is in yet. Be the first.'}</T>
          </View>
        ) : (
          <View>
            <View style={{ height: rows.length * ROW_HEIGHT, overflow: 'hidden' }}>
              {rows.map((member, index) => (
                <SlidingRow key={rowKey(member, index)} top={index * ROW_HEIGHT}>
                  <Row
                    member={member}
                    ranked={pool.ranked}
                    settled={pool.status === 'settled'}
                    last={index === rows.length - 1}
                  />
                </SlidingRow>
              ))}
            </View>
            {hidden > 0 || (showAll && all.length > COLLAPSED) ? (
              <TextButton label={showAll ? 'Show fewer' : `Show all ${all.length}`} onPress={() => setShowAll(!showAll)} />
            ) : null}
            {beyond > 0 && (showAll || hidden === 0) ? (
              <T v="bodySmall" center color={muted} style={{ paddingHorizontal: 12, paddingTop: 6, paddingBottom: 10 }}>
                {`Showing the top of the table: ${all.length} of ${grouped(pool.memberCount)} managers.`}
              </T>
            ) : null}
          </View>
        )}
      </GradientPanel>
    </View>
  );
}

/** Older servers do not send the manager's id; then the name and place have to do. */
const rowKey = (m: PoolMember, index: number) => (m.userId ? m.userId : `${m.displayName}#${index}`);

function caption(pool: Pool): string {
  if (pool.status === 'settled') return 'The official result. Prizes have been paid.';
  if (pool.status === 'cancelled') return 'This pool was cancelled and every entry was refunded.';
  if (isLive(pool)) {
    const when = pool.scoredAt == null ? '' : `Updated ${formatDate(pool.scoredAt, 'HH:mm')} · `;
    return pool.ranked
      ? `${when}provisional until FPL confirms the scores.`
      : 'The gameweek has started. Positions appear with the first points.';
  }
  return 'Positions appear when the gameweek kicks off.';
}

/** A row that glides to its new place when positions change. */
function SlidingRow({ top, children }: { top: number; children: React.ReactNode }) {
  const y = useRef(new Animated.Value(top)).current;
  useEffect(() => {
    Animated.timing(y, {
      toValue: top,
      duration: 520,
      easing: Easing.inOut(Easing.cubic),
      useNativeDriver: false,
    }).start();
  }, [top, y]);
  return <Animated.View style={{ position: 'absolute', left: 0, right: 0, height: ROW_HEIGHT, top: y }}>{children}</Animated.View>;
}

/** A small pulsing "LIVE" tag. */
function LiveBadge() {
  const pulse = useRef(new Animated.Value(0.35)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 900, useNativeDriver: native }),
        Animated.timing(pulse, { toValue: 0.35, duration: 900, useNativeDriver: native }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        paddingLeft: 7,
        paddingRight: 9,
        paddingVertical: 4,
        borderRadius: 999,
        backgroundColor: alpha(AppColors.danger, 0.14),
      }}
    >
      <Animated.View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: AppColors.danger, opacity: pulse }} />
      <View style={{ width: 5 }} />
      <T w={900} color={AppColors.danger} style={{ fontSize: 10.5, lineHeight: 12, letterSpacing: 0.8 }}>
        LIVE
      </T>
    </View>
  );
}

/** One manager: position, name, prize if any, and points. */
function Row({ member, ranked, settled, last }: { member: PoolMember; ranked: boolean; settled: boolean; last: boolean }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const prize = settled ? member.payoutCents : member.projectedCents;
  const note =
    prize > 0 ? `${settled ? 'Won' : 'Winning'} ${money(prize)}` : member.status === 'pending' ? 'Waiting for approval' : null;
  const points = useAnimatedNumber(member.points, 650);
  return (
    <View
      style={[
        { flex: 1, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 10 },
        member.isMe
          ? { backgroundColor: alpha(s.primary, 0.09), borderRadius: 16, borderWidth: 1, borderColor: alpha(s.primary, 0.3) }
          : last
            ? null
            : { borderBottomWidth: 1, borderBottomColor: alpha(s.onSurface, 0.07) },
      ]}
    >
      <PositionBadge rank={ranked ? member.rank : 0} />
      <View style={{ width: 12 }} />
      <View style={{ flex: 1, justifyContent: 'center' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <T w={700} numberOfLines={1} style={{ fontSize: 15, lineHeight: 20, flexShrink: 1 }}>
            {member.displayName}
          </T>
          {member.isMe ? (
            <View
              style={{
                marginLeft: 7,
                paddingHorizontal: 6,
                paddingVertical: 2,
                borderRadius: 999,
                backgroundColor: alpha(s.primary, 0.16),
              }}
            >
              <T w={900} color={s.primary} style={{ fontSize: 9.5, lineHeight: 11, letterSpacing: 0.6 }}>
                YOU
              </T>
            </View>
          ) : null}
        </View>
        {note ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2 }}>
            {prize > 0 ? <Icon name="emoji_events_rounded" size={13} color={s.primary} style={{ marginRight: 4 }} /> : null}
            <T w={700} numberOfLines={1} color={prize > 0 ? s.primary : muted} style={{ fontSize: 12, lineHeight: 16, flexShrink: 1 }}>
              {note}
            </T>
          </View>
        ) : null}
      </View>
      <View style={{ width: 10 }} />
      {/* Counts up (or down) to the new score when it changes. */}
      <T numberOfLines={1}>
        <T mono w={800} style={{ fontSize: 19, lineHeight: 24 }}>
          {String(Math.round(points))}
        </T>
        <T color={muted} style={{ fontSize: 11 }}>
          {' pts'}
        </T>
      </T>
    </View>
  );
}

/** "1st", "2nd", "3rd" ... The top three are gold, silver and bronze; a dash before positions. */
function PositionBadge({ rank }: { rank: number }) {
  const s = useScheme();
  const medal: [string, string] | null =
    rank === 1 ? ['#FFE08A', '#F2B21B'] : rank === 2 ? ['#F1F4F7', '#B8C2CC'] : rank === 3 ? ['#F2C29B', '#C97B45'] : null;
  const ink = rank === 1 ? '#3A2A00' : rank === 2 ? '#1E2A33' : rank === 3 ? '#3A1D08' : s.onSurface;
  const content =
    rank <= 0 ? (
      <T w={900} color={s.onSurfaceVariant} style={{ fontSize: 17 }}>
        –
      </T>
    ) : (
      <T numberOfLines={1} color={ink} style={{ paddingHorizontal: 4 }}>
        <T style={{ fontSize: rank > 99 ? 13 : 17, lineHeight: 19, color: ink, ...font(900) }}>{String(rank)}</T>
        <T style={{ fontSize: 10, lineHeight: 12, color: ink, ...font(800) }}>{ordinalSuffix(rank)}</T>
      </T>
    );
  const box = { width: 44, height: 44, borderRadius: 14, alignItems: 'center' as const, justifyContent: 'center' as const };
  return medal ? (
    <LinearGradient colors={medal} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={box}>
      {content}
    </LinearGradient>
  ) : (
    <View style={[box, { backgroundColor: alpha(s.primary, 0.12) }]}>{content}</View>
  );
}
