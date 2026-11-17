import React, { useRef, useState } from 'react';
import { View } from 'react-native';

import { money } from '@/core/format';
import {
  PayoutChoice,
  PoolDrawMethod,
  PoolTerms,
  defaultPayoutChoice,
  drawMethodDescription,
  drawMethodLabel,
  drawMethods,
} from '@/domain/pool';
import { requireLinkedFplTeam } from '@/features/team/linkTeam';
import { openTopUpIfInsufficientFunds } from '@/features/wallet/insufficientFunds';
import { gateway } from '@/state/gateway';
import { afterPoolAction, useDashboard, usePoolTerms } from '@/state/queries';
import { AppColors, alpha, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { FormDialog } from '@/ui/FormDialog';
import { Icon } from '@/ui/Icon';
import { SegmentedButton, TextField } from '@/ui/Inputs';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { openDialog } from '@/ui/overlay';
import { GradientPanel } from '@/ui/widgets';
import { PayoutEditor, payoutProblem } from './PayoutEditor';

/** Opens "Create a private pool"; resolves with the new pool's id (the /pools/create route in Flutter). */
export function openCreatePoolDialog(): Promise<string | undefined> {
  let busy = false;
  return openDialog<string>((close) => <CreatePoolDialog close={close} onBusy={(b) => (busy = b)} />, {
    dismissible: () => !busy,
    inset: { horizontal: 18, vertical: 24 },
  });
}

const nairaOf = (text: string) => {
  const t = text.replace(/,/g, '').trim();
  return /^-?\d+$/.test(t) ? parseInt(t, 10) : null;
};

export const drawIcon = (m: PoolDrawMethod) =>
  m === 'split' ? 'call_split_rounded' : m === 'captains' ? 'workspace_premium_outlined' : 'numbers_rounded';

/** The draw-method chooser and its explanation (shared with the edit form). */
export function DrawMethodPicker({
  value,
  onChange,
  disabled,
}: {
  value: PoolDrawMethod;
  onChange: (m: PoolDrawMethod) => void;
  disabled?: boolean;
}) {
  const s = useScheme();
  return (
    <>
      <SegmentedButton<PoolDrawMethod>
        segments={drawMethods.map((m) => ({ value: m, label: drawMethodLabel[m] }))}
        selected={value}
        onChange={onChange}
        disabled={disabled}
      />
      <View style={{ height: 10 }} />
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'flex-start',
          padding: 14,
          borderRadius: 14,
          backgroundColor: alpha(s.primaryContainer, s.dark ? 0.45 : 0.8),
        }}
      >
        <Icon name={drawIcon(value)} size={20} />
        <View style={{ width: 10 }} />
        <T style={{ flex: 1 }}>{drawMethodDescription[value]}</T>
      </View>
    </>
  );
}

function CreatePoolDialog({ close, onBusy }: { close: (id?: string) => void; onBusy: (b: boolean) => void }) {
  const s = useScheme();
  const gameweek = useDashboard().data?.currentGameweek ?? null;
  // The fee and winners limit the server sets; the usual ones until they load.
  const terms = usePoolTerms().data ?? new PoolTerms();
  const [name, setName] = useState('');
  const [stake, setStake] = useState('');
  const [maxMembers, setMaxMembers] = useState('');
  const [maxTouched, setMaxTouched] = useState(false);
  const [drawMethod, setDrawMethod] = useState<PoolDrawMethod>('split');
  const payout = useRef<PayoutChoice>(defaultPayoutChoice);
  const [errors, setErrors] = useState<{ name?: string | null; stake?: string | null }>({});
  const [busy, setBusyState] = useState(false);
  const setBusy = (b: boolean) => {
    setBusyState(b);
    onBusy(b);
  };

  const nameError = (v: string) => (v.trim().length < 3 ? 'Use at least 3 characters' : null);
  const stakeError = (v: string) => {
    const amount = nairaOf(v);
    if (amount == null) return 'Enter a whole amount in naira';
    if (amount < 1000) return 'The minimum amount is ₦1,000';
    return null;
  };
  const maxError = (v: string) => {
    if (!v) return null;
    const parsed = /^\d+$/.test(v) ? parseInt(v, 10) : null;
    return parsed == null || parsed < 2 ? 'Use 2 or more' : null;
  };

  const create = async (gw: number) => {
    const next = { name: nameError(name), stake: stakeError(stake) };
    setErrors(next);
    setMaxTouched(true);
    if (next.name || next.stake || maxError(maxMembers)) return;
    const max = /^\d+$/.test(maxMembers.trim()) ? parseInt(maxMembers.trim(), 10) : null;
    const problem = payoutProblem(payout.current, terms.winnerRule, max);
    if (problem) {
      AppNotice.error(problem);
      return;
    }
    if (!(await requireLinkedFplTeam('pool'))) return;
    setBusy(true);
    try {
      const pool = await gateway.createPool({
        name: name.trim(),
        gameweek: gw,
        stakeCents: nairaOf(stake)! * 100,
        drawMethod,
        payout: payout.current,
        maxMembers: /^\d+$/.test(maxMembers) ? parseInt(maxMembers, 10) : null,
      });
      afterPoolAction();
      AppNotice.success(`${pool.name} was created and you are in it. Share its invite link with the managers you want in.`);
      // Closes with the new pool's id, so the pools page can open it.
      setBusy(false);
      close(pool.id);
    } catch (error) {
      setBusy(false);
      // Creating a pool pays for the creator's own entry.
      if (openTopUpIfInsufficientFunds(error)) return;
      AppNotice.error(error ?? 'The pool could not be created.');
    }
  };

  return (
    <FormDialog
      title="Create a private pool"
      subtitle="Only people you invite can see or join it."
      onClose={busy ? null : () => close()}
      maxWidth={680}
    >
      <GradientPanel>
        <Icon name="auto_awesome_rounded" color={s.dark ? AppColors.lime : s.positive} />
        <View style={{ height: 12 }} />
        <T v="headlineSmall" w={900}>
          Your pool, your people.
        </T>
        <View style={{ height: 6 }} />
        <T color={s.onSurfaceVariant}>
          {gameweek == null
            ? 'Loading the official FPL gameweek…'
            : `You get a link and a code to share once it is created. One pool per gameweek; this one is for Gameweek ${gameweek} and closes at the FPL deadline.`}
        </T>
      </GradientPanel>
      <View style={{ height: 24 }} />
      <TextField
        value={name}
        onChangeText={(v) => {
          setName(v);
          if (errors.name) setErrors((e) => ({ ...e, name: nameError(v) }));
        }}
        autoCapitalize="sentences"
        label="Pool name"
        hint={`e.g. Lagos Legends${gameweek == null ? '' : ` GW${gameweek}`}`}
        error={errors.name}
      />
      <View style={{ height: 20 }} />
      <T v="titleMedium">Stake per manager</T>
      <View style={{ height: 10 }} />
      <TextField
        value={stake}
        onChangeText={(v) => {
          setStake(v);
          if (errors.stake) setErrors((e) => ({ ...e, stake: stakeError(v) }));
        }}
        keyboardType="number-pad"
        label="Amount (₦)"
        hint="Minimum ₦1,000"
        prefixIcon="payments_outlined"
        error={errors.stake}
      />
      <View style={{ height: 16 }} />
      <TextField
        value={maxMembers}
        onChangeText={(v) => {
          setMaxMembers(v);
          setMaxTouched(true);
        }}
        keyboardType="number-pad"
        label="Maximum managers (optional)"
        hint="Unlimited"
        prefixIcon="groups_outlined"
        error={maxTouched ? maxError(maxMembers) : null}
      />
      <View style={{ height: 24 }} />
      <T v="titleMedium">If managers finish level</T>
      <View style={{ height: 6 }} />
      <T v="bodySmall" color={s.onSurfaceVariant}>
        Choose what happens when two or more managers finish on the same score.
      </T>
      <View style={{ height: 12 }} />
      <DrawMethodPicker value={drawMethod} onChange={setDrawMethod} disabled={busy} />
      <View style={{ height: 24 }} />
      <PayoutEditor
        initial={defaultPayoutChoice}
        rule={terms.winnerRule}
        maxMembers={maxMembers}
        enabled={!busy}
        onChanged={(c) => (payout.current = c)}
      />
      <View style={{ height: 20 }} />
      <DeleteFeeNote stake={stake} terms={terms} />
      <View style={{ height: 24 }} />
      <FilledButton
        label={gameweek == null ? 'Syncing gameweek…' : 'Create pool'}
        busy={busy}
        onPress={gameweek == null ? null : () => create(gameweek)}
      />
      <View style={{ height: 10 }} />
      <T v="labelSmall" center color={s.onSurfaceVariant}>
        You are the first manager in your pool: your stake is taken from your wallet when you create it. FPLboardman
        reviews new pools before anyone else can join, and we will tell you when yours is approved. You can edit it until
        another manager joins. If it is not approved before the deadline, or you delete it while you are the only one in
        it, your stake comes straight back.
      </T>
      <View style={{ height: 8 }} />
      <TextButton label="Cancel" onPress={busy ? null : () => close()} />
    </FormDialog>
  );
}

/**
 * Tells the creator, before they create the pool, what deleting it will cost
 * once other managers have joined. The amount follows the stake as typed.
 */
function DeleteFeeNote({ stake, terms }: { stake: string; terms: PoolTerms }) {
  const s = useScheme();
  const naira = nairaOf(stake);
  const percent = `${terms.deleteFeePercentLabel}%`;
  const example =
    naira == null || naira < 1000
      ? ''
      : ` That is ${money(terms.deleteFeeFor(naira * 100))} on a ${money(naira * 100)} entry.`;
  const free = terms.deleteFeeBasisPoints <= 0;
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'flex-start',
        padding: 14,
        borderRadius: 14,
        backgroundColor: alpha(AppColors.amber, 0.12),
        borderWidth: 1,
        borderColor: alpha(AppColors.amber, 0.35),
      }}
    >
      <Icon name="info_outline_rounded" size={20} color={AppColors.amber} />
      <View style={{ width: 10 }} />
      <View style={{ flex: 1 }}>
        <T w={800}>{free ? 'Deleting your pool' : 'Deleting after someone joins costs a fee'}</T>
        <View style={{ height: 4 }} />
        <T color={s.onSurfaceVariant} style={{ lineHeight: 19 }}>
          {free
            ? 'You can delete this pool until the gameweek deadline. Everyone who joined gets their money back.'
            : `You can delete this pool until the gameweek deadline. If another manager has joined, everyone gets their money back and you pay ${percent} of the entry fee.${example} Deleting before anyone else joins is free.`}
        </T>
      </View>
    </View>
  );
}
