import React from 'react';
import { ScrollView, View, useWindowDimensions } from 'react-native';

import { AppSpacing, useScheme } from '@/theme/theme';
import { IconButton } from './Buttons';
import { T } from './Text';
import { DialogSurface } from './overlay';
import { Divider } from './widgets';

/** The page-like dialogs (link team, create pool): title, subtitle, close, then a scrolling body. */
export function FormDialog({
  title,
  subtitle,
  onClose,
  maxWidth,
  children,
}: {
  title: string;
  subtitle: string;
  onClose: (() => void) | null;
  maxWidth: number;
  children: React.ReactNode;
}) {
  const s = useScheme();
  const { height } = useWindowDimensions();
  return (
    <DialogSurface maxWidth={maxWidth} maxHeight={height * 0.9}>
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingTop: 16, paddingLeft: 22, paddingRight: 10, paddingBottom: 12 }}>
        <View style={{ flex: 1 }}>
          <T v="titleLarge">{title}</T>
          <View style={{ height: 2 }} />
          <T v="bodySmall" color={s.onSurfaceVariant}>
            {subtitle}
          </T>
        </View>
        <IconButton icon="close_rounded" tooltip="Close" onPress={onClose} />
      </View>
      <Divider />
      <ScrollView style={{ flexShrink: 1 }} contentContainerStyle={{ padding: AppSpacing.lg }} keyboardShouldPersistTaps="handled">
        {children}
      </ScrollView>
    </DialogSurface>
  );
}
