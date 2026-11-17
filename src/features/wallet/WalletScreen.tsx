import { router } from 'expo-router';
import React from 'react';
import { View } from 'react-native';

import { AppConfig } from '@/core/config';
import { formatDate, money, moneyColor, signedMoney } from '@/core/format';
import { LedgerEntry, ledgerBank } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, useWallet } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { FilledButton, OutlinedButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { AppHeader, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { openSheet } from '@/ui/overlay';
import { AsyncContent, EmptyState, FitText, GradientPanel } from '@/ui/widgets';

export default function WalletScreen() {
  const wallet = useWallet();
  return (
    <Scaffold appBar={<AppHeader title="Wallet" back />}>
      <AsyncContent
        query={wallet}
        onRetry={() => invalidate(keys.wallet)}
        data={(value) => (
          <RefreshScroll
            onRefresh={() => invalidate(keys.wallet)}
            contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}
          >
            <GradientPanel colors={AppColors.heroPanel}>
              <T w={800} color={AppColors.heroText} style={{ fontSize: 11, letterSpacing: 0.7 }}>
                AVAILABLE BALANCE
              </T>
              <View style={{ height: 8 }} />
              <FitText v="displaySmall" w={800} mono color={AppColors.cyan}>
                {money(value.availableCents)}
              </FitText>
              <View style={{ height: 10 }} />
              <T color={AppColors.heroText}>{`${money(value.lockedCents)} locked in active games`}</T>
              <View style={{ height: 20 }} />
              <View style={{ flexDirection: 'row' }}>
                <View style={{ flex: 1 }}>
                  <FilledButton label="Top up" onPress={() => router.push('/wallet/top-up')} />
                </View>
                <View style={{ width: 10 }} />
                <View style={{ flex: 1 }}>
                  {/* Withdraw asks for a verified email and a bank account first if either is missing. */}
                  <OutlinedButton label="Withdraw" color="#FFFFFF" style={{ minHeight: 54 }} onPress={() => router.push('/withdraw')} />
                </View>
              </View>
            </GradientPanel>
            <View style={{ height: 26 }} />
            {AppConfig.enableDevCredit ? (
              <>
                <OutlinedButton icon="science_outlined" label="Add development credit" onPress={showDevCredit} />
                <View style={{ height: 18 }} />
              </>
            ) : null}
            <T v="titleLarge">Transaction ledger</T>
            <View style={{ height: 10 }} />
            {value.ledger.length === 0 ? (
              <EmptyState icon="receipt_long_outlined" title="No transactions" message="Wallet activity appears here." />
            ) : (
              <GradientPanel>
                {value.ledger.map((entry) => (
                  <LedgerRow key={entry.id} entry={entry} />
                ))}
              </GradientPanel>
            )}
          </RefreshScroll>
        )}
      />
    </Scaffold>
  );
}

async function showDevCredit() {
  const amount = await openSheet<number>((close) => <DevCreditSheet close={close} />);
  if (amount == null) return;
  try {
    await gateway.creditWallet(amount);
    invalidate(keys.wallet, keys.dashboard);
    AppNotice.success('Wallet credited successfully.');
  } catch (e) {
    AppNotice.error(e ?? 'Top up failed.');
  }
}

function DevCreditSheet({ close }: { close: (v?: number) => void }) {
  const s = useScheme();
  return (
    <View style={{ paddingHorizontal: 20, paddingTop: 16, paddingBottom: 24 }}>
      <T v="titleLarge">Choose an amount</T>
      <View style={{ height: 6 }} />
      <T color={s.onSurfaceVariant}>Development credits only. Replace with signed payment webhooks.</T>
      <View style={{ height: 18 }} />
      {[100000, 200000, 500000, 1000000].map((amount) => (
        <View key={amount} style={{ marginBottom: 8 }}>
          <OutlinedButton label={money(amount)} onPress={() => close(amount)} />
        </View>
      ))}
    </View>
  );
}

function LedgerRow({ entry }: { entry: LedgerEntry }) {
  const s = useScheme();
  const credit = entry.amountCents > 0;
  const color = moneyColor(s, entry.amountCents) ?? s.positive;
  const bank = ledgerBank(entry);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 10 }}>
      <View
        style={{
          width: 40,
          height: 40,
          borderRadius: 20,
          backgroundColor: alpha(color, 0.13),
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={credit ? 'south_west_rounded' : 'north_east_rounded'} color={color} size={18} />
      </View>
      <View style={{ width: 12 }} />
      <View style={{ flex: 1 }}>
        <T v="titleSmall">{entry.description}</T>
        {/* A withdrawal names the account it was sent to. */}
        {bank ? (
          <T v="bodySmall" color={s.onSurfaceVariant}>
            {bank.accountName}
          </T>
        ) : null}
        <T v="bodySmall" color={s.onSurfaceVariant}>
          {formatDate(entry.createdAt, 'd MMM · HH:mm')}
        </T>
      </View>
      <T v="titleMedium" w={900} mono color={moneyColor(s, entry.amountCents)}>
        {signedMoney(entry.amountCents)}
      </T>
    </View>
  );
}
