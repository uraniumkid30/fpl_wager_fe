import React from 'react';
import { ActivityIndicator, Pressable, StyleProp, View, ViewStyle } from 'react-native';

import { alpha, useScheme } from '@/theme/theme';
import { Icon } from './Icon';
import { T } from './Text';

type Base = {
  label?: string;
  children?: React.ReactNode;
  icon?: string;
  onPress?: (() => void) | null;
  busy?: boolean;
  style?: StyleProp<ViewStyle>;
  /** Shrink to the label instead of filling the row. */
  compact?: boolean;
  accessibilityLabel?: string;
};

function Content({ label, children, icon, color, busy, weight }: Base & { color: string; weight: number }) {
  // FilledButton(child: spinner) shows only the spinner; FilledButton.icon keeps its label.
  if (busy && !icon) return <ActivityIndicator size="small" color={color} />;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, flexShrink: 1 }}>
      {busy ? <ActivityIndicator size="small" color={color} /> : icon ? <Icon name={icon} size={18} color={color} /> : null}
      {children ?? (
        <T v="labelLarge" w={weight} color={color} numberOfLines={2} center style={{ flexShrink: 1 }}>
          {label}
        </T>
      )}
    </View>
  );
}

/** FilledButton: Pitch Green with Boardroom Purple text, 54 high, radius 16. */
export function FilledButton(props: Base & { tonal?: boolean; danger?: boolean; height?: number }) {
  const s = useScheme();
  const enabled = !!props.onPress && !props.busy;
  const bg = props.danger ? s.error : props.tonal ? s.primaryContainer : s.fill;
  const fg = props.danger ? '#FFFFFF' : props.tonal ? s.onPrimaryContainer : s.onFill;
  const disabledBg = alpha(s.dark ? '#FFFFFF' : '#1A0B28', 0.12);
  const disabledFg = alpha(s.dark ? '#FFFFFF' : '#1A0B28', 0.38);
  const height = props.height ?? 54;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={props.accessibilityLabel ?? props.label}
      disabled={!enabled}
      onPress={props.onPress ?? undefined}
      style={({ pressed }) => [
        {
          minHeight: height,
          borderRadius: 16,
          paddingHorizontal: 24,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: enabled ? bg : disabledBg,
          opacity: pressed ? 0.85 : 1,
          alignSelf: props.compact ? 'flex-start' : 'stretch',
        },
        props.style,
      ]}
    >
      <Content {...props} color={enabled ? fg : disabledFg} weight={800} />
    </Pressable>
  );
}

/** OutlinedButton: 52 high, radius 16, outline-variant border. */
export function OutlinedButton(props: Base & { color?: string }) {
  const s = useScheme();
  const enabled = !!props.onPress && !props.busy;
  const fg = enabled ? (props.color ?? s.primary) : alpha(s.dark ? '#FFFFFF' : '#1A0B28', 0.38);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={props.accessibilityLabel ?? props.label}
      disabled={!enabled}
      onPress={props.onPress ?? undefined}
      style={({ pressed }) => [
        {
          minHeight: 52,
          borderRadius: 16,
          paddingHorizontal: 24,
          borderWidth: 1,
          borderColor: s.outlineVariant,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: pressed ? alpha(s.primary, 0.08) : 'transparent',
          alignSelf: props.compact ? 'flex-start' : 'stretch',
        },
        props.style,
      ]}
    >
      <Content {...props} color={fg} weight={700} />
    </Pressable>
  );
}

/** TextButton. */
export function TextButton(props: Base & { color?: string }) {
  const s = useScheme();
  const enabled = !!props.onPress && !props.busy;
  const fg = enabled ? (props.color ?? s.primary) : alpha(s.dark ? '#FFFFFF' : '#1A0B28', 0.38);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={props.accessibilityLabel ?? props.label}
      disabled={!enabled}
      onPress={props.onPress ?? undefined}
      style={({ pressed }) => [
        {
          minHeight: 40,
          borderRadius: 999,
          paddingHorizontal: 12,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: pressed ? alpha(s.primary, 0.1) : 'transparent',
          alignSelf: props.compact === false ? 'stretch' : 'center',
        },
        props.style,
      ]}
    >
      <Content {...props} color={fg} weight={500} />
    </Pressable>
  );
}

/** IconButton (standard, filled tonal or filled). */
export function IconButton({
  icon,
  onPress,
  tooltip,
  variant = 'standard',
  color,
  size = 24,
  style,
}: {
  icon: string;
  onPress?: (() => void) | null;
  tooltip?: string;
  variant?: 'standard' | 'tonal' | 'filled';
  color?: string;
  size?: number;
  style?: StyleProp<ViewStyle>;
}) {
  const s = useScheme();
  const enabled = !!onPress;
  const bg = variant === 'tonal' ? s.primaryContainer : variant === 'filled' ? s.fill : 'transparent';
  const fg =
    color ?? (variant === 'tonal' ? s.onPrimaryContainer : variant === 'filled' ? s.onFill : s.onSurfaceVariant);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={tooltip}
      disabled={!enabled}
      onPress={onPress ?? undefined}
      hitSlop={4}
      style={({ pressed }) => [
        {
          width: 40,
          height: 40,
          borderRadius: 20,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: !enabled && variant !== 'standard' ? alpha(s.onSurface, 0.12) : bg,
          opacity: pressed ? 0.7 : enabled ? 1 : 0.38,
        },
        style,
      ]}
    >
      <Icon name={icon} size={size} color={fg} />
    </Pressable>
  );
}

/** FloatingActionButton.extended. */
export function ExtendedFab({ icon, label, onPress }: { icon: string; label: string; onPress: () => void }) {
  const s = useScheme();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => ({
        position: 'absolute',
        right: 16,
        bottom: 16,
        height: 56,
        borderRadius: 16,
        paddingHorizontal: 20,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        backgroundColor: s.fill,
        opacity: pressed ? 0.85 : 1,
        boxShadow: '0px 4px 10px rgba(0,0,0,0.25)',
      })}
    >
      <Icon name={icon} color={s.onFill} />
      <T v="labelLarge" w={600} color={s.onFill}>
        {label}
      </T>
    </Pressable>
  );
}
