import { router } from 'expo-router';
import React, { useState } from 'react';
import { Platform, ScrollView, View } from 'react-native';

import { AppException } from '@/core/errors';
import { auth } from '@/state/auth';
import { gateway } from '@/state/gateway';
import { AppColors, AppSpacing, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { AppBar, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { GradientPanel } from '@/ui/widgets';

const validEmail = (v: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v.trim());

/**
 * "Sign in with email": for someone whose account (created by signing in with
 * FPL) has a verified email. A six-digit code emailed to it signs them in.
 */
export default function EmailSignInScreen() {
  const s = useScheme();
  const [email, setEmail] = useState('');
  const [emailError, setEmailError] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [codeError, setCodeError] = useState<string | null>(null);
  /** The address the current code was sent to; null until one is sent. */
  const [sentTo, setSentTo] = useState<string | null>(null);
  /** Set when the server says this address cannot sign in by email. */
  const [unavailable, setUnavailable] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const sendCode = async () => {
    if (!validEmail(email)) {
      setEmailError('Enter a valid email address');
      return;
    }
    setEmailError(null);
    const address = email.trim().toLowerCase();
    setBusy(true);
    setUnavailable(null);
    try {
      const challenge = await gateway.requestEmailSignIn(address);
      setSentTo(address);
      setCode('');
      AppNotice.info(challenge.message);
    } catch (e) {
      if (e instanceof AppException && e.code === 'EMAIL_SIGN_IN_UNAVAILABLE') {
        // No account, or the email is not verified: leave the explanation on the page.
        setUnavailable(e.message);
        setSentTo(null);
        AppNotice.error(e.message);
      } else {
        AppNotice.error(e);
      }
    } finally {
      setBusy(false);
    }
  };

  const verify = async () => {
    if (!sentTo) return;
    if (code.trim().length !== 6) {
      setCodeError('Enter the six-digit code');
      return;
    }
    setCodeError(null);
    setBusy(true);
    try {
      const session = await gateway.verifyEmailSignIn(sentTo, code.trim());
      auth.accept(session);
      // The root layout takes the user on: to an invite they opened, or Home.
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Scaffold
      appBar={<AppBar title="Sign in with email" backIcon="arrow_back_rounded" onBack={() => router.replace('/welcome')} />}
    >
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: AppSpacing.lg }}
        keyboardShouldPersistTaps="handled"
      >
        <View style={{ width: '100%', maxWidth: 440, alignSelf: 'center' }}>
          <GradientPanel colors={AppColors.heroPanel}>
            <Icon name="mail_lock_outlined" color={AppColors.lime} size={34} />
            <View style={{ height: 14 }} />
            <T v="headlineSmall" w={900} color="#FFFFFF">
              Welcome back
            </T>
            <View style={{ height: 8 }} />
            <T color={AppColors.heroText} style={{ lineHeight: 21 }}>
              Enter the email you verified on your FPLboardman account and we will send you a six-digit code. No password
              needed.
            </T>
          </GradientPanel>
          <View style={{ height: 24 }} />
          <TextField
            value={email}
            editable={!busy}
            autoFocus
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
            textContentType="emailAddress"
            label="Email address"
            prefixIcon="mail_outline_rounded"
            error={emailError}
            onChangeText={(v) => {
              setEmail(v);
              // A different address deserves a fresh attempt.
              if (unavailable != null || sentTo != null) {
                setUnavailable(null);
                setSentTo(null);
                setCode('');
              }
            }}
            onSubmitEditing={() => {
              if (sentTo == null) sendCode();
            }}
          />
          <View style={{ height: 14 }} />
          {unavailable != null ? (
            <GradientPanel padding={18}>
              <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
                <Icon name="info_outline_rounded" color={s.error} />
                <View style={{ width: 12 }} />
                <T style={{ flex: 1, lineHeight: 20 }}>{unavailable}</T>
              </View>
              <View style={{ height: 14 }} />
              {/* FPL sign-in needs the mobile app; in a browser the welcome page explains that. */}
              <FilledButton
                icon="sports_soccer_rounded"
                label="Sign in with FPL instead"
                onPress={() => router.replace(Platform.OS === 'web' ? '/welcome' : '/fpl-login')}
              />
            </GradientPanel>
          ) : sentTo == null ? (
            <FilledButton icon="send_rounded" label="Send code" busy={busy} onPress={sendCode} />
          ) : (
            <>
              <T color={s.onSurfaceVariant}>{`Enter the six-digit code we sent to ${sentTo}.`}</T>
              <View style={{ height: 12 }} />
              <TextField
                value={code}
                editable={!busy}
                autoFocus
                keyboardType="number-pad"
                autoComplete="one-time-code"
                textContentType="oneTimeCode"
                allow={/\d/}
                maxLength={6}
                label="Sign-in code"
                prefixIcon="pin_outlined"
                error={codeError}
                onChangeText={setCode}
                onSubmitEditing={verify}
              />
              <View style={{ height: 14 }} />
              <FilledButton icon="login_rounded" label="Sign in" busy={busy} onPress={verify} />
              <View style={{ height: 6 }} />
              <TextButton label="Send a new code" onPress={busy ? null : sendCode} />
            </>
          )}
          <View style={{ height: 18 }} />
          <T v="bodySmall" center color={s.onSurfaceVariant} style={{ lineHeight: 17 }}>
            New to FPLboardman? Go back and use Sign in with FPL. That creates your account; verify your email afterwards
            and you can sign in this way next time.
          </T>
        </View>
      </ScrollView>
    </Scaffold>
  );
}
