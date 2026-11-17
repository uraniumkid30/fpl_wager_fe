import React from 'react';
import { View } from 'react-native';

import { useScheme } from '@/theme/theme';
import { BrandMark, Spinner } from '@/ui/widgets';

/** Shown while the saved sign-in is read. */
export function SplashView() {
  const s = useScheme();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: s.scaffold }}>
      <BrandMark />
      <View style={{ height: 28 }} />
      <Spinner />
    </View>
  );
}
