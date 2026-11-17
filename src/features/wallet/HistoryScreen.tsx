import React from 'react';
import { View } from 'react-native';

import { formatDate, moneyColor, signedMoney } from '@/core/format';
import { LedgerEntry, ledgerBank, ledgerReason } from '@/domain/models';
import { invalidate, keys, useWallet } from '@/state/queries';
import { AppSpacing, useScheme } from '@/theme/theme';
import { Icon } from '@/ui/Icon';
import { AppHeader, RefreshScroll, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AsyncContent, EmptyState, GradientPanel } from '@/ui/widgets';

/** The line under an entry: kind, when, and for a withdrawal or its refund, the bank account. */
function details(entry: LedgerEntry) {
  const bank = ledgerBank(entry);
  const reason = ledgerReason(entry);
  return [
    `${entry.kind.replace(/_/g, ' ')} · ${formatDate(entry.createdAt, 'd MMM y · HH:mm')}`,
    ...(bank ? [`${bank.bankName} · ${bank.accountNumber}`, bank.accountName] : []),
    ...(reason ? [`Reason: ${reason}`] : []),
  ].join('\n');
}

export default function HistoryScreen() {
  const s = useScheme();
  const wallet = useWallet();
  return (
    <Scaffold appBar={<AppHeader title="History" back />}>
      <AsyncContent
        query={wallet}
        onRetry={() => invalidate(keys.wallet)}
        data={(value) =>
          value.ledger.length === 0 ? (
            <EmptyState
              icon="history_rounded"
              title="Nothing settled yet"
              message="Your results and wallet activity will appear after each gameweek."
            />
          ) : (
            <RefreshScroll contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}>
              <T color={s.onSurfaceVariant}>A complete record of stakes, refunds, winnings and withdrawals.</T>
              <View style={{ height: 18 }} />
              {value.ledger.map((entry) => (
                <View key={entry.id} style={{ marginBottom: 10 }}>
                  <GradientPanel padding={16}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}>
                      <Icon
                        name={entry.amountCents > 0 ? 'add_circle_outline' : 'remove_circle_outline'}
                        color={moneyColor(s, entry.amountCents) ?? s.onSurfaceVariant}
                      />
                      <View style={{ flex: 1 }}>
                        <T v="bodyLarge" color={s.onSurface}>
                          {entry.description}
                        </T>
                        <T v="bodyMedium" color={s.onSurfaceVariant}>
                          {details(entry)}
                        </T>
                      </View>
                      <T v="titleMedium" w={900} mono color={moneyColor(s, entry.amountCents)}>
                        {signedMoney(entry.amountCents)}
                      </T>
                    </View>
                  </GradientPanel>
                </View>
              ))}
            </RefreshScroll>
          )
        }
      />
    </Scaffold>
  );
}
