import React, { useEffect, useRef } from 'react';
import { Animated, Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { errorMessage } from '@/core/errors';
import { createStore } from '@/state/store';
import { useScheme } from '@/theme/theme';
import { IconButton } from './Buttons';
import { Icon } from './Icon';
import { T } from './Text';
import { easeOutCubic } from './widgets';

type NoticeType = 'success' | 'error' | 'info';
type Notice = { id: number; message: string; type: NoticeType };

const store = createStore<Notice | null>(null);
let timer: ReturnType<typeof setTimeout> | null = null;
let seq = 0;

/**
 * Success, error and information messages in the centre of the screen, over
 * a dimmed background. They go away on their own after a few seconds, on a
 * tap outside the card, or on the close button.
 */
export const AppNotice = {
  success: (message: string) => show(message, 'success', 4000),
  error: (error: unknown) =>
    show(
      errorMessage(error)
        .trim()
        .replace(/^(Exception|Error):\s*/, '')
        .replace(/^[A-Za-z]+Exception:\s*/, ''),
      'error',
      6000,
    ),
  info: (message: string) => show(message, 'info', 4000),
  dismiss,
};

function show(message: string, type: NoticeType, duration: number) {
  dismiss();
  const id = ++seq;
  store.set({ id, message, type });
  timer = setTimeout(() => {
    if (store.get()?.id === id) dismiss();
  }, duration);
}

function dismiss() {
  if (timer) clearTimeout(timer);
  timer = null;
  store.set(null);
}

export function NoticeHost() {
  const notice = store.use();
  if (!notice) return null;
  return <NoticeCard key={notice.id} notice={notice} />;
}

function NoticeCard({ notice }: { notice: Notice }) {
  const s = useScheme();
  const insets = useSafeAreaInsets();
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(progress, { toValue: 1, duration: 220, easing: easeOutCubic, useNativeDriver: false }).start();
  }, [progress]);
  const [accent, icon, title] =
    notice.type === 'success'
      ? [s.success, 'check_circle_rounded', 'Done']
      : notice.type === 'error'
        ? [s.error, 'error_rounded', 'Something went wrong']
        : [s.primary, 'info_rounded', 'Heads up'];
  return (
    <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, zIndex: 1000 }} pointerEvents="box-none">
      <Animated.View
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: progress.interpolate({ inputRange: [0, 1], outputRange: ['rgba(0,0,0,0)', 'rgba(0,0,0,0.38)'] }),
        }}
      >
        <Pressable style={{ flex: 1 }} onPress={dismiss} accessibilityLabel="Close" />
      </Animated.View>
      <View
        pointerEvents="box-none"
        style={{
          flex: 1,
          alignItems: 'center',
          justifyContent: 'center',
          paddingTop: Math.max(24, insets.top),
          paddingBottom: Math.max(24, insets.bottom),
          paddingHorizontal: 24,
        }}
      >
        <Animated.View
          accessibilityLiveRegion="polite"
          style={{
            width: '100%',
            maxWidth: 380,
            opacity: progress,
            transform: [{ scale: progress.interpolate({ inputRange: [0, 1], outputRange: [0.92, 1] }) }],
          }}
        >
          <View
            style={{
              backgroundColor: s.surface,
              borderRadius: 24,
              overflow: 'hidden',
              boxShadow: '0px 12px 32px rgba(0,0,0,0.45)',
            }}
          >
            <View style={{ paddingTop: 30, paddingHorizontal: 24, paddingBottom: 26, alignItems: 'center' }}>
              <View
                style={{
                  width: 64,
                  height: 64,
                  borderRadius: 32,
                  backgroundColor: accent + '24',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name={icon} color={accent} size={34} />
              </View>
              <View style={{ height: 16 }} />
              <T v="titleMedium" w={900} center color={s.onSurface}>
                {title}
              </T>
              <View style={{ height: 8 }} />
              <T v="bodyMedium" center color={s.onSurfaceVariant} style={{ lineHeight: 20 }}>
                {notice.message}
              </T>
            </View>
            <View style={{ position: 'absolute', top: 6, right: 6 }}>
              <IconButton icon="close_rounded" tooltip="Close" onPress={dismiss} />
            </View>
          </View>
        </Animated.View>
      </View>
    </View>
  );
}
