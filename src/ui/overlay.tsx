import React, { useEffect, useRef } from 'react';
import {
  Animated,
  BackHandler,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  View,
  useWindowDimensions,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { createStore } from '@/state/store';
import { useScheme } from '@/theme/theme';
import { TextButton } from './Buttons';
import { T } from './Text';
import { easeOutCubic } from './widgets';

type Kind = 'dialog' | 'sheet' | 'page';
type Entry = {
  id: number;
  kind: Kind;
  dismissible: () => boolean;
  render: (close: (value?: unknown) => void) => React.ReactNode;
  resolve: (value: unknown) => void;
  inset?: { horizontal: number; vertical: number };
  /** Android back on a full-screen page: the page decides (for example, back inside a web view). */
  onBack?: () => void;
};

const stack = createStore<Entry[]>([]);
let seq = 0;

function close(id: number, value?: unknown) {
  const entry = stack.get().find((e) => e.id === id);
  if (!entry) return;
  stack.set((s) => s.filter((e) => e.id !== id));
  entry.resolve(value);
}

/**
 * Opens a dialog (showDialog) or a modal bottom sheet and resolves with the
 * value it is closed with, as Navigator.pop(value) did in Flutter.
 */
export function openOverlay<T>(
  kind: Kind,
  render: (close: (value?: T) => void) => React.ReactNode,
  opts: { dismissible?: () => boolean; inset?: { horizontal: number; vertical: number }; onBack?: () => void } = {},
): Promise<T | undefined> {
  return new Promise((resolve) => {
    const id = ++seq;
    stack.set((s) => [
      ...s,
      {
        id,
        kind,
        render: (c) => render(c as (v?: T) => void),
        resolve: resolve as (v: unknown) => void,
        dismissible: opts.dismissible ?? (() => true),
        inset: opts.inset,
        onBack: opts.onBack,
      },
    ]);
  });
}

export const openDialog = <T,>(render: (close: (value?: T) => void) => React.ReactNode, opts?: Parameters<typeof openOverlay>[2]) =>
  openOverlay<T>('dialog', render, opts);
export const openPage = <T,>(render: (close: (value?: T) => void) => React.ReactNode, opts?: Parameters<typeof openOverlay>[2]) =>
  openOverlay<T>('page', render, opts);
export const openSheet = <T,>(render: (close: (value?: T) => void) => React.ReactNode, opts?: Parameters<typeof openOverlay>[2]) =>
  openOverlay<T>('sheet', render, opts);

/** Closes every open dialog and sheet (on sign-out, for instance). */
export function closeAllOverlays() {
  stack.get().forEach((e) => close(e.id));
}

export function OverlayHost() {
  const entries = stack.use();
  useEffect(() => {
    if (Platform.OS !== 'android' || entries.length === 0) return;
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      const top = stack.get()[stack.get().length - 1];
      if (top?.onBack) top.onBack();
      else if (top && top.dismissible()) close(top.id);
      return true;
    });
    return () => sub.remove();
  }, [entries.length]);
  return (
    <>
      {entries.map((e) => (
        <OverlayFrame key={e.id} entry={e} />
      ))}
    </>
  );
}

function OverlayFrame({ entry }: { entry: Entry }) {
  const s = useScheme();
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const progress = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(progress, { toValue: 1, duration: 220, easing: easeOutCubic, useNativeDriver: false }).start();
  }, [progress]);
  const doClose = (v?: unknown) => close(entry.id, v);
  const scrim = (
    <Animated.View
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: progress.interpolate({ inputRange: [0, 1], outputRange: ['rgba(0,0,0,0)', 'rgba(0,0,0,0.5)'] }),
      }}
    >
      <Pressable style={{ flex: 1 }} onPress={() => entry.dismissible() && doClose()} accessibilityLabel="Dismiss" />
    </Animated.View>
  );

  if (entry.kind === 'page') {
    return (
      <Animated.View
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          zIndex: 900,
          opacity: progress,
          transform: [{ translateY: progress.interpolate({ inputRange: [0, 1], outputRange: [40, 0] }) }],
        }}
      >
        {entry.render(doClose)}
      </Animated.View>
    );
  }

  if (entry.kind === 'sheet') {
    return (
      <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, zIndex: 900 }}>
        {scrim}
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={{ flex: 1, justifyContent: 'flex-end', alignItems: 'center' }}
          pointerEvents="box-none"
        >
          <Animated.View
            style={{
              width: '100%',
              maxWidth: 640,
              maxHeight: height * 0.9,
              backgroundColor: s.surface,
              borderTopLeftRadius: 28,
              borderTopRightRadius: 28,
              paddingBottom: insets.bottom,
              transform: [{ translateY: progress.interpolate({ inputRange: [0, 1], outputRange: [80, 0] }) }],
              opacity: progress,
            }}
          >
            <View style={{ alignItems: 'center', paddingTop: 12 }}>
              <View style={{ width: 32, height: 4, borderRadius: 2, backgroundColor: s.outline, opacity: 0.4 }} />
            </View>
            {entry.render(doClose)}
          </Animated.View>
        </KeyboardAvoidingView>
      </View>
    );
  }

  const inset = entry.inset ?? { horizontal: 40, vertical: 24 };
  return (
    <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, zIndex: 900 }}>
      {scrim}
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{
          flex: 1,
          alignItems: 'center',
          justifyContent: 'center',
          paddingHorizontal: inset.horizontal,
          paddingTop: inset.vertical + insets.top,
          paddingBottom: inset.vertical + insets.bottom,
        }}
        pointerEvents="box-none"
      >
        <Animated.View
          style={{
            width: '100%',
            alignItems: 'center',
            opacity: progress,
            transform: [{ scale: progress.interpolate({ inputRange: [0, 1], outputRange: [0.95, 1] }) }],
          }}
          pointerEvents="box-none"
        >
          {entry.render(doClose)}
        </Animated.View>
      </KeyboardAvoidingView>
    </View>
  );
}

/** The surface of a Material 3 dialog: radius 28, at most 560 wide. */
export function DialogSurface({
  children,
  maxWidth = 560,
  maxHeight,
}: {
  children: React.ReactNode;
  maxWidth?: number;
  maxHeight?: number;
}) {
  const s = useScheme();
  return (
    <View
      style={{
        width: '100%',
        maxWidth,
        maxHeight,
        minWidth: 280,
        backgroundColor: s.surface,
        borderRadius: 28,
        overflow: 'hidden',
        boxShadow: '0px 12px 32px rgba(0,0,0,0.35)',
      }}
    >
      {children}
    </View>
  );
}

/** AlertDialog: title, content and right-aligned actions. */
export function AlertDialogView({
  title,
  content,
  actions,
  icon,
}: {
  title?: string;
  content?: React.ReactNode;
  actions: React.ReactNode;
  icon?: React.ReactNode;
}) {
  const s = useScheme();
  const { height } = useWindowDimensions();
  return (
    <DialogSurface maxWidth={560}>
      <View style={{ padding: 24, paddingBottom: 0, maxHeight: height * 0.7 }}>
        {icon ? <View style={{ alignItems: 'center', marginBottom: 16 }}>{icon}</View> : null}
        {title ? (
          <T v="headlineSmall" center={!!icon} style={{ marginBottom: 16 }} color={s.onSurface}>
            {title}
          </T>
        ) : null}
        <ScrollView style={{ flexGrow: 0 }}>
          {typeof content === 'string' ? (
            <T v="bodyMedium" color={s.onSurfaceVariant}>
              {content}
            </T>
          ) : (
            content
          )}
        </ScrollView>
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'flex-end', flexWrap: 'wrap', gap: 8, padding: 24, paddingTop: 24 }}>
        {actions}
      </View>
    </DialogSurface>
  );
}

/** A yes/no question. Resolves true when confirmed. */
export async function confirm(opts: {
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel?: string;
  destructive?: boolean;
}): Promise<boolean> {
  const result = await openDialog<boolean>((done) => <ConfirmBody {...opts} done={done} />);
  return result === true;
}

function ConfirmBody(props: {
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel?: string;
  destructive?: boolean;
  done: (v?: boolean) => void;
}) {
  const s = useScheme();
  return (
    <AlertDialogView
      title={props.title}
      content={props.message}
      actions={
        <>
          <TextButton label={props.cancelLabel ?? 'Cancel'} onPress={() => props.done(false)} />
          <TextButton
            label={props.confirmLabel}
            color={props.destructive ? s.error : undefined}
            onPress={() => props.done(true)}
          />
        </>
      }
    />
  );
}
