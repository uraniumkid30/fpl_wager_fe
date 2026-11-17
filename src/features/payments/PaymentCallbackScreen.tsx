import { useQuery, useQueryClient } from '@tanstack/react-query';
import { router, useLocalSearchParams } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import { Platform, ScrollView, View } from 'react-native';

import { errorMessage } from '@/core/errors';
import { money } from '@/core/format';
import { Payment, paymentFinal, paymentSuccessful } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys } from '@/state/queries';
import { AppSpacing, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { forgetPendingPayment, takePendingPayment } from './pendingPayment';
import { GradientPanel, Spinner } from '@/ui/widgets';

const ATTEMPTS = 9;
const INTERVAL = 3000;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Asks the server about a payment until it is final (up to 9 times, 3 s apart). */
async function verify(reference: string, signal: AbortSignal): Promise<Payment> {
  let payment = await gateway.verifyPayment(reference);
  for (let attempt = 1; attempt < ATTEMPTS && !paymentFinal(payment) && !signal.aborted; attempt++) {
    await sleep(INTERVAL);
    if (signal.aborted) break;
    payment = await gateway.verifyPayment(reference);
  }
  if (paymentSuccessful(payment) && !signal.aborted) invalidate(keys.wallet, keys.dashboard);
  return payment;
}

/** Where the provider returns: the server confirms the payment and credits the wallet. */
export default function PaymentCallbackScreen() {
  const s = useScheme();
  const params = useLocalSearchParams<{ reference?: string; trxref?: string; merchantTransactionReference?: string }>();
  // A provider may put its query on the page address itself (on the web).
  const fromLocation =
    Platform.OS === 'web' ? new URLSearchParams(window.location.search) : new URLSearchParams();
  // Our references start with "fpl_". A provider may add its own reference
  // to the return address instead (GlobalPay can); then the one this browser
  // kept when it left for the checkout is used.
  const candidates = [
    params.reference,
    params.trxref,
    params.merchantTransactionReference,
    fromLocation.get('reference'),
    fromLocation.get('trxref'),
    fromLocation.get('merchantTransactionReference'),
  ].filter((v): v is string => typeof v === 'string' && v.length > 0);
  const [pending] = useState(() => takePendingPayment());
  const reference = candidates.find((v) => v.startsWith('fpl_')) ?? pending ?? candidates[0] ?? '';
  const client = useQueryClient();
  const result = useQuery({
    queryKey: keys.payment(reference),
    queryFn: ({ signal }) => verify(reference, signal),
    enabled: reference.length > 0,
    gcTime: 0,
  });
  const returned = useRef(false);
  useEffect(() => {
    if (result.data && paymentFinal(result.data)) forgetPendingPayment();
    if (result.data && paymentSuccessful(result.data) && !returned.current) {
      returned.current = true;
      AppNotice.success(`${money(result.data.amountCents)} was added to your wallet.`);
      router.replace('/profile/wallet');
    }
  }, [result.data]);
  const again = () => client.resetQueries({ queryKey: keys.payment(reference) });
  const toWallet = () => router.replace('/profile/wallet');

  let content: React.ReactNode;
  if (!reference) {
    content = (
      <Result icon="error_outline_rounded" title="Missing payment reference" message="Return to your wallet and try the top up again." onDone={toWallet} />
    );
  } else if (result.isFetching || (!result.data && !result.isError)) {
    // The spinner shows again while "Check again" runs.
    content = (
      <View style={{ alignItems: 'center' }}>
        <Spinner />
        <View style={{ height: 20 }} />
        <T center>Confirming your payment…</T>
      </View>
    );
  } else if (result.isError) {
    content = (
      <Result icon="sync_problem_rounded" title="Verification needs attention" message={errorMessage(result.error)} onDone={again} action="Try again" />
    );
  } else {
    const p = result.data!;
    content =
      p.status === 'succeeded' ? (
        <Result icon="check_circle_rounded" title="Wallet funded" message={`${money(p.amountCents)} has been added to your wallet.`} onDone={toWallet} />
      ) : p.status === 'failed' ? (
        <Result
          icon="error_outline_rounded"
          title="Payment failed"
          message="The payment did not go through and nothing was added to your wallet. You can try again."
          onDone={() => router.replace('/wallet/top-up')}
          action="Try again"
          onSecondary={toWallet}
          secondaryAction="Back to wallet"
        />
      ) : p.status === 'cancelled' ? (
        <Result icon="cancel_outlined" title="Payment cancelled" message="Nothing was added to your wallet." onDone={toWallet} />
      ) : (
        // Still pending after waiting: a transfer that has not landed, or a payment never finished.
        <Result
          icon="schedule_rounded"
          title="Waiting for confirmation"
          message="Your payment has not been confirmed yet. If you paid, your wallet updates automatically as soon as it is — you do not need to stay on this screen."
          onDone={again}
          action="Check again"
          onSecondary={toWallet}
          secondaryAction="Back to wallet"
        />
      );
  }
  return (
    <Scaffold>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: AppSpacing.lg }}>
        <View style={{ width: '100%', maxWidth: 520, alignSelf: 'center' }}>
          <GradientPanel>{content}</GradientPanel>
        </View>
      </ScrollView>
    </Scaffold>
  );
}

function Result({
  icon,
  title,
  message,
  onDone,
  action = 'Back to wallet',
  onSecondary,
  secondaryAction,
}: {
  icon: string;
  title: string;
  message: string;
  onDone: () => void;
  action?: string;
  onSecondary?: () => void;
  secondaryAction?: string;
}) {
  const s = useScheme();
  return (
    <View style={{ alignItems: 'center' }}>
      <Icon name={icon} size={58} color={s.primary} />
      <View style={{ height: 18 }} />
      <T v="headlineSmall" center>
        {title}
      </T>
      <View style={{ height: 8 }} />
      <T center>{message}</T>
      <View style={{ height: 24 }} />
      <FilledButton label={action} onPress={onDone} style={{ alignSelf: 'stretch' }} />
      {onSecondary && secondaryAction ? (
        <>
          <View style={{ height: 8 }} />
          <TextButton label={secondaryAction} onPress={onSecondary} />
        </>
      ) : null}
    </View>
  );
}
