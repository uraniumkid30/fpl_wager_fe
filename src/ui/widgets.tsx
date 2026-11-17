import { UseQueryResult } from '@tanstack/react-query';
import { LinearGradient } from 'expo-linear-gradient';
import React, { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Animated,
  Easing,
  Image,
  LayoutChangeEvent,
  Platform,
  Pressable,
  StyleProp,
  View,
  ViewStyle,
  TextStyle,
  StyleSheet,
} from 'react-native';

import { errorMessage } from '@/core/errors';
import { formatDate } from '@/core/format';
import { AppColors, AppMotion, AppSpacing, Brand, alpha, type as typeScale, useScheme } from '@/theme/theme';
import { FilledButton } from './Buttons';
import { Icon } from './Icon';
import { T, TProps } from './Text';

export const easeOutCubic = Easing.bezier(0.33, 1, 0.68, 1);
const native = Platform.OS !== 'web';

// ---------------------------------------------------------------- brand

const iconArt = require('../../assets/brand/icon.png');
const wordmarkWhite = require('../../assets/brand/wordmark-white.png');
const wordmarkPurple = require('../../assets/brand/wordmark-purple.png');

/**
 * The FPL Boardman logo from the brand guidelines: the managers'-table icon
 * with the stacked "FPL / Boardman" wordmark. Purple wordmark on light
 * backgrounds, white (reversed) on purple and dark ones.
 */
export function BrandMark({
  compact = false,
  reversed,
  iconOnly = false,
}: {
  compact?: boolean;
  reversed?: boolean;
  iconOnly?: boolean;
}) {
  const s = useScheme();
  const icon = compact ? 30 : 38;
  const white = reversed ?? s.dark;
  // The wordmark art is 860×340; keep its proportions.
  const wordHeight = icon * 0.86;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }} accessibilityRole="image" accessibilityLabel="FPL Boardman">
      <Image source={iconArt} style={{ width: icon, height: icon * (406 / 410) }} resizeMode="contain" />
      {iconOnly ? null : <View style={{ width: icon * 0.26 }} />}
      {iconOnly ? null : <Image
        source={white ? wordmarkWhite : wordmarkPurple}
        style={{ height: wordHeight, width: wordHeight * (860 / 340) }}
        resizeMode="contain"
      />}
    </View>
  );
}

/** Just the icon (app icon art), for small places. */
export function BrandIcon({ size = 38 }: { size?: number }) {
  return <Image source={iconArt} style={{ width: size, height: size * (406 / 410) }} resizeMode="contain" />;
}

// ---------------------------------------------------------------- panel

export function GradientPanel({
  children,
  padding = AppSpacing.lg,
  colors,
  onPress,
  style,
}: {
  children: React.ReactNode;
  padding?:
    | number
    | Pick<ViewStyle, 'padding' | 'paddingHorizontal' | 'paddingVertical' | 'paddingLeft' | 'paddingRight' | 'paddingTop' | 'paddingBottom'>;
  colors?: [string, string];
  onPress?: () => void;
  style?: StyleProp<ViewStyle>;
}) {
  const s = useScheme();
  const pad = typeof padding === 'number' ? { padding } : padding;
  const panel = (
    <LinearGradient
      colors={colors ?? s.panel}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={[
        {
          borderRadius: 24,
          borderWidth: 1,
          borderColor: alpha(s.outlineVariant, 0.45),
          ...pad,
        },
        s.panelShadow ? { boxShadow: '0px 10px 24px rgba(26,11,40,0.08)' } : null,
        onPress ? null : style,
      ]}
    >
      {children}
    </LinearGradient>
  );
  if (!onPress) return panel;
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [{ opacity: pressed ? 0.88 : 1, borderRadius: 24 }, style]}>
      {panel}
    </Pressable>
  );
}

export function StatusPill({ label, color }: { label: string; color?: string }) {
  const s = useScheme();
  const c = color ?? s.primary;
  return (
    <View
      style={{
        paddingHorizontal: 10,
        paddingVertical: 5,
        borderRadius: 999,
        backgroundColor: alpha(c, 0.14),
        alignSelf: 'flex-start',
      }}
    >
      <T v="labelSmall" w={900} color={c} style={{ letterSpacing: 0.4 }}>
        {label.toUpperCase()}
      </T>
    </View>
  );
}

export function Divider({ style }: { style?: StyleProp<ViewStyle> }) {
  const s = useScheme();
  return <View style={[{ height: StyleSheet.hairlineWidth || 1, backgroundColor: s.divider }, style]} />;
}

export function Spinner({ size = 'large', color }: { size?: 'small' | 'large'; color?: string }) {
  const s = useScheme();
  return <ActivityIndicator size={size} color={color ?? s.primary} />;
}

export function Gap({ h, w }: { h?: number; w?: number }) {
  return <View style={{ height: h, width: w }} />;
}

/** LinearProgressIndicator. */
export function ProgressBar({ value, height = 8, color }: { value: number | null; height?: number; color?: string }) {
  const s = useScheme();
  const v = value == null ? 0.3 : Math.max(0, Math.min(1, value));
  return (
    <View style={{ height, borderRadius: 99, backgroundColor: s.surfaceHigh, overflow: 'hidden' }}>
      <View style={{ width: `${v * 100}%`, height: '100%', backgroundColor: color ?? s.primary, borderRadius: 99 }} />
    </View>
  );
}

// ---------------------------------------------------------------- clock / countdown

export function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), intervalMs);
    return () => clearInterval(t);
  }, [intervalMs]);
  return now;
}

function split(ms: number) {
  const total = Math.max(0, Math.floor(ms / 1000));
  return {
    days: Math.floor(total / 86400),
    hours: Math.floor(total / 3600) % 24,
    minutes: Math.floor(total / 60) % 60,
    seconds: total % 60,
  };
}

export function DeadlineCountdown({ deadline, compact = false }: { deadline: Date; compact?: boolean }) {
  const now = useNow();
  const r = split(deadline.getTime() - now.getTime());
  return (
    <T v={compact ? 'labelMedium' : 'headlineMedium'} w={900}>
      {`${r.days}d ${r.hours}h ${r.minutes}m`}
    </T>
  );
}

/** The split-flap countdown to the FPL deadline. */
export function FlipDeadlineCountdown({ deadline, gameweek }: { deadline: Date; gameweek?: number | null }) {
  const now = useNow();
  const diff = deadline.getTime() - now.getTime();
  const passed = diff < 0;
  const r = split(diff);
  const units = [
    { label: 'DAYS', value: String(r.days).padStart(2, '0') },
    { label: 'HOURS', value: String(r.hours).padStart(2, '0') },
    { label: 'MIN', value: String(r.minutes).padStart(2, '0') },
    { label: 'SEC', value: String(r.seconds).padStart(2, '0') },
  ];
  const [width, setWidth] = useState(400);
  const gap = width < 340 ? 5 : 8;
  return (
    <View
      accessibilityLiveRegion="polite"
      accessibilityLabel={
        passed
          ? 'The gameweek deadline has passed'
          : `${r.days} days, ${r.hours} hours, ${r.minutes} minutes and ${r.seconds} seconds until the FPL deadline`
      }
    >
      <GradientPanel colors={[Brand.midnight, Brand.boardroomPurple]}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={{ padding: 10, borderRadius: 14, backgroundColor: alpha(AppColors.cyan, 0.14) }}>
            <Icon name="timer_outlined" color={AppColors.cyan} />
          </View>
          <Gap w={12} />
          <View style={{ flex: 1 }}>
            <T v="titleMedium" color="#FFFFFF">
              {gameweek == null ? 'Official FPL deadline' : `Gameweek ${gameweek} deadline`}
            </T>
            <T v="bodySmall" color="#CDBFDD">
              {passed ? 'Entries are now locked' : formatDate(deadline, 'EEE, d MMM · HH:mm')}
            </T>
          </View>
          <StatusPill label={passed ? 'closed' : 'live'} color={passed ? AppColors.danger : AppColors.lime} />
        </View>
        <Gap h={20} />
        <View style={{ flexDirection: 'row' }} onLayout={(e) => setWidth(e.nativeEvent.layout.width)}>
          {units.map((u, i) => (
            <React.Fragment key={u.label}>
              <View style={{ flex: 1 }}>
                <FlipClockUnit label={u.label} value={u.value} />
              </View>
              {i !== units.length - 1 ? <View style={{ width: gap }} /> : null}
            </React.Fragment>
          ))}
        </View>
      </GradientPanel>
    </View>
  );
}

function FlipClockUnit({ label, value }: { label: string; value: string }) {
  const rotation = useRef(new Animated.Value(0)).current;
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    rotation.setValue(1);
    Animated.timing(rotation, {
      toValue: 0,
      duration: 520,
      easing: Easing.out(Easing.back(1.7)),
      useNativeDriver: native,
    }).start();
  }, [value, rotation]);
  const rotateX = rotation.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '90deg'] });
  const [box, setBox] = useState(0);
  return (
    <View style={{ alignItems: 'center' }}>
      <View
        onLayout={(e: LayoutChangeEvent) => setBox(e.nativeEvent.layout.width)}
        style={{
          width: '100%',
          aspectRatio: 0.86,
          borderRadius: 14,
          overflow: 'hidden',
          backgroundColor: '#2A1642',
          borderWidth: 1,
          borderColor: '#5A3F78',
          boxShadow: '0px 8px 14px rgba(0,0,0,0.4)',
        }}
      >
        <View style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '50%', backgroundColor: '#341C50' }} />
        <Animated.View
          style={{
            flex: 1,
            alignItems: 'center',
            justifyContent: 'center',
            transform: [{ perspective: 1000 }, { rotateX }],
          }}
        >
          <T
            mono
            w={800}
            color="#FFFFFF"
            style={{ fontSize: Math.min(36, box ? box * 0.48 : 36), lineHeight: Math.min(40, box ? box * 0.54 : 40) }}
            numberOfLines={1}
          >
            {value}
          </T>
        </Animated.View>
        <View style={{ position: 'absolute', left: 0, right: 0, top: '50%', height: 1, backgroundColor: Brand.midnight }} />
      </View>
      <Gap h={7} />
      <T v="labelSmall" w={800} color="#C5B4D8" style={{ letterSpacing: 0.8 }}>
        {label}
      </T>
    </View>
  );
}

// ---------------------------------------------------------------- async states

export function Loading({ style }: { style?: StyleProp<ViewStyle> }) {
  return (
    <View style={[{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32 }, style]}>
      <Spinner />
    </View>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const s = useScheme();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: AppSpacing.xl }}>
      <Icon name="cloud_off_rounded" size={44} color={s.error} />
      <Gap h={16} />
      <T center>{errorMessage(error)}</T>
      {onRetry ? (
        <>
          <Gap h={16} />
          <FilledButton tonal label="Try again" onPress={onRetry} style={{ alignSelf: 'stretch' }} />
        </>
      ) : null}
    </View>
  );
}

/** AsyncContent: spinner while loading, the error with a retry, or the data. */
export function AsyncContent<T>({
  query,
  data,
  onRetry,
  keepDataOnError = false,
}: {
  query: UseQueryResult<T>;
  data: (value: T) => React.ReactNode;
  onRetry?: () => void;
  keepDataOnError?: boolean;
}) {
  if (query.data !== undefined && (keepDataOnError || !query.isError)) return <>{data(query.data)}</>;
  if (query.isError) return <ErrorState error={query.error} onRetry={onRetry ?? (() => query.refetch())} />;
  return <Loading />;
}

export function EmptyState({ icon, title, message }: { icon: string; title: string; message: string }) {
  const s = useScheme();
  return (
    <View style={{ alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32, paddingVertical: 48 }}>
      <View style={{ padding: 18, borderRadius: 999, backgroundColor: alpha(s.primary, 0.12) }}>
        <Icon name={icon} size={34} color={s.primary} />
      </View>
      <Gap h={18} />
      <T v="titleLarge" center>
        {title}
      </T>
      <Gap h={8} />
      <T v="bodyMedium" center color={s.onSurfaceVariant}>
        {message}
      </T>
    </View>
  );
}

/** Fades and slides a child 18 px up into place. */
export function FadeSlideIn({ children, delay = 0, style }: { children: React.ReactNode; delay?: number; style?: StyleProp<ViewStyle> }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(v, {
      toValue: 1,
      duration: AppMotion.entrance + delay,
      easing: easeOutCubic,
      useNativeDriver: native,
    }).start();
  }, [v, delay]);
  return (
    <Animated.View
      style={[
        style,
        { opacity: v, transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [18, 0] }) }] },
      ]}
    >
      {children}
    </Animated.View>
  );
}

/**
 * A figure in large type that shrinks to fit the space it has, instead of
 * wrapping or running off the edge ("₦1,250,000.00").
 */
export function FitText({ children, style, align = 'left', ...rest }: TProps & { children: string; align?: 'left' | 'center' | 'right' }) {
  const [box, setBox] = useState(0);
  const [natural, setNatural] = useState(0);
  const flat = (StyleSheet.flatten(style) ?? {}) as TextStyle;
  const v = rest.v ?? 'bodyMedium';
  const base = flat.fontSize ?? typeScale[v].fontSize;
  const scale = box && natural > box ? box / natural : 1;
  return (
    <View
      style={{ alignSelf: 'stretch', alignItems: align === 'left' ? 'flex-start' : align === 'right' ? 'flex-end' : 'center' }}
      onLayout={(e) => setBox(e.nativeEvent.layout.width)}
    >
      <T {...rest} style={[style, { fontSize: base * scale, lineHeight: undefined }]} numberOfLines={1}>
        {children}
      </T>
      <View style={{ position: 'absolute', opacity: 0, flexDirection: 'row', width: 10000 }} pointerEvents="none">
        <T {...rest} style={[style, { lineHeight: undefined }]} onLayout={(e) => setNatural(e.nativeEvent.layout.width)}>
          {children}
        </T>
      </View>
    </View>
  );
}
