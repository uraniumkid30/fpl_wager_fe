import { router } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, RefreshControl, ScrollView, ScrollViewProps, StyleProp, View, ViewStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { money } from '@/core/format';
import { useUnreadCount, useWallet } from '@/state/queries';
import { alpha, font, useScheme } from '@/theme/theme';
import { IconButton } from './Buttons';
import { T } from './Text';
import { WalletIcon } from './WalletIcon';
import { BrandMark, easeOutCubic } from './widgets';

/** Pops the current page, or goes to a fallback when there is nothing to pop (a deep link on the web). */
export function goBack(fallback = '/home') {
  if (router.canGoBack()) router.back();
  else router.replace(fallback as never);
}

/** The page background, with room for the status bar. */
export function Scaffold({
  children,
  appBar,
  fab,
  style,
  topInset = true,
}: {
  children: React.ReactNode;
  appBar?: React.ReactNode;
  fab?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  topInset?: boolean;
}) {
  const s = useScheme();
  const insets = useSafeAreaInsets();
  return (
    <View style={[{ flex: 1, backgroundColor: s.scaffold, paddingTop: topInset ? insets.top : 0 }, style]}>
      {appBar}
      <View style={{ flex: 1 }}>
        {children}
        {fab}
      </View>
    </View>
  );
}

/** Material AppBar: back arrow (when there is somewhere to go back to), title, actions. */
export function AppBar({
  title,
  actions,
  leading,
  showBack = true,
  onBack,
  backIcon = 'arrow_back',
}: {
  title?: React.ReactNode;
  actions?: React.ReactNode;
  leading?: React.ReactNode;
  showBack?: boolean;
  onBack?: () => void;
  backIcon?: string;
}) {
  const s = useScheme();
  const lead =
    leading ??
    (showBack ? (
      <IconButton icon={backIcon} tooltip="Back" color={s.onSurface} onPress={onBack ?? (() => goBack())} />
    ) : null);
  return (
    <View style={{ height: 56, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 4 }}>
      {lead ? <View style={{ width: 48, alignItems: 'center' }}>{lead}</View> : null}
      <View style={{ flex: 1, paddingLeft: lead ? 12 : 12, paddingRight: 8, minWidth: 0 }}>
        {typeof title === 'string' ? (
          <T v="titleLarge" w={800} color={s.onSurface} numberOfLines={1}>
            {title}
          </T>
        ) : (
          title
        )}
      </View>
      {actions ? <View style={{ flexDirection: 'row', alignItems: 'center' }}>{actions}</View> : null}
    </View>
  );
}

/** The header on the main pages: logo or title, wallet balance, notifications, settings. */
export function AppHeader({
  title,
  actions,
  back = false,
  onBack,
}: {
  title?: string;
  actions?: React.ReactNode;
  /** Pushed pages get a back arrow, as Flutter's AppBar adds one when it can pop. */
  back?: boolean;
  onBack?: () => void;
}) {
  const s = useScheme();
  const wallet = useWallet().data;
  const unread = useUnreadCount();
  return (
    <AppBar
      showBack={back}
      onBack={onBack}
      title={
        title == null ? (
          <View style={{ flexShrink: 1, overflow: 'hidden' }}>
            <BrandMark compact />
          </View>
        ) : (
          title
        )
      }
      actions={
        <>
          {actions}
          {wallet ? (
            <View style={{ marginRight: 2 }}>
              <WalletPill cents={wallet.availableCents} onPress={() => router.navigate('/profile/wallet')} />
            </View>
          ) : null}
          <View>
            <IconButton icon="notifications_outlined" tooltip="Notifications" onPress={() => router.push('/notifications')} />
            {unread > 0 ? (
              <View
                pointerEvents="none"
                style={{
                  position: 'absolute',
                  top: 4,
                  right: 2,
                  minWidth: 16,
                  height: 16,
                  borderRadius: 8,
                  paddingHorizontal: 4,
                  backgroundColor: s.error,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <T v="labelSmall" color="#FFFFFF" style={{ fontSize: 11, lineHeight: 14 }}>
                  {unread > 99 ? '99+' : String(unread)}
                </T>
              </View>
            ) : null}
          </View>
          <IconButton icon="tune_rounded" tooltip="Settings" onPress={() => router.push('/settings')} />
          <View style={{ width: 4 }} />
        </>
      }
    />
  );
}

/** The wallet balance in the header; counts up or down to a new balance. */
function WalletPill({ cents, onPress }: { cents: number; onPress: () => void }) {
  const s = useScheme();
  const accent = s.primary;
  const shown = useAnimatedNumber(cents, 700);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Wallet balance ${money(cents)}`}
      onPress={onPress}
      style={({ pressed }) => ({
        flexDirection: 'row',
        alignItems: 'center',
        paddingTop: 5,
        paddingBottom: 5,
        paddingLeft: 5,
        paddingRight: 12,
        borderRadius: 999,
        backgroundColor: alpha(accent, pressed ? 0.16 : 0.09),
        borderWidth: 1,
        borderColor: alpha(accent, 0.26),
      })}
    >
      <View
        style={{
          width: 26,
          height: 26,
          borderRadius: 13,
          backgroundColor: alpha(accent, 0.15),
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <WalletIcon size={16} color={accent} strokeWidth={1.7} />
      </View>
      <View style={{ width: 8 }} />
      <ShrinkText text={money(Math.round(shown))} maxWidth={108} color={s.onSurface} />
    </Pressable>
  );
}

/** A one-line figure that scales down to fit maxWidth. */
function ShrinkText({ text, maxWidth, color }: { text: string; maxWidth: number; color: string }) {
  const [natural, setNatural] = useState(0);
  const size = natural > maxWidth ? (13.5 * maxWidth) / natural : 13.5;
  return (
    <View style={{ maxWidth }}>
      <T mono style={{ fontSize: size, lineHeight: 18, ...font(800, true), color }} numberOfLines={1}>
        {text}
      </T>
      <View style={{ position: 'absolute', opacity: 0, width: 1000, flexDirection: 'row' }} pointerEvents="none">
        <T mono style={{ fontSize: 13.5, ...font(800, true) }} onLayout={(e) => setNatural(e.nativeEvent.layout.width)}>
          {text}
        </T>
      </View>
    </View>
  );
}

export function useAnimatedNumber(target: number, duration: number) {
  const [value, setValue] = useState(target);
  const anim = useRef(new Animated.Value(target)).current;
  useEffect(() => {
    const id = anim.addListener(({ value: v }) => setValue(v));
    Animated.timing(anim, { toValue: target, duration, easing: easeOutCubic, useNativeDriver: false }).start();
    return () => anim.removeListener(id);
  }, [target, duration, anim]);
  return value;
}

/** A scroll view with pull-to-refresh (RefreshIndicator + AlwaysScrollableScrollPhysics). */
export function RefreshScroll({
  onRefresh,
  children,
  contentContainerStyle,
  ...rest
}: ScrollViewProps & { onRefresh?: () => Promise<unknown> }) {
  const s = useScheme();
  const [refreshing, setRefreshing] = useState(false);
  return (
    <ScrollView
      {...rest}
      alwaysBounceVertical
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={[{ flexGrow: 1 }, contentContainerStyle]}
      refreshControl={
        onRefresh ? (
          <RefreshControl
            refreshing={refreshing}
            tintColor={s.primary}
            colors={[s.dark ? s.onFill : s.primary]}
            progressBackgroundColor={s.dark ? s.fill : s.surface}
            onRefresh={async () => {
              setRefreshing(true);
              try {
                await onRefresh();
              } catch {
              } finally {
                setRefreshing(false);
              }
            }}
          />
        ) : undefined
      }
    >
      {children}
    </ScrollView>
  );
}

/** Centers content and caps its width, as ConstrainedBox(maxWidth) in Center did. */
export function MaxWidth({ width, children, style }: { width: number; children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[{ width: '100%', maxWidth: width, alignSelf: 'center' }, style]}>{children}</View>;
}
