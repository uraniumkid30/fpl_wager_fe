import { TabList, TabSlot, TabTrigger, Tabs } from 'expo-router/ui';
import { router, usePathname } from 'expo-router';
import React from 'react';
import { Pressable, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppSpacing, alpha, useScheme } from '@/theme/theme';
import { Icon } from '@/ui/Icon';
import { T } from '@/ui/Text';
import { BrandMark } from '@/ui/widgets';

const destinations = [
  { name: 'home', href: '/home', label: 'Home', icon: 'home_outlined', selected: 'home_rounded' },
  { name: 'pools', href: '/pools', label: 'Pools', icon: 'emoji_events_outlined', selected: 'emoji_events_rounded' },
  { name: 'profile', href: '/profile', label: 'Profile', icon: 'person_outline_rounded', selected: 'person_rounded' },
] as const;

/** Bottom navigation on phones; a navigation rail in a card from 960 wide (extended from 1180). */
export default function AppShell() {
  const { width } = useWindowDimensions();
  const desktop = width >= 960;
  const pathname = usePathname();
  const current = destinations.findIndex((d) => pathname === d.href || pathname.startsWith(`${d.href}/`));

  const go = (index: number) => {
    // Tapping the tab you are on goes back to its first page (Wallet -> Profile).
    router.navigate(destinations[index].href);
  };

  return (
    <Tabs style={{ flex: 1 }}>
      <TabList style={{ display: 'none' }}>
        {destinations.map((d) => (
          <TabTrigger key={d.name} name={d.name} href={d.href} />
        ))}
      </TabList>
      {desktop ? (
        <View style={{ flex: 1, flexDirection: 'row' }}>
          <Rail current={current} onSelect={go} extended={width >= 1180} />
          <View style={{ flex: 1 }}>
            <TabSlot />
          </View>
        </View>
      ) : (
        <View style={{ flex: 1 }}>
          <View style={{ flex: 1 }}>
            <TabSlot />
          </View>
          <BottomBar current={current} onSelect={go} />
        </View>
      )}
    </Tabs>
  );
}

function BottomBar({ current, onSelect }: { current: number; onSelect: (i: number) => void }) {
  const s = useScheme();
  const insets = useSafeAreaInsets();
  return (
    <View
      style={{
        flexDirection: 'row',
        height: 72 + insets.bottom,
        paddingBottom: insets.bottom,
        backgroundColor: s.navBar,
        borderTopWidth: s.dark ? 0 : 1,
        borderTopColor: s.divider,
      }}
    >
      {destinations.map((d, i) => {
        const on = i === current;
        return (
          <Pressable
            key={d.name}
            accessibilityRole="tab"
            accessibilityState={{ selected: on }}
            accessibilityLabel={d.label}
            onPress={() => onSelect(i)}
            style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 4 }}
          >
            <View
              style={{
                width: 64,
                height: 32,
                borderRadius: 16,
                alignItems: 'center',
                justifyContent: 'center',
                backgroundColor: on ? alpha(s.primary, 0.16) : 'transparent',
              }}
            >
              <Icon name={on ? d.selected : d.icon} color={on ? s.primary : s.onSurfaceVariant} />
            </View>
            <T v="labelSmall" w={700} color={on ? s.onSurface : s.onSurfaceVariant}>
              {d.label}
            </T>
          </Pressable>
        );
      })}
    </View>
  );
}

function Rail({ current, onSelect, extended }: { current: number; onSelect: (i: number) => void; extended: boolean }) {
  const s = useScheme();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ padding: AppSpacing.md, paddingTop: AppSpacing.md + insets.top, paddingBottom: AppSpacing.md + insets.bottom }}>
      <View
        style={{
          flex: 1,
          width: extended ? 256 : 80,
          backgroundColor: s.surface,
          borderRadius: 24,
          borderWidth: 1,
          borderColor: s.outlineVariant,
          alignItems: extended ? 'stretch' : 'center',
        }}
      >
        <View style={{ paddingTop: 18, paddingBottom: 28, paddingHorizontal: 12, alignItems: extended ? 'flex-start' : 'center' }}>
          <BrandMark compact iconOnly={!extended} />
        </View>
        {destinations.map((d, i) => {
          const on = i === current;
          return (
            <Pressable
              key={d.name}
              accessibilityRole="tab"
              accessibilityState={{ selected: on }}
              accessibilityLabel={d.label}
              onPress={() => onSelect(i)}
              style={
                extended
                  ? { flexDirection: 'row', alignItems: 'center', height: 56, paddingHorizontal: 12, marginBottom: 4 }
                  : { alignItems: 'center', marginBottom: 12, gap: 4 }
              }
            >
              <View
                style={{
                  width: 56,
                  height: 32,
                  borderRadius: 16,
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: on ? alpha(s.primary, 0.16) : 'transparent',
                }}
              >
                <Icon name={on ? d.selected : d.icon} color={on ? s.primary : s.onSurfaceVariant} />
              </View>
              <T
                v={extended ? 'labelLarge' : 'labelMedium'}
                color={on ? s.onSurface : s.onSurfaceVariant}
                style={extended ? { marginLeft: 12 } : undefined}
              >
                {d.label}
              </T>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}
