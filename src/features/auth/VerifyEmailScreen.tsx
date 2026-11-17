import { useQueryClient } from '@tanstack/react-query';
import React, { useState } from 'react';
import { ScrollView, View } from 'react-native';

import { displayEmail } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { authStore } from '@/state/auth';
import { invalidate, keys } from '@/state/queries';
import { AppColors, AppSpacing, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { AppBar, Scaffold, goBack } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { GradientPanel } from '@/ui/widgets';
import { Dashboard } from '@/domain/models';

const validEmail = (v: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v.trim());

/**
 * "Verify email", opened from Home and Profile. Enter the address and get a
 * six-digit code, then enter the code. Nothing changes until it is accepted.
 */
export default function VerifyEmailScreen() {
  const s = useScheme();
  const client = useQueryClient();
  const [email, setEmail] = useState(() => {
    // Start from the address already on the account, if it is a real one.
    const user = client.getQueryData<Dashboard>(keys.dashboard)?.user ?? authStore.get().session?.user;
    return user ? displayEmail(user) : '';
  });
  const [emailError, setEmailError] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [codeError, setCodeError] = useState<string | null>(null);
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const sendCode = async () => {
    if (!validEmail(email)) {
      setEmailError('Enter a valid email address');
      return;
    }
    setEmailError(null);
    const address = email.trim().toLowerCase();
    setBusy(true);
    try {
      const challenge = await gateway.requestEmailVerification(address);
      setSentTo(address);
      setCode('');
      AppNotice.info(challenge.message);
    } catch (e) {
      AppNotice.error(e);
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
      await gateway.verifyEmail(sentTo, code.trim());
      // Home and Profile read the user from the dashboard; refresh it so the
      // "Verify email" link goes away.
      invalidate(keys.dashboard);
      AppNotice.success(`${sentTo} is now verified.`);
      goBack('/home');
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Scaffold appBar={<AppBar title="Verify email" />}>
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: AppSpacing.lg }}
        keyboardShouldPersistTaps="handled"
      >
        <View style={{ width: '100%', maxWidth: 440, alignSelf: 'center' }}>
          <GradientPanel colors={AppColors.heroPanel}>
            <Icon name="mark_email_read_outlined" color={AppColors.lime} size={34} />
            <View style={{ height: 14 }} />
            <T v="headlineSmall" w={900} color="#FFFFFF">
              Confirm your email
            </T>
            <View style={{ height: 8 }} />
            <T color={AppColors.heroText} style={{ lineHeight: 21 }}>
              We use it for receipts, pool approvals and anything important about your money.
            </T>
          </GradientPanel>
          <View style={{ height: 24 }} />
          <TextField
            value={email}
            onChangeText={setEmail}
            editable={!busy}
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
            textContentType="emailAddress"
            label="Email address"
            prefixIcon="mail_outline_rounded"
            error={emailError}
          />
          <View style={{ height: 14 }} />
          {sentTo == null ? (
            <FilledButton icon="send_rounded" label="Send code" busy={busy} onPress={sendCode} />
          ) : (
            <>
              <T color={s.onSurfaceVariant}>{`Enter the six-digit code we sent to ${sentTo}.`}</T>
              <View style={{ height: 12 }} />
              <TextField
                value={code}
                onChangeText={setCode}
                editable={!busy}
                autoFocus
                keyboardType="number-pad"
                autoComplete="one-time-code"
                textContentType="oneTimeCode"
                allow={/\d/}
                maxLength={6}
                label="Verification code"
                prefixIcon="pin_outlined"
                error={codeError}
                onSubmitEditing={verify}
              />
              <View style={{ height: 14 }} />
              <FilledButton icon="verified_outlined" label="Verify email" busy={busy} onPress={verify} />
              <View style={{ height: 6 }} />
              <TextButton label="Send a new code" onPress={busy ? null : sendCode} />
            </>
          )}
        </View>
      </ScrollView>
    </Scaffold>
  );
}
