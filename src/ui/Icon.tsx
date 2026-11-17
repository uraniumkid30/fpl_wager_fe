import { MaterialIcons } from '@expo/vector-icons';
import React from 'react';
import { StyleProp, TextStyle } from 'react-native';

import { useScheme } from '@/theme/theme';

const glyphs = MaterialIcons.glyphMap as Record<string, number>;
const special: Record<string, string> = { copy_rounded: 'content-copy' };

/** Material icons by their Flutter names ("emoji_events_rounded"). */
export function glyph(name: string): keyof typeof MaterialIcons.glyphMap {
  if (special[name]) return special[name] as any;
  const outlined = name.includes('_outlined');
  const base = name.replace(/_rounded|_outlined|_sharp/g, '').replace(/_/g, '-');
  const candidates = outlined ? [`${base}-outline`, `outline-${base}`, base] : [base];
  return (candidates.find((c) => c in glyphs) ?? 'help-outline') as any;
}

export function Icon({
  name,
  size = 24,
  color,
  style,
}: {
  name: string;
  size?: number;
  color?: string;
  style?: StyleProp<TextStyle>;
}) {
  const scheme = useScheme();
  return <MaterialIcons name={glyph(name)} size={size} color={color ?? scheme.onSurface} style={style} />;
}
