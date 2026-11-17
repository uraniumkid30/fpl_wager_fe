import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import React, { useState } from 'react';
import { LayoutChangeEvent, NativeScrollEvent, NativeSyntheticEvent, Pressable, ScrollView, View } from 'react-native';

import { Campaign } from '@/domain/models';
import { useCampaigns } from '@/state/queries';
import { Brand, alpha } from '@/theme/theme';
import { Icon } from '@/ui/Icon';
import { T } from '@/ui/Text';
import { useNow } from '@/ui/widgets';
import { openCampaignAction, shortCountdown } from './cta';
import { campaignThemes } from './themes';

/**
 * The marketing slot at the top of Home and Pools. Shows nothing when no
 * campaign is live (or the server is older and has none), one banner for one
 * campaign, and a swipeable row with dots for several — so the next drive is
 * just a new row in the admin's Campaigns page.
 */
export function CampaignCarousel({ placement, bottomSpacing = 16 }: { placement: 'home' | 'pools'; bottomSpacing?: number }) {
  const { data } = useCampaigns(placement);
  const [width, setWidth] = useState(0);
  const [index, setIndex] = useState(0);
  const items = data ?? [];
  if (items.length === 0) return null;

  const onLayout = (e: LayoutChangeEvent) => setWidth(e.nativeEvent.layout.width);
  if (items.length === 1) {
    return (
      <View style={{ marginBottom: bottomSpacing }}>
        <CampaignBanner campaign={items[0]} />
      </View>
    );
  }
  const gap = 12;
  const cardWidth = Math.max(0, width - 28);
  const onScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    if (!cardWidth) return;
    const next = Math.round(e.nativeEvent.contentOffset.x / (cardWidth + gap));
    if (next !== index) setIndex(Math.max(0, Math.min(items.length - 1, next)));
  };
  return (
    <View style={{ marginBottom: bottomSpacing }} onLayout={onLayout}>
      {width > 0 ? (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          snapToInterval={cardWidth + gap}
          decelerationRate="fast"
          disableIntervalMomentum
          onScroll={onScroll}
          scrollEventThrottle={32}
        >
          {items.map((item, i) => (
            <View key={item.id} style={{ width: cardWidth, marginRight: i === items.length - 1 ? 0 : gap }}>
              <CampaignBanner campaign={item} />
            </View>
          ))}
        </ScrollView>
      ) : null}
      <View style={{ flexDirection: 'row', justifyContent: 'center', marginTop: 10, gap: 6 }}>
        {items.map((item, i) => (
          <View
            key={item.id}
            style={{
              height: 6,
              width: i === index ? 18 : 6,
              borderRadius: 3,
              backgroundColor: i === index ? campaignThemes[items[index].theme].colors[0] : alpha(Brand.boardroomPurple, 0.25),
            }}
          />
        ))}
      </View>
    </View>
  );
}

/** One campaign as a bold gradient card. Tapping it opens its page; the button does what the admin set. */
export function CampaignBanner({ campaign }: { campaign: Campaign }) {
  const theme = campaignThemes[campaign.theme];
  const now = useNow(30_000);
  const countdown = campaign.countdownTo ? shortCountdown(campaign.countdownTo, now) : null;
  const open = () => router.push(`/campaigns/${campaign.slug}`);
  const act = () => (campaign.ctaKind === 'none' ? open() : openCampaignAction(campaign));

  return (
    <Pressable onPress={open} accessibilityRole="button" accessibilityLabel={`${campaign.title}. ${campaign.tagline}`}>
      {({ pressed }) => (
        <LinearGradient
          colors={theme.colors}
          locations={[0, 0.55, 1]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{
            borderRadius: 24,
            overflow: 'hidden',
            padding: 20,
            transform: [{ scale: pressed ? 0.985 : 1 }],
            boxShadow: `0px 14px 30px ${alpha(theme.colors[0], 0.28)}`,
          }}
        >
          {/* Glow and watermark: depth without images, so it loads instantly. */}
          <View
            pointerEvents="none"
            style={{
              position: 'absolute',
              width: 220,
              height: 220,
              borderRadius: 110,
              right: -70,
              top: -90,
              backgroundColor: alpha(theme.glow, 0.22),
            }}
          />
          <View pointerEvents="none" style={{ position: 'absolute', right: -18, bottom: -26, opacity: 0.13, transform: [{ rotate: '-12deg' }] }}>
            <Icon name={theme.icon} size={150} color={Brand.white} />
          </View>

          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                gap: 6,
                paddingHorizontal: 10,
                paddingVertical: 5,
                borderRadius: 999,
                backgroundColor: alpha(Brand.white, 0.14),
                borderWidth: 1,
                borderColor: alpha(Brand.white, 0.18),
              }}
            >
              <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: theme.accent }} />
              <T v="labelSmall" w={800} color={Brand.white} style={{ letterSpacing: 0.8 }}>
                {(campaign.badge || 'Featured').toUpperCase()}
              </T>
            </View>
            {countdown ? (
              <View
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: 4,
                  paddingHorizontal: 9,
                  paddingVertical: 4,
                  borderRadius: 999,
                  backgroundColor: alpha(Brand.midnight, 0.35),
                }}
              >
                <Icon name="schedule_rounded" size={13} color={theme.accent} />
                <T v="labelSmall" mono w={700} color={Brand.white}>
                  {campaign.countdownLabel ? `${campaign.countdownLabel} ${countdown}` : countdown}
                </T>
              </View>
            ) : null}
          </View>

          <T v="headlineMedium" w={900} color={Brand.white} style={{ marginTop: 14, letterSpacing: -0.8, maxWidth: '88%' }}>
            {campaign.title}
          </T>
          {campaign.tagline ? (
            <T v="bodyMedium" color={alpha(Brand.white, 0.86)} style={{ marginTop: 4, maxWidth: '90%' }}>
              {campaign.tagline}
            </T>
          ) : null}

          {campaign.highlights.length ? (
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 14 }}>
              {campaign.highlights.map((h) => (
                <View
                  key={h.label}
                  style={{
                    paddingHorizontal: 10,
                    paddingVertical: 6,
                    borderRadius: 12,
                    backgroundColor: alpha(Brand.midnight, 0.32),
                  }}
                >
                  <T v="labelSmall" color={alpha(Brand.white, 0.66)} style={{ fontSize: 10, lineHeight: 12 }}>
                    {h.label.toUpperCase()}
                  </T>
                  <T v="labelLarge" w={800} color={Brand.white}>
                    {h.value}
                  </T>
                </View>
              ))}
            </View>
          ) : null}

          <View style={{ flexDirection: 'row', marginTop: 16 }}>
            <Pressable
              onPress={act}
              accessibilityRole="button"
              style={({ pressed: down }) => ({
                flexDirection: 'row',
                alignItems: 'center',
                gap: 6,
                paddingHorizontal: 16,
                height: 40,
                borderRadius: 999,
                backgroundColor: theme.accent,
                opacity: down ? 0.85 : 1,
              })}
            >
              <T v="labelLarge" w={800} color={Brand.boardroomPurple}>
                {campaign.ctaLabel}
              </T>
              <Icon name="arrow_forward_rounded" size={18} color={Brand.boardroomPurple} />
            </Pressable>
          </View>
        </LinearGradient>
      )}
    </Pressable>
  );
}
