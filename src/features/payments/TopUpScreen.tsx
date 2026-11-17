import { router } from 'expo-router';
import React, { useState } from 'react';
import { Platform, Pressable, ScrollView, View } from 'react-native';

import { AppConfig } from '@/core/config';
import { errorMessage } from '@/core/errors';
import { grouped, money } from '@/core/format';
import { nairaToCents, paymentSuccessful } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, usePaymentOptions } from '@/state/queries';
import { createStore } from '@/state/store';
import { AppColors, AppSpacing, alpha, font, useScheme } from '@/theme/theme';
import { FilledButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { AppBar, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { GradientPanel } from '@/ui/widgets';
import { CheckoutOutcome, openCheckout } from './checkout';
import { rememberPendingPayment } from './pendingPayment';

/**
 * The amount last chosen (kept for the session). The provider is not a choice
 * any more: administrators pick it (Zenith GlobalPay, or Paystack) and the
 * server uses it for every top-up.
 */
const draftStore = createStore<{ amountCents: number }>({ amountCents: 100000 });

/** The smallest and largest top-up the server accepts. */
const MINIMUM_CENTS = 10000;
const MAXIMUM_CENTS = 100000000;
/** Quick picks under the amount field. */
const QUICK_AMOUNTS = [100000, 200000, 500000, 1000000];

/** "1,000" from 100000 kobo (whole naira without decimals). */
const nairaText = (cents: number) => (cents % 100 === 0 ? grouped(cents / 100) : (cents / 100).toFixed(2));

export default function TopUpScreen() {
  const s = useScheme();
  const options = usePaymentOptions().data;
  const draft = draftStore.use();
  const [amount, setAmount] = useState(() => nairaText(draftStore.get().amountCents));
  /** What is wrong with the typed amount, or null when it can be paid. */
  const [problem, setProblem] = useState<string | null>(null);
  const [initializing, setInitializing] = useState(false);
  const [initError, setInitError] = useState<unknown>(null);
  /** True from the moment the checkout opens until its result is known. */
  const [checkingOut, setCheckingOut] = useState(false);
  const busy = initializing || checkingOut;

  const amountChanged = (text: string) => {
    setAmount(text);
    const cents = nairaToCents(text);
    let next: string | null = null;
    if (!text.trim()) next = 'Enter the amount to add';
    else if (cents == null) next = 'Enter an amount in naira, like 2,500';
    else if (cents < MINIMUM_CENTS) next = `The minimum top-up is ${money(MINIMUM_CENTS)}`;
    else if (cents > MAXIMUM_CENTS) next = `The most you can add at once is ${money(MAXIMUM_CENTS)}`;
    setProblem(next);
    if (next == null && cents != null) draftStore.set((d) => ({ ...d, amountCents: cents }));
  };

  /**
   * The whole payment: the server starts the transaction and returns the
   * provider's checkout page, the customer pays there, then the server
   * confirms with the provider and credits the wallet. The app never holds a
   * provider key and never tells the server that a payment succeeded.
   */
  const checkout = async () => {
    const d = draftStore.get();
    setInitializing(true);
    setInitError(null);
    let payment;
    try {
      payment = await gateway.initializePayment({
        amountCents: d.amountCents,
        callbackUrl: AppConfig.paymentCallbackUrl,
        cancelUrl: AppConfig.paymentCancelUrl,
      });
    } catch (e) {
      setInitError(e);
      AppNotice.error(e ?? 'Payment could not be initialized. Please try again.');
      return;
    } finally {
      setInitializing(false);
    }
    const confirmation = `/payments/callback?reference=${encodeURIComponent(payment.reference)}`;
    if (AppConfig.useDemoData) {
      router.replace(confirmation as never);
      return;
    }
    const url = payment.checkoutUrl ?? '';
    if (!/^[a-z][a-z0-9+.-]*:/i.test(url)) {
      AppNotice.error('Could not open the secure checkout page.');
      return;
    }
    if (Platform.OS === 'web') {
      // In a browser the provider takes over the tab and redirects back to the
      // confirmation route. Not every provider puts our reference on that
      // address (GlobalPay may not), so it is kept here for the return.
      rememberPendingPayment(payment.reference);
      window.location.assign(url);
      return;
    }
    const outcome = await openCheckout({
      checkoutUrl: url,
      callbackUrl: AppConfig.paymentCallbackUrl,
      providerLabel: options?.label ?? 'Secure',
    });
    if (outcome === 'completed') {
      // The confirmation screen asks the server to verify and settle.
      router.replace(confirmation as never);
      return;
    }
    await checkAfterLeaving(payment.reference, outcome);
  };

  const startCheckout = async () => {
    if (checkingOut) return;
    setCheckingOut(true);
    try {
      await checkout();
    } finally {
      setCheckingOut(false);
    }
  };

  return (
    <Scaffold appBar={<AppBar title="Top up wallet" />}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: AppSpacing.lg }} keyboardShouldPersistTaps="handled">
        <View style={{ width: '100%', maxWidth: 620, alignSelf: 'center' }}>
          <GradientPanel colors={AppColors.heroPanel}>
            <Icon name="shield_outlined" color={AppColors.lime} size={34} />
            <View style={{ height: 16 }} />
            <T v="headlineSmall" w={900} color="#FFFFFF">
              Secure wallet funding
            </T>
            <View style={{ height: 8 }} />
            <T color={AppColors.heroText} style={{ lineHeight: 21 }}>
              Payment credentials and test/live mode are selected securely by the server.
            </T>
          </GradientPanel>
          <View style={{ height: 24 }} />
          <T v="titleLarge">Amount to add</T>
          <View style={{ height: 10 }} />
          <TextField
            value={amount}
            onChangeText={amountChanged}
            editable={!busy}
            keyboardType="decimal-pad"
            allow={/[0-9.,]/}
            hint="0"
            error={problem}
            helper={problem == null ? `From ${money(MINIMUM_CENTS)} to ${money(MAXIMUM_CENTS)}` : undefined}
            prefixText="₦ "
            prefixSize={24}
            inputStyle={{ fontSize: 24, ...font(800, true) }}
          />
          <View style={{ height: 12 }} />
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
            {QUICK_AMOUNTS.map((cents) => {
              const selected = problem == null && draft.amountCents === cents;
              return (
                <Pressable
                  key={cents}
                  disabled={busy}
                  onPress={() => amountChanged(nairaText(cents))}
                  style={{
                    height: 32,
                    paddingHorizontal: 12,
                    borderRadius: 8,
                    borderWidth: 1,
                    borderColor: selected ? 'transparent' : s.outline,
                    backgroundColor: selected ? s.primaryContainer : 'transparent',
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 6,
                  }}
                >
                  {selected ? <Icon name="check_rounded" size={18} color={s.onPrimaryContainer} /> : null}
                  <T v="labelLarge" mono color={selected ? s.onPrimaryContainer : s.onSurfaceVariant}>
                    {money(cents)}
                  </T>
                </Pressable>
              );
            })}
          </View>
          <View style={{ height: 24 }} />
          <ProviderNote label={options?.label} available={options?.available ?? true} />
          <View style={{ height: 28 }} />
          {initError ? (
            <>
              <T color={s.error}>{errorMessage(initError)}</T>
              <View style={{ height: 12 }} />
            </>
          ) : null}
          <FilledButton
            icon="lock_rounded"
            label={problem == null ? `Continue to pay ${money(draft.amountCents)}` : 'Enter an amount'}
            busy={busy}
            onPress={problem != null || options?.available === false ? null : startCheckout}
          />
          <View style={{ height: 10 }} />
          <T v="bodySmall" center color={s.onSurfaceVariant}>
            Checkout opens securely inside the app. Your wallet is credited as soon as the payment is confirmed.
          </T>
        </View>
      </ScrollView>
    </Scaffold>
  );
}

/**
 * The customer cancelled or closed the checkout. They may still have paid,
 * so the server is asked once before saying anything.
 */
async function checkAfterLeaving(reference: string, outcome: CheckoutOutcome) {
  try {
    const payment = await gateway.verifyPayment(reference);
    if (paymentSuccessful(payment)) {
      invalidate(keys.wallet, keys.dashboard);
      AppNotice.success(`${money(payment.amountCents)} was added to your wallet.`);
      router.navigate('/profile/wallet');
      return;
    }
  } catch {
    // Only a courtesy: a completed payment is credited by the provider's webhook anyway.
  }
  AppNotice.info(
    outcome === 'cancelled'
      ? 'Payment cancelled. Nothing was added to your wallet.'
      : 'Checkout closed. If you completed the payment, your wallet updates as soon as it is confirmed.',
  );
}

/** Which provider this top-up goes through: shown, not chosen. */
function ProviderNote({ label, available }: { label?: string; available: boolean }) {
  const s = useScheme();
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        padding: 14,
        borderRadius: 16,
        backgroundColor: alpha(available ? s.primary : s.error, 0.08),
        borderWidth: 1,
        borderColor: alpha(available ? s.primary : s.error, 0.2),
      }}
    >
      <View
        style={{
          width: 40,
          height: 40,
          borderRadius: 20,
          backgroundColor: alpha(available ? s.primary : s.error, 0.14),
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={available ? 'verified_user_outlined' : 'error_outline_rounded'} color={available ? s.primary : s.error} />
      </View>
      <View style={{ width: 12 }} />
      <View style={{ flex: 1 }}>
        <T v="labelMedium" color={s.onSurfaceVariant}>
          Secure payment by
        </T>
        <T v="titleMedium" w={800}>
          {label ?? '…'}
        </T>
        {!available ? (
          <T v="bodySmall" color={s.error}>
            Top-ups are unavailable right now. Please try again later.
          </T>
        ) : null}
      </View>
    </View>
  );
}
