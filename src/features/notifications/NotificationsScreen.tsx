import { router } from 'expo-router';
import React from 'react';
import { View } from 'react-native';

import { formatDate } from '@/core/format';
import { AppNotification, isUnread, notificationRoute } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, useNotifications } from '@/state/queries';
import { AppSpacing, alpha, useScheme } from '@/theme/theme';
import { Icon } from '@/ui/Icon';
import { AppBar, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AsyncContent, EmptyState, GradientPanel, StatusPill } from '@/ui/widgets';

export default function NotificationsScreen() {
  const value = useNotifications();
  return (
    <Scaffold appBar={<AppBar title="Notifications" />}>
      <AsyncContent
        query={value}
        onRetry={() => invalidate(keys.notifications)}
        data={(items) => (
          <RefreshScroll onRefresh={() => invalidate(keys.notifications)} contentContainerStyle={{ padding: items.length ? AppSpacing.md : 0 }}>
            {items.length === 0 ? (
              <EmptyState icon="notifications_none_rounded" title="No notifications" message="Pool approvals and important updates will appear here." />
            ) : (
              items.map((item, i) => (
                <View key={item.id} style={{ marginTop: i === 0 ? 0 : 10 }}>
                  <NotificationCard item={item} />
                </View>
              ))
            )}
          </RefreshScroll>
        )}
      />
    </Scaffold>
  );
}

function NotificationCard({ item }: { item: AppNotification }) {
  const s = useScheme();
  return (
    <GradientPanel
      onPress={async () => {
        if (isUnread(item)) {
          // Being marked read is a nicety; failing to must not stop it opening.
          try {
            await gateway.markNotificationRead(item.id);
            invalidate(keys.notifications);
          } catch {}
        }
        const route = notificationRoute(item);
        if (route) openNotificationRoute(route);
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
        <View
          style={{
            width: 40,
            height: 40,
            borderRadius: 20,
            backgroundColor: alpha(s.primary, 0.14),
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={item.kind === 'pool_approved' ? 'verified_rounded' : 'notifications_rounded'} color={s.primary} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <T v="titleMedium" style={{ flex: 1 }}>
              {item.title}
            </T>
            {isUnread(item) ? <StatusPill label="New" /> : null}
          </View>
          <View style={{ height: 6 }} />
          <T>{item.body}</T>
          <View style={{ height: 8 }} />
          <T v="bodySmall" color={s.onSurfaceVariant}>
            {formatDate(item.createdAt, 'd MMM · HH:mm')}
          </T>
        </View>
      </View>
    </GradientPanel>
  );
}

/**
 * Opens the page a notification points to. Home, Pools and Profile (and the
 * pages inside Profile) live in the tabs and are switched to; every other page
 * opens on top, so Back returns to the notifications.
 */
export function openNotificationRoute(route: string) {
  const text = route.trim();
  if (!text.startsWith('/')) return;
  const path = text.split(/[?#]/)[0];
  const inTabs = path === '/home' || path === '/dashboard' || path === '/pools' || path === '/profile' || path.startsWith('/profile/');
  if (inTabs) router.navigate((path === '/dashboard' ? '/home' : text) as never);
  else router.push(text as never);
}
