import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import React from 'react';
import { Platform, ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppColors, Brand, alpha, useScheme } from '@/theme/theme';
import { FilledButton, OutlinedButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { BrandMark, Divider, FadeSlideIn } from '@/ui/widgets';
import { Glow } from './Glow';
import { WebQrSignIn } from './WebQrSignIn';

const isWeb = Platform.OS === 'web';

export default function WelcomeScreen() {
  const s = useScheme();
  const insets = useSafeAreaInsets();
  const muted = s.onSurfaceVariant;

  /**
   * FPL sign-in reads the session from FPL's own login page inside an in-app
   * browser. A web page cannot do that to another site, so in a browser this
   * explains what to do instead.
   */
  const signInWithFpl = () => {
    if (isWeb) {
      AppNotice.info(
        'Sign in with FPL works in the FPLboardman mobile app. Sign in there once and verify your email, then use Sign in with email here.',
      );
      return;
    }
    router.replace('/fpl-login');
  };

  const card = (
    <View
      style={{
        backgroundColor: alpha(s.surface, s.dark ? 0.86 : 0.94),
        borderRadius: 24,
        borderWidth: 1,
        borderColor: alpha(s.outlineVariant, 0.5),
        boxShadow: `0px 18px 40px rgba(0,0,0,${s.dark ? 0.35 : 0.08})`,
        paddingTop: 28,
        paddingHorizontal: 24,
        paddingBottom: 24,
      }}
    >
      {isWeb ? (
        <View>
          <WebQrSignIn />
          <View style={{ height: 18 }} />
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <Divider style={{ flex: 1 }} />
            <T color={muted} style={{ paddingHorizontal: 12 }}>
              or
            </T>
            <Divider style={{ flex: 1 }} />
          </View>
          <View style={{ height: 14 }} />
          <OutlinedButton icon="mail_outline_rounded" label="Sign in with email" onPress={() => router.replace('/email-sign-in')} />
          <View style={{ height: 14 }} />
          <T v="bodySmall" center color={muted}>
            New to FPLboardman? Create your account in the FPLboardman phone app with Sign in with FPL, then sign in here
            with your phone.
          </T>
        </View>
      ) : (
        <View>
          <View style={{ alignItems: 'center' }}>
            <View
              style={{
                width: 72,
                height: 72,
                borderRadius: 36,
                backgroundColor: alpha(s.primary, 0.13),
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="emoji_events_rounded" size={38} color={s.primary} />
            </View>
          </View>
          <View style={{ height: 20 }} />
          <T v="headlineSmall" w={800} center style={{ letterSpacing: -0.4 }}>
            {'Put your gameweek\nwhere your mouth is.'}
          </T>
          <View style={{ height: 10 }} />
          <T v="bodyMedium" center color={muted} style={{ lineHeight: 21 }}>
            Join trusted pools, challenge a rival head to head, and follow every result with a transparent wallet.
          </T>
          <View style={{ height: 26 }} />
          <FilledButton icon="sports_soccer_rounded" label="Sign in with FPL" onPress={signInWithFpl} />
          <View style={{ height: 10 }} />
          <OutlinedButton icon="mail_outline_rounded" label="Sign in with email" onPress={() => router.replace('/email-sign-in')} />
          <View style={{ height: 16 }} />
          <T v="bodySmall" center color={muted}>
            New here? Use Sign in with FPL: it opens the official Fantasy Premier League login, where your password goes
            straight to them and never to us. Once you have verified your email you can also sign in with email.
          </T>
        </View>
      )}
    </View>
  );

  return (
    <LinearGradient
      colors={s.dark ? [Brand.midnight, '#2A1145', '#1E0D33'] : ['#F7F4FA', '#E9FBF1', '#EFE8F6']}
      start={{ x: 0.5, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={{ flex: 1, overflow: 'hidden' }}
    >
      {/* Two soft glows in the brand colours behind the card. */}
      <Glow color={s.dark ? Brand.pitchGreen : Brand.pitchGreen} opacity={s.dark ? 0.2 : 0.14} size={460} style={{ top: -160, left: -120 }} />
      <Glow color={s.dark ? AppColors.cyan : Brand.boardroomPurple} opacity={s.dark ? 0.18 : 0.1} size={520} style={{ bottom: -180, right: -140 }} />
      <ScrollView
        contentContainerStyle={{
          flexGrow: 1,
          justifyContent: 'center',
          paddingHorizontal: 20,
          paddingTop: 32 + insets.top,
          paddingBottom: 32 + insets.bottom,
        }}
        keyboardShouldPersistTaps="handled"
      >
        <View style={{ width: '100%', maxWidth: 420, alignSelf: 'center' }}>
          <View style={{ alignItems: 'center' }}>
            <BrandMark />
          </View>
          <View style={{ height: 24 }} />
          <FadeSlideIn>{card}</FadeSlideIn>
          <View style={{ height: 18 }} />
          <T v="labelSmall" center color={muted}>
            18+ · Play responsibly
          </T>
        </View>
      </ScrollView>
    </LinearGradient>
  );
}
