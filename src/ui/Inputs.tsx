import React, { useEffect, useRef, useState } from 'react';
import {
  Animated,
  KeyboardTypeOptions,
  Platform,
  Pressable,
  StyleProp,
  Switch,
  TextInput,
  TextInputProps,
  View,
  ViewStyle,
} from 'react-native';

import { alpha, font, useScheme } from '@/theme/theme';
import { Icon } from './Icon';
import { T } from './Text';

export type FieldProps = {
  value: string;
  onChangeText?: (v: string) => void;
  label?: string;
  hint?: string;
  helper?: string;
  error?: string | null;
  prefixIcon?: string;
  suffixText?: string;
  /** Text before the value, shown once the field has focus or text (prefixText). */
  prefixText?: string;
  prefixSize?: number;
  suffix?: React.ReactNode;
  keyboardType?: KeyboardTypeOptions;
  secure?: boolean;
  editable?: boolean;
  autoFocus?: boolean;
  maxLength?: number;
  multiline?: boolean;
  dense?: boolean;
  textAlign?: 'left' | 'center' | 'right';
  inputStyle?: TextInputProps['style'];
  style?: StyleProp<ViewStyle>;
  onSubmitEditing?: () => void;
  autoCapitalize?: TextInputProps['autoCapitalize'];
  autoComplete?: TextInputProps['autoComplete'];
  textContentType?: TextInputProps['textContentType'];
  returnKeyType?: TextInputProps['returnKeyType'];
  /** Keeps only these characters as they are typed (inputFormatters). */
  allow?: RegExp;
  onFocus?: () => void;
  onBlur?: () => void;
  /** Hide the space under the field when there is no helper or error. */
  hideErrorText?: boolean;
};

/**
 * A Material 3 filled text field with an outline (the app's InputDecoration
 * theme): radius 16, label floating onto the border when it has focus or text.
 */
export function TextField(p: FieldProps) {
  const s = useScheme();
  const [focused, setFocused] = useState(false);
  const floating = focused || p.value.length > 0 || !p.label;
  const anim = useRef(new Animated.Value(floating ? 1 : 0)).current;
  useEffect(() => {
    Animated.timing(anim, { toValue: floating ? 1 : 0, duration: 150, useNativeDriver: false }).start();
  }, [floating, anim]);
  const enabled = p.editable !== false;
  const hasError = !!p.error;
  const borderColor = hasError ? s.error : focused ? s.primary : s.inputBorder;
  const padV = p.dense ? 10 : 16;
  const left = p.prefixIcon ? 48 : p.dense ? 10 : 16;

  const onChange = (text: string) => {
    const next = p.allow ? [...text].filter((ch) => p.allow!.test(ch)).join('') : text;
    p.onChangeText?.(p.maxLength ? next.slice(0, p.maxLength) : next);
  };

  return (
    <View style={p.style}>
      <View
        style={{
          backgroundColor: enabled ? s.inputFill : alpha(s.inputFill, 0.6),
          borderRadius: p.dense ? 12 : 16,
          borderWidth: focused || hasError ? 1.5 : 1,
          borderColor,
          flexDirection: 'row',
          alignItems: p.multiline ? 'flex-start' : 'center',
          minHeight: p.dense ? 40 : 56,
          opacity: enabled ? 1 : 0.6,
        }}
      >
        {p.prefixIcon ? (
          <View style={{ width: 48, alignItems: 'center' }}>
            <Icon name={p.prefixIcon} color={hasError ? s.error : s.onSurfaceVariant} />
          </View>
        ) : null}
        {p.prefixText && floating ? (
          <T
            v="bodyLarge"
            color={s.onSurfaceVariant}
            style={{ paddingLeft: p.prefixIcon ? 0 : 16, fontSize: p.prefixSize ?? 16, lineHeight: (p.prefixSize ?? 16) + 6 }}
          >
            {p.prefixText}
          </T>
        ) : null}
        <TextInput
          value={p.value}
          onChangeText={onChange}
          placeholder={floating ? p.hint : undefined}
          placeholderTextColor={alpha(s.onSurfaceVariant, 0.8)}
          keyboardType={p.keyboardType}
          secureTextEntry={p.secure}
          editable={enabled}
          autoFocus={p.autoFocus}
          maxLength={p.allow ? undefined : p.maxLength}
          multiline={p.multiline}
          onSubmitEditing={p.onSubmitEditing}
          autoCapitalize={p.autoCapitalize}
          autoComplete={p.autoComplete}
          textContentType={p.textContentType}
          returnKeyType={p.returnKeyType}
          onFocus={() => {
            setFocused(true);
            p.onFocus?.();
          }}
          onBlur={() => {
            setFocused(false);
            p.onBlur?.();
          }}
          style={[
            {
              flex: 1,
              paddingTop: padV + (p.label && !p.dense ? 2 : 0),
              paddingBottom: padV - (p.label && !p.dense ? 2 : 0),
              paddingLeft: p.prefixIcon || (p.prefixText && floating) ? 0 : p.dense ? 10 : 16,
              paddingRight: p.suffixText || p.suffix ? 4 : p.dense ? 10 : 16,
              color: s.onSurface,
              fontSize: 16,
              textAlign: p.textAlign,
              ...font(400),
              ...(Platform.OS === 'web' ? ({ outlineStyle: 'none' } as object) : null),
            },
            p.inputStyle,
          ]}
        />
        {p.suffixText ? (
          <T v="bodyLarge" color={s.onSurfaceVariant} style={{ paddingRight: p.dense ? 10 : 16 }}>
            {p.suffixText}
          </T>
        ) : null}
        {p.suffix}
        {p.label ? (
          <Animated.View
            pointerEvents="none"
            style={{
              position: 'absolute',
              left: anim.interpolate({ inputRange: [0, 1], outputRange: [left, p.dense ? 8 : 12] }),
              top: anim.interpolate({ inputRange: [0, 1], outputRange: [p.dense ? 10 : 16, -9] }),
              paddingHorizontal: anim.interpolate({ inputRange: [0, 1], outputRange: [0, 4] }),
              backgroundColor: floating ? s.inputFill : 'transparent',
              borderRadius: 4,
            }}
          >
            <Animated.Text
              numberOfLines={1}
              style={{
                ...font(400),
                color: hasError ? s.error : focused ? s.primary : s.onSurfaceVariant,
                fontSize: anim.interpolate({ inputRange: [0, 1], outputRange: [16, 12] }),
                lineHeight: anim.interpolate({ inputRange: [0, 1], outputRange: [24, 16] }),
              }}
            >
              {p.label}
            </Animated.Text>
          </Animated.View>
        ) : null}
      </View>
      {!p.hideErrorText && (p.error || p.helper) ? (
        <T
          v="bodySmall"
          color={p.error ? s.error : s.onSurfaceVariant}
          style={{ paddingHorizontal: 16, paddingTop: 4 }}
        >
          {p.error || p.helper}
        </T>
      ) : null}
    </View>
  );
}

/** SegmentedButton (single selection, no check icon). */
export function SegmentedButton<V extends string>({
  segments,
  selected,
  onChange,
  disabled,
}: {
  segments: { value: V; label: string; icon?: string }[];
  selected: V;
  onChange: (v: V) => void;
  disabled?: boolean;
}) {
  const s = useScheme();
  return (
    <View
      style={{
        flexDirection: 'row',
        borderWidth: 1,
        borderColor: s.outline,
        borderRadius: 999,
        overflow: 'hidden',
        opacity: disabled ? 0.5 : 1,
      }}
    >
      {segments.map((seg, i) => {
        const on = seg.value === selected;
        return (
          <Pressable
            key={seg.value}
            disabled={disabled}
            accessibilityRole="button"
            accessibilityState={{ selected: on }}
            onPress={() => onChange(seg.value)}
            style={{
              flex: 1,
              minHeight: 40,
              paddingHorizontal: 12,
              paddingVertical: 6,
              flexDirection: 'row',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
              backgroundColor: on ? s.primaryContainer : 'transparent',
              borderLeftWidth: i === 0 ? 0 : 1,
              borderLeftColor: s.outline,
            }}
          >
            {seg.icon ? <Icon name={seg.icon} size={18} color={on ? s.onPrimaryContainer : s.onSurface} /> : null}
            <T v="labelLarge" color={on ? s.onPrimaryContainer : s.onSurface} numberOfLines={2} center style={{ flexShrink: 1 }}>
              {seg.label}
            </T>
          </Pressable>
        );
      })}
    </View>
  );
}

/** SwitchListTile. */
export function SwitchTile({
  title,
  subtitle,
  value,
  onChange,
  disabled = false,
  inset = 16,
}: {
  title: string;
  subtitle?: string;
  value: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  inset?: number;
}) {
  const s = useScheme();
  return (
    <Pressable
      disabled={disabled}
      onPress={() => onChange(!value)}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 8,
        paddingHorizontal: inset,
        minHeight: 56,
        opacity: disabled ? 0.38 : 1,
      }}
    >
      <View style={{ flex: 1, paddingRight: 16 }}>
        <T v="bodyLarge" color={s.onSurface}>
          {title}
        </T>
        {subtitle ? (
          <T v="bodyMedium" color={s.onSurfaceVariant}>
            {subtitle}
          </T>
        ) : null}
      </View>
      <Switch
        value={value}
        disabled={disabled}
        onValueChange={onChange}
        trackColor={{ true: s.fill, false: s.surfaceHigh }}
        thumbColor={value ? s.onFill : s.outline}
        {...(Platform.OS === 'web' ? ({ activeThumbColor: s.onFill } as object) : null)}
      />
    </Pressable>
  );
}

/** ListTile: leading, title, subtitle, trailing. */
export function ListTile({
  leading,
  title,
  subtitle,
  trailing,
  onPress,
  dense,
}: {
  leading?: React.ReactNode;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  trailing?: React.ReactNode;
  onPress?: () => void;
  dense?: boolean;
}) {
  const s = useScheme();
  return (
    <Pressable
      disabled={!onPress}
      onPress={onPress}
      style={({ pressed }) => ({
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: 16,
        paddingVertical: dense ? 4 : 8,
        minHeight: dense ? 48 : 56,
        gap: 16,
        backgroundColor: pressed ? alpha(s.onSurface, 0.06) : 'transparent',
      })}
    >
      {leading}
      <View style={{ flex: 1 }}>
        {typeof title === 'string' ? (
          <T v="bodyLarge" color={s.onSurface}>
            {title}
          </T>
        ) : (
          title
        )}
        {typeof subtitle === 'string' ? (
          <T v="bodyMedium" color={s.onSurfaceVariant}>
            {subtitle}
          </T>
        ) : (
          subtitle
        )}
      </View>
      {trailing}
    </Pressable>
  );
}

/** RadioListTile-like option row. */
export function Radio({ selected }: { selected: boolean }) {
  const s = useScheme();
  return (
    <View
      style={{
        width: 20,
        height: 20,
        borderRadius: 10,
        borderWidth: 2,
        borderColor: selected ? s.primary : s.onSurfaceVariant,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {selected ? <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: s.primary }} /> : null}
    </View>
  );
}
