import React, { useState } from 'react';
import { FlatList, Pressable, ScrollView, View, useWindowDimensions } from 'react-native';

import { Bank, BankAccount } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, queryClient, useBankAccount, useBanks } from '@/state/queries';
import { AppSpacing, useScheme } from '@/theme/theme';
import { FilledButton, OutlinedButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { ListTile, TextField } from '@/ui/Inputs';
import { AppBar, Scaffold } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { confirm, openSheet } from '@/ui/overlay';
import { AsyncContent, Divider, EmptyState, GradientPanel } from '@/ui/widgets';

/**
 * Profile → Bank account: the one account withdrawals are paid to. The bank
 * is picked from the provider's list and "Check account" asks the provider
 * whose account it is; only then can it be saved. The name is never typed.
 */
export default function BankAccountScreen() {
  const s = useScheme();
  const account = useBankAccount();
  /** True while the form is open over a saved account ("Change"). */
  const [editing, setEditing] = useState(false);
  const [bank, setBank] = useState<Bank | null>(null);
  const [bankError, setBankError] = useState<string | null>(null);
  const [number, setNumber] = useState('');
  const [numberError, setNumberError] = useState<string | null>(null);
  /** The provider's answer for the bank and number in the form; cleared when either changes. */
  const [checked, setChecked] = useState<BankAccount | null>(null);
  const [busy, setBusy] = useState(false);

  const reset = () => {
    setEditing(false);
    setBank(null);
    setNumber('');
    setChecked(null);
    setBankError(null);
    setNumberError(null);
  };

  const startEditing = (saved: BankAccount) => {
    setEditing(true);
    setBank({ name: saved.bankName, code: saved.bankCode });
    setNumber(saved.accountNumber);
    setChecked(null);
  };

  const pickBank = async () => {
    const picked = await openSheet<Bank>((close) => <BankPicker close={close} />);
    if (!picked) return;
    setBank(picked);
    setBankError(null);
    setChecked(null);
  };

  const check = async () => {
    const be = bank == null ? 'Choose your bank' : null;
    const ne = number.trim().length === 10 ? null : 'Enter the 10-digit account number';
    setBankError(be);
    setNumberError(ne);
    if (be || ne || !bank) return;
    setBusy(true);
    try {
      setChecked(await gateway.resolveBankAccount({ bankCode: bank.code, accountNumber: number.trim() }));
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  const save = async () => {
    if (!checked) return;
    setBusy(true);
    try {
      await gateway.saveBankAccount({ bankCode: checked.bankCode, accountNumber: checked.accountNumber });
      // Wait for the saved account to load, so the page goes straight from the form to it.
      try {
        await queryClient.refetchQueries({ queryKey: keys.bankAccount });
      } catch {}
      reset();
      AppNotice.success('Bank account saved.');
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    const ok = await confirm({
      title: 'Remove bank account?',
      message:
        'You will need to add an account again before your next withdrawal. Withdrawals you have already requested are not affected.',
      cancelLabel: 'Keep it',
      confirmLabel: 'Remove',
    });
    if (!ok) return;
    setBusy(true);
    try {
      await gateway.deleteBankAccount();
      invalidate(keys.bankAccount);
      AppNotice.success('Bank account removed.');
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };

  const form = (saved: BankAccount | null) => (
    <View>
      <T v="titleLarge">{saved == null ? 'Add your bank account' : 'Change your bank account'}</T>
      <View style={{ height: 14 }} />
      {/* The bank is chosen from the provider's list, never typed. */}
      <Pressable disabled={busy} onPress={pickBank}>
        <View pointerEvents="none">
          <TextField
            value={bank?.name ?? ''}
            editable={false}
            label="Bank"
            prefixIcon="account_balance_outlined"
            error={bankError}
            suffix={<Icon name="expand_more_rounded" color={s.onSurfaceVariant} style={{ marginRight: 12 }} />}
          />
        </View>
      </Pressable>
      <View style={{ height: 14 }} />
      <TextField
        value={number}
        editable={!busy}
        keyboardType="number-pad"
        allow={/\d/}
        maxLength={10}
        label="Account number"
        prefixIcon="numbers_rounded"
        helper="10 digits"
        error={numberError}
        onChangeText={(v) => {
          setNumber(v);
          if (checked) setChecked(null);
        }}
      />
      <View style={{ height: 16 }} />
      {checked == null ? (
        <FilledButton icon="search_rounded" label="Check account" busy={busy} onPress={check} />
      ) : (
        <>
          <GradientPanel padding={18}>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Icon name="verified_rounded" color={s.positive} />
              <View style={{ width: 12 }} />
              <View style={{ flex: 1 }}>
                <T v="labelSmall" w={800} color={s.onSurfaceVariant} style={{ letterSpacing: 0.7 }}>
                  ACCOUNT NAME
                </T>
                <View style={{ height: 4 }} />
                <T v="titleMedium" w={900}>
                  {checked.accountName}
                </T>
                <View style={{ height: 2 }} />
                <T color={s.onSurfaceVariant}>{`${checked.bankName} · ${checked.accountNumber}`}</T>
              </View>
            </View>
          </GradientPanel>
          <View style={{ height: 10 }} />
          <T color={s.onSurfaceVariant}>Is this your account? Withdrawals will be sent here.</T>
          <View style={{ height: 14 }} />
          <FilledButton icon="check_rounded" label="Yes, save this account" busy={busy} onPress={save} />
        </>
      )}
      {saved != null ? (
        <>
          <View style={{ height: 6 }} />
          <TextButton label="Cancel" onPress={busy ? null : reset} />
        </>
      ) : null}
    </View>
  );

  return (
    <Scaffold appBar={<AppBar title="Bank account" />}>
      <AsyncContent
        query={account}
        onRetry={() => invalidate(keys.bankAccount)}
        data={(saved) => (
          <ScrollView
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}
          >
            <T color={s.onSurfaceVariant} style={{ lineHeight: 20 }}>
              Withdrawals are paid to this account. You can keep one account at a time.
            </T>
            <View style={{ height: 16 }} />
            {saved != null && !editing ? (
              <SavedAccount account={saved} busy={busy} onChange={() => startEditing(saved)} onRemove={remove} />
            ) : (
              form(saved)
            )}
          </ScrollView>
        )}
      />
    </Scaffold>
  );
}

/** The saved account, with the two things that can be done to it. */
function SavedAccount({
  account,
  busy,
  onChange,
  onRemove,
}: {
  account: BankAccount;
  busy: boolean;
  onChange: () => void;
  onRemove: () => void;
}) {
  const s = useScheme();
  const row = (label: string, value: string) => (
    <View style={{ paddingVertical: 10 }}>
      <T v="labelMedium" color={s.onSurfaceVariant}>
        {label}
      </T>
      <View style={{ height: 2 }} />
      <T v="titleMedium">{value}</T>
    </View>
  );
  return (
    <View>
      <GradientPanel padding={{ paddingHorizontal: 20, paddingVertical: 8 }}>
        {row('Bank', account.bankName)}
        <Divider />
        {row('Account number', account.accountNumber)}
        <Divider />
        {row('Account name', account.accountName)}
      </GradientPanel>
      <View style={{ height: 16 }} />
      <View style={{ flexDirection: 'row' }}>
        <View style={{ flex: 1 }}>
          <FilledButton icon="edit_outlined" label="Change" onPress={busy ? null : onChange} />
        </View>
        <View style={{ width: 10 }} />
        <View style={{ flex: 1 }}>
          <OutlinedButton icon="delete_outline_rounded" label="Remove" color={s.error} onPress={busy ? null : onRemove} style={{ minHeight: 54 }} />
        </View>
      </View>
    </View>
  );
}

/** A searchable list of banks, in a sheet. Closes with the bank tapped. */
function BankPicker({ close }: { close: (b?: Bank) => void }) {
  const s = useScheme();
  const banks = useBanks();
  const { height } = useWindowDimensions();
  const [query, setQuery] = useState('');
  return (
    <View style={{ height: height * 0.75, paddingTop: 12 }}>
      <View style={{ paddingHorizontal: 20, paddingBottom: 12 }}>
        <TextField
          value={query}
          autoFocus
          label="Search banks"
          prefixIcon="search_rounded"
          onChangeText={(v) => setQuery(v)}
        />
      </View>
      <View style={{ flex: 1 }}>
        <AsyncContent
          query={banks}
          onRetry={() => invalidate(keys.banks)}
          data={(items) => {
            const q = query.trim().toLowerCase();
            const matches = q ? items.filter((b) => b.name.toLowerCase().includes(q)) : items;
            if (matches.length === 0) {
              return <EmptyState icon="account_balance_outlined" title="No bank found" message="Check the spelling and try again." />;
            }
            return (
              <FlatList
                data={matches}
                keyExtractor={(b) => b.code + b.name}
                keyboardShouldPersistTaps="handled"
                renderItem={({ item }) => (
                  <ListTile
                    leading={<Icon name="account_balance_outlined" color={s.onSurfaceVariant} />}
                    title={item.name}
                    onPress={() => close(item)}
                  />
                )}
              />
            );
          }}
        />
      </View>
    </View>
  );
}
