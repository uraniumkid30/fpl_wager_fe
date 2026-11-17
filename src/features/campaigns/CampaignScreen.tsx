import { LinearGradient } from 'expo-linear-gradient';
import React from 'react';
import { View } from 'react-native';

import { Campaign } from '@/domain/models';
import { invalidate, keys, useCampaign } from '@/state/queries';
import { AppSpacing, Brand, alpha, useScheme } from '@/theme/theme';
import { FilledButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppBar, MaxWidth, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AsyncContent, GradientPanel, useNow } from '@/ui/widgets';
import { openCampaignAction } from './cta';
import { campaignThemes } from './themes';

/** The full page for a campaign: what it is, its rules and its button. */
export function CampaignScreen({ slug }: { slug: string }) {
  const value = useCampaign(slug);
  return (
    <Scaffold appBar={<AppBar title={value.data?.title ?? ''} />}>
      <AsyncContent
        query={value}
        onRetry={() => invalidate(keys.campaign(slug))}
        data={(campaign) => (
          <RefreshScroll onRefresh={() => invalidate(keys.campaign(slug))} contentContainerStyle={{ padding: AppSpacing.md, paddingBottom: 40 }}>
            <MaxWidth width={720}>
              <Hero campaign={campaign} />
              <Details campaign={campaign} />
            </MaxWidth>
          </RefreshScroll>
        )}
      />
    </Scaffold>
  );
}

function Hero({ campaign }: { campaign: Campaign }) {
  const theme = campaignThemes[campaign.theme];
  return (
    <LinearGradient
      colors={theme.colors}
      locations={[0, 0.55, 1]}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={{ borderRadius: 28, overflow: 'hidden', padding: 24, paddingTop: 28 }}
    >
      <View pointerEvents="none" style={{ position: 'absolute', width: 280, height: 280, borderRadius: 140, right: -90, top: -110, backgroundColor: alpha(theme.glow, 0.22) }} />
      <View pointerEvents="none" style={{ position: 'absolute', right: -24, bottom: -30, opacity: 0.12, transform: [{ rotate: '-12deg' }] }}>
        <Icon name={theme.icon} size={200} color={Brand.white} />
      </View>
      {campaign.badge ? (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start', paddingHorizontal: 10, paddingVertical: 5, borderRadius: 999, backgroundColor: alpha(Brand.white, 0.14) }}>
          <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: theme.accent }} />
          <T v="labelSmall" w={800} color={Brand.white} style={{ letterSpacing: 0.8 }}>
            {campaign.badge.toUpperCase()}
          </T>
        </View>
      ) : null}
      <T v="displaySmall" w={900} color={Brand.white} style={{ marginTop: 16, maxWidth: '90%' }}>
        {campaign.title}
      </T>
      {campaign.tagline ? (
        <T v="bodyLarge" color={alpha(Brand.white, 0.88)} style={{ marginTop: 6, maxWidth: '92%' }}>
          {campaign.tagline}
        </T>
      ) : null}
      {campaign.countdownTo ? <Countdown to={campaign.countdownTo} label={campaign.countdownLabel} accent={theme.accent} /> : null}
      {campaign.highlights.length ? (
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginTop: 18 }}>
          {campaign.highlights.map((h) => (
            <View key={h.label} style={{ flexGrow: 1, minWidth: 120, padding: 12, borderRadius: 16, backgroundColor: alpha(Brand.midnight, 0.32) }}>
              <T v="labelSmall" color={alpha(Brand.white, 0.66)}>
                {h.label.toUpperCase()}
              </T>
              <T v="titleMedium" w={800} color={Brand.white}>
                {h.value}
              </T>
            </View>
          ))}
        </View>
      ) : null}
    </LinearGradient>
  );
}

function Countdown({ to, label, accent }: { to: Date; label: string; accent: string }) {
  const now = useNow();
  const ms = to.getTime() - now.getTime();
  if (ms <= 0) return null;
  const total = Math.floor(ms / 1000);
  const parts = [
    [Math.floor(total / 86400), 'days'],
    [Math.floor(total / 3600) % 24, 'hrs'],
    [Math.floor(total / 60) % 60, 'min'],
    [total % 60, 'sec'],
  ] as const;
  return (
    <View style={{ marginTop: 18 }}>
      {label ? (
        <T v="labelMedium" w={700} color={accent}>
          {label}
        </T>
      ) : null}
      <View style={{ flexDirection: 'row', gap: 8, marginTop: 6 }}>
        {parts.map(([n, unit]) => (
          <View key={unit} style={{ minWidth: 58, paddingVertical: 8, borderRadius: 12, alignItems: 'center', backgroundColor: alpha(Brand.midnight, 0.45) }}>
            <T v="titleLarge" mono w={800} color={Brand.white}>
              {String(n).padStart(2, '0')}
            </T>
            <T v="labelSmall" color={alpha(Brand.white, 0.6)}>
              {unit}
            </T>
          </View>
        ))}
      </View>
    </View>
  );
}

function Details({ campaign }: { campaign: Campaign }) {
  const s = useScheme();
  const theme = campaignThemes[campaign.theme];
  const paragraphs = campaign.body.split(/\n{2,}/).map((p) => p.trim()).filter(Boolean);
  return (
    <View style={{ marginTop: 16, gap: 16 }}>
      {paragraphs.length ? (
        <GradientPanel>
          {paragraphs.map((p, i) => (
            <T key={i} v="bodyLarge" style={{ marginTop: i === 0 ? 0 : 12 }}>
              {p}
            </T>
          ))}
        </GradientPanel>
      ) : null}
      {campaign.rules.length ? (
        <GradientPanel>
          <T v="titleMedium">The rules</T>
          {campaign.rules.map((rule, i) => (
            <View key={i} style={{ flexDirection: 'row', alignItems: 'flex-start', marginTop: 14 }}>
              <View
                style={{
                  width: 28,
                  height: 28,
                  borderRadius: 14,
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: alpha(theme.colors[0], 0.16),
                  marginRight: 12,
                }}
              >
                <T v="labelLarge" mono w={800} color={s.dark ? theme.accent : theme.colors[0]}>
                  {i + 1}
                </T>
              </View>
              <T v="bodyMedium" style={{ flex: 1, marginTop: 4 }}>
                {rule}
              </T>
            </View>
          ))}
        </GradientPanel>
      ) : null}
      {campaign.ctaKind !== 'none' ? (
        <FilledButton label={campaign.ctaLabel} icon="arrow_forward_rounded" onPress={() => openCampaignAction(campaign)} />
      ) : null}
    </View>
  );
}
