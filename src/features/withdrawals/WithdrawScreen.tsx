import { router } from 'expo-router';
import React, { useRef, useState } from 'react';
import { View } from 'react-native';

import { errorMessage } from '@/core/errors';
import { formatDate, money, moneyColor, signedMoney } from '@/core/format';
import { newIdempotencyKey } from '@/core/gateway';
import {
  BankAccount,
  Dashboard,
  Withdrawal,
  bankSummary,
  nairaToCents,
  withdrawalPaid,
  withdrawalRefunded,
  withdrawalStatusLabel,
  withdrawalStatusNote,
} from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, useBankAccount, useDashboard, useWithdrawals } from '@/state/queries';
import { AppColors, AppSpacing, alpha, font, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { AppBar, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { confirm } from '@/ui/overlay';
import { AsyncContent, GradientPanel, Loading, StatusPill } from '@/ui/widgets';

/**
 * Profile → Withdraw. A verified email and a bank account come first; then an
 * amount, and an administrator approves the request before money goes out.
 * Below the form is every withdrawal and where it stands.
 */
export default function WithdrawScreen() {
  const dashboard = useDashboard();
  return (
    <Scaffold appBar={<AppBar title="Withdraw" />}>
      <AsyncContent query={dashboard} onRetry={() => invalidate(keys.dashboard)} data={(value) => <Body dashboard={value} />} />
    </Scaffold>
  );
}

function Body({ dashboard }: { dashboard: Dashboard }) {
  const s = useScheme();
  const account = useBankAccount();
  const history = useWithdrawals();
  const emailVerified = dashboard.user.emailVerified;

  let accountPart: React.ReactNode;
  if (account.isError) {
    accountPart = (
      <Requirement
        icon="cloud_off_rounded"
        title="Could not load your bank account"
        message={errorMessage(account.error)}
        action="Try again"
        onAction={() => invalidate(keys.bankAccount)}
      />
    );
  } else if (account.data === undefined) {
    accountPart = <Loading style={{ flex: 0, paddingVertical: 24 }} />;
  } else if (account.data == null) {
    accountPart = (
      <Requirement
        icon="account_balance_outlined"
        title="Add your bank account"
        message="Tell us which account to pay. You only do this once."
        action="Add bank account"
        onAction={() => router.push('/bank-account')}
      />
    );
  } else if (!emailVerified) {
    accountPart = <Destination bank={account.data} />;
  } else {
    accountPart = (
      <WithdrawForm
        bank={account.data}
        availableCents={dashboard.wallet.availableCents}
        // Until the list has loaded, assume the usual minimum; the server enforces the real one.
        minimumCents={history.data?.minimumCents ?? 100000}
      />
    );
  }

  return (
    <RefreshScroll
      onRefresh={async () => {
        invalidate(keys.bankAccount, keys.withdrawals);
        await invalidate(keys.dashboard);
      }}
      contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}
    >
      <GradientPanel colors={AppColors.heroPanel}>
        <T w={800} color={AppColors.heroText} style={{ fontSize: 11, letterSpacing: 0.7 }}>
          AVAILABLE TO WITHDRAW
        </T>
        <View style={{ height: 8 }} />
        <T v="displaySmall" w={800} mono color={AppColors.lime}>
          {money(dashboard.wallet.availableCents)}
        </T>
        <View style={{ height: 6 }} />
        <T color={AppColors.heroText} style={{ lineHeight: 20 }}>
          Money locked in active games cannot be withdrawn until the game ends.
        </T>
      </GradientPanel>
      <View style={{ height: 22 }} />
      {/* What is still needed, in the order to do it. */}
      {!emailVerified ? (
        <>
          <Requirement
            icon="mark_email_unread_outlined"
            title="Verify your email first"
            message="We confirm every withdrawal by email, so your address has to be verified before you can withdraw."
            action="Verify email"
            onAction={() => router.push('/verify-email')}
          />
          <View style={{ height: 12 }} />
        </>
      ) : null}
      {accountPart}
      <View style={{ height: 28 }} />
      <T v="titleLarge">Your withdrawals</T>
      <View style={{ height: 10 }} />
      {history.isError ? (
        <T color={s.error}>{errorMessage(history.error)}</T>
      ) : !history.data ? (
        <Loading style={{ flex: 0, paddingVertical: 24 }} />
      ) : history.data.items.length === 0 ? (
        <T color={s.onSurfaceVariant}>Nothing yet. Your requests appear here with their status.</T>
      ) : (
        history.data.items.map((item) => (
          <View key={item.id} style={{ marginBottom: 10 }}>
            <WithdrawalTile item={item} />
          </View>
        ))
      )}
    </RefreshScroll>
  );
}

/** Something the user must do before they can withdraw, with the button that takes them there. */
function Requirement({
  icon,
  title,
  message,
  action,
  onAction,
}: {
  icon: string;
  title: string;
  message: string;
  action: string;
  onAction: () => void;
}) {
  const s = useScheme();
  return (
    <GradientPanel>
      <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
        <Icon name={icon} color={s.primary} />
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleMedium">{title}</T>
          <View style={{ height: 4 }} />
          <T color={s.onSurfaceVariant} style={{ lineHeight: 20 }}>
            {message}
          </T>
        </View>
      </View>
      <View style={{ height: 14 }} />
      <FilledButton label={action} onPress={onAction} />
    </GradientPanel>
  );
}

/** The account the money will go to, with a link to change it. */
function Destination({ bank }: { bank: BankAccount }) {
  const s = useScheme();
  return (
    <GradientPanel padding={18}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View
          style={{
            width: 40,
            height: 40,
            borderRadius: 20,
            backgroundColor: alpha(s.primary, 0.13),
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="account_balance_outlined" color={s.primary} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleMedium" numberOfLines={1}>
            {bank.accountName}
          </T>
          <T v="bodySmall" color={s.onSurfaceVariant}>
            {bankSummary(bank)}
          </T>
        </View>
        <TextButton label="Change" onPress={() => router.push('/bank-account')} />
      </View>
    </GradientPanel>
  );
}

function WithdrawForm({ bank, availableCents, minimumCents }: { bank: BankAccount; availableCents: number; minimumCents: number }) {
  const s = useScheme();
  const [amount, setAmount] = useState('');
  const [touched, setTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  /**
   * Identifies one withdrawal to the server. Kept until the request is known
   * to have succeeded, so retrying after a lost connection cannot create a
   * second withdrawal for the same tap.
   */
  const requestKey = useRef(newIdempotencyKey());
  const newRequest = () => (requestKey.current = newIdempotencyKey());
  const tooLittle = availableCents < minimumCents;

  const validate = (value: string) => {
    const cents = nairaToCents(value);
    if (cents == null) return 'Enter an amount';
    if (cents < minimumCents) return `The minimum is ${money(minimumCents)}`;
    if (cents > availableCents) return `More than your ${money(availableCents)} available`;
    return null;
  };
  const amountOk = validate(amount) == null;

  const submit = async () => {
    setTouched(true);
    if (validate(amount) != null) return;
    const cents = nairaToCents(amount)!;
    const ok = await confirm({
      title: `Withdraw ${money(cents)}?`,
      message: `To ${bank.accountName}\n${bankSummary(bank)}\n\nAn administrator reviews the request before it is paid.`,
      confirmLabel: 'Withdraw',
    });
    if (!ok) return;
    setBusy(true);
    try {
      await gateway.requestWithdrawal({ amountCents: cents, idempotencyKey: requestKey.current });
      newRequest();
      invalidate(keys.withdrawals, keys.wallet, keys.dashboard);
      // Back to an empty form, without an "Enter an amount" error.
      setAmount('');
      setTouched(false);
      AppNotice.success('Withdrawal requested. We will email you when it is paid.');
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <View>
      <T v="titleLarge">Pay to</T>
      <View style={{ height: 10 }} />
      <Destination bank={bank} />
      <View style={{ height: 18 }} />
      <TextField
        value={amount}
        editable={!busy && !tooLittle}
        keyboardType="decimal-pad"
        allow={/[0-9.,]/}
        label="Amount"
        prefixText="₦ "
        inputStyle={{ ...font(400) }}
        helper={`Available ${money(availableCents)} · minimum ${money(minimumCents)}`}
        // An amount over the balance is flagged as soon as it is typed.
        error={touched ? validate(amount) : null}
        suffix={
          <TextButton
            label="All"
            onPress={
              busy || tooLittle
                ? null
                : () => {
                    setAmount((availableCents / 100).toFixed(2));
                    setTouched(true);
                    newRequest();
                  }
            }
          />
        }
        onChangeText={(v) => {
          setAmount(v);
          setTouched(true);
          // A different amount is a different request.
          newRequest();
        }}
      />
      <View style={{ height: 16 }} />
      <FilledButton icon="north_east_rounded" label="Withdraw" busy={busy} onPress={tooLittle || !amountOk ? null : submit} />
      <View style={{ height: 10 }} />
      <T v="bodySmall" center color={s.onSurfaceVariant} style={{ lineHeight: 17 }}>
        {tooLittle
          ? `You need at least ${money(minimumCents)} available to withdraw.`
          : 'Every withdrawal is reviewed before it is paid. The amount leaves your wallet now and comes straight back if the request is not approved or the transfer fails.'}
      </T>
    </View>
  );
}

function WithdrawalTile({ item }: { item: Withdrawal }) {
  const s = useScheme();
  const refunded = withdrawalRefunded(item);
  const color = withdrawalPaid(item) ? s.positive : refunded ? s.error : s.secondary;
  const bank = item.bank;
  return (
    <GradientPanel padding={16}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T v="titleMedium" w={900} mono color={refunded ? undefined : moneyColor(s, -item.amountCents)} style={{ flex: 1 }}>
          {/* Money leaving the wallet, unless it came back. */}
          {refunded ? money(item.amountCents) : signedMoney(-item.amountCents)}
        </T>
        <StatusPill label={withdrawalStatusLabel(item)} color={color} />
      </View>
      <View style={{ height: 6 }} />
      <T v="bodySmall" color={s.onSurfaceVariant}>
        {[...(bank ? [bankSummary(bank)] : []), formatDate(item.createdAt, 'd MMM y · HH:mm')].join('  ·  ')}
      </T>
      <View style={{ height: 6 }} />
      <T style={{ lineHeight: 19 }}>{withdrawalStatusNote(item)}</T>
      {item.reason && refunded ? (
        <T color={s.onSurfaceVariant} style={{ marginTop: 4, lineHeight: 19 }}>{`Reason: ${item.reason}`}</T>
      ) : null}
    </GradientPanel>
  );
}
