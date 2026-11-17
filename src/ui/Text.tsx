import React from 'react';
import { StyleProp, StyleSheet, Text, TextProps, TextStyle } from 'react-native';

import { TypeName, font, type, useScheme } from '@/theme/theme';

export type TProps = TextProps & {
  /** A Material 3 type style, as Theme.of(context).textTheme.<v> in Flutter. */
  v?: TypeName;
  color?: string;
  /** Overrides the weight of the type style. */
  w?: number;
  /** JetBrains Mono, the brand face for numbers and stats. */
  mono?: boolean;
  center?: boolean;
  style?: StyleProp<TextStyle>;
};

const displayStyles = new Set<TypeName>(['displaySmall', 'headlineMedium', 'headlineSmall']);

/**
 * Text in the app's type scale. Weights become font families (Outfit_800ExtraBold…),
 * because custom fonts need one family per weight on Android.
 */
export function T({ v = 'bodyMedium', color, w, mono, center, style, ...rest }: TProps) {
  const scheme = useScheme();
  const flat = StyleSheet.flatten([type[v], style]) as TextStyle;
  const weight = w ?? (flat.fontWeight ? Number(flat.fontWeight === 'bold' ? 700 : flat.fontWeight) : weightOf(v));
  const resolved: { -readonly [K in keyof TextStyle]: TextStyle[K] } = {
    color: displayStyles.has(v) ? scheme.display : scheme.text,
    ...flat,
    ...font(weight, mono),
    fontWeight: undefined,
    ...(color ? { color } : null),
    ...(center ? { textAlign: 'center' } : null),
  };
  if (flat.color && !color) resolved.color = flat.color;
  return <Text {...rest} style={resolved} />;
}

function weightOf(v: TypeName): number {
  const family = type[v].fontFamily ?? '';
  const m = /_(\d00)/.exec(family);
  return m ? Number(m[1]) : 400;
}
