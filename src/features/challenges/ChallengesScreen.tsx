import React, { useState } from 'react';
import { View } from 'react-native';

import { errorMessage } from '@/core/errors';
import { money } from '@/core/format';
import { Challenge, challengeStatusLabel } from '@/domain/models';
import { requireLinkedFplTeam } from '@/features/team/linkTeam';
import { openTopUpIfInsufficientFunds } from '@/features/wallet/insufficientFunds';
import { gateway } from '@/state/gateway';
import { invalidate, keys, useChallenges, useDashboard } from '@/state/queries';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { ExtendedFab, FilledButton, IconButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { AppHeader, RefreshScroll, Scaffold, goBack } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { EmptyState, FadeSlideIn, GradientPanel, Loading, StatusPill } from '@/ui/widgets';

/** The smallest stake the server accepts for a head-to-head: ₦100. */
const MINIMUM_STAKE_NAIRA = 100;
const parseNaira = (text: string) => {
  const t = text.replace(/,/g, '').replace(/₦/g, '').trim();
  return /^-?\d+$/.test(t) ? parseInt(t, 10) : null;
};

export default function ChallengesScreen() {
  const s = useScheme();
  const challenges = useChallenges();
  const gameweek = useDashboard().data?.currentGameweek ?? null;
  const [composerOpen, setComposerOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [opponent, setOpponent] = useState('');
  const [amount, setAmount] = useState('');
  const [errors, setErrors] = useState<{ opponent?: string | null; amount?: string | null }>({});
  const [amountTouched, setAmountTouched] = useState(false);

  const amountError = (v: string) => {
    const naira = parseNaira(v);
    if (naira == null) return 'Enter a whole amount in naira';
    if (naira < MINIMUM_STAKE_NAIRA) return `The minimum stake is ₦${MINIMUM_STAKE_NAIRA}`;
    return null;
  };

  const beginCreate = async () => {
    if (await requireLinkedFplTeam('challenge')) setComposerOpen(true);
  };

  const submit = async () => {
    const next = {
      opponent: /^\d+$/.test(opponent.trim()) ? null : 'Enter a valid numeric team ID',
      amount: amountError(amount),
    };
    setErrors(next);
    setAmountTouched(true);
    if (next.opponent || next.amount) return;
    if (!(await requireLinkedFplTeam('challenge'))) return;
    if (gameweek == null) {
      AppNotice.info('The current FPL gameweek is still syncing.');
      return;
    }
    setBusy(true);
    try {
      await gateway.createChallenge({
        opponentTeamId: parseInt(opponent.trim(), 10),
        gameweek,
        stakeCents: parseNaira(amount)! * 100,
      });
      invalidate(keys.challenges, keys.wallet, keys.dashboard);
      setOpponent('');
      setAmount('');
      setAmountTouched(false);
      setComposerOpen(false);
      AppNotice.success('Head-to-head challenge created.');
    } catch (error) {
      if (openTopUpIfInsufficientFunds(error)) return;
      AppNotice.error(error ?? 'The challenge could not be created.');
    } finally {
      setBusy(false);
    }
  };

  const naira = parseNaira(amount);
  const sendLabel =
    gameweek == null
      ? 'Syncing gameweek…'
      : naira == null || naira < MINIMUM_STAKE_NAIRA
        ? 'Send challenge'
        : `Send challenge · ${money(naira * 100)}`;

  return (
    <Scaffold
      appBar={
        <AppHeader
          title="Head to head"
          back
          onBack={() => goBack('/pools')}
          actions={
            <>
              <IconButton
                variant="tonal"
                tooltip={composerOpen ? 'Close challenge form' : 'Create challenge'}
                icon={composerOpen ? 'close_rounded' : 'add_rounded'}
                onPress={busy ? null : composerOpen ? () => setComposerOpen(false) : beginCreate}
              />
              <View style={{ width: 8 }} />
            </>
          }
        />
      }
      fab={composerOpen ? null : <ExtendedFab icon="add_rounded" label="New challenge" onPress={beginCreate} />}
    >
      <RefreshScroll
        onRefresh={async () => {
          invalidate(keys.dashboard);
          await invalidate(keys.challenges);
        }}
        contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 120 }}
      >
        <T color={s.onSurfaceVariant}>Challenge any verified FPL manager. Winner takes the pot.</T>
        <View style={{ height: 18 }} />
        {composerOpen ? (
          <FadeSlideIn key="composer">
            <GradientPanel>
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Icon name="compare_arrows_rounded" color={s.secondary} />
                <View style={{ width: 10 }} />
                <T v="titleLarge" style={{ flex: 1 }}>
                  {gameweek == null ? 'New challenge' : `New Gameweek ${gameweek} challenge`}
                </T>
                <IconButton icon="close_rounded" tooltip="Cancel" onPress={busy ? null : () => setComposerOpen(false)} />
              </View>
              <View style={{ height: 18 }} />
              <TextField
                value={opponent}
                onChangeText={setOpponent}
                keyboardType="number-pad"
                label="Opponent FPL Team ID"
                prefixIcon="tag_rounded"
                error={errors.opponent}
              />
              <View style={{ height: 16 }} />
              <TextField
                value={amount}
                onChangeText={(v) => {
                  setAmount(v);
                  setAmountTouched(true);
                }}
                keyboardType="number-pad"
                label="Stake (₦)"
                hint="How much each of you puts in"
                helper="Whole naira, at least ₦100"
                prefixIcon="payments_outlined"
                error={amountTouched || errors.amount ? amountError(amount) : null}
                onSubmitEditing={() => {
                  if (!busy && gameweek != null) submit();
                }}
              />
              <View style={{ height: 18 }} />
              {/* The button shows the amount as it is typed. */}
              <FilledButton label={sendLabel} busy={busy} onPress={gameweek == null ? null : submit} />
            </GradientPanel>
          </FadeSlideIn>
        ) : (
          <FadeSlideIn key="cta">
            <GradientPanel colors={AppColors.heroPanel}>
              <Icon name="compare_arrows_rounded" color={AppColors.lime} size={34} />
              <View style={{ height: 14 }} />
              <T v="titleLarge" color="#FFFFFF">
                Ready for a one-on-one?
              </T>
              <View style={{ height: 6 }} />
              <T color={AppColors.heroText}>Create a challenge against another verified FPL manager.</T>
              <View style={{ height: 18 }} />
              <FilledButton icon="add_rounded" label="Create head-to-head" onPress={beginCreate} />
            </GradientPanel>
          </FadeSlideIn>
        )}
        <View style={{ height: 26 }} />
        <T v="titleLarge">Your head-to-heads</T>
        <View style={{ height: 10 }} />
        {challenges.data ? (
          challenges.data.length === 0 ? (
            <EmptyState icon="compare_arrows_rounded" title="No challenges yet" message="Pick a rival and make this gameweek personal." />
          ) : (
            challenges.data.map((item) => (
              <View key={item.id} style={{ marginBottom: 12 }}>
                <ChallengeCard item={item} />
              </View>
            ))
          )
        ) : challenges.isError ? (
          <T>{errorMessage(challenges.error)}</T>
        ) : (
          <Loading style={{ flex: 0 }} />
        )}
      </RefreshScroll>
    </Scaffold>
  );
}

function ChallengeCard({ item }: { item: Challenge }) {
  const s = useScheme();
  return (
    <GradientPanel>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ padding: 12, borderRadius: 15, backgroundColor: alpha(s.secondary, 0.14) }}>
          <Icon name="compare_arrows_rounded" color={s.secondary} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleMedium">{item.opponentName}</T>
          <T v="bodySmall" color={s.onSurfaceVariant}>{`GW${item.gameweek} · Team ${item.opponentTeamId}`}</T>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <T v="titleMedium" w={900} mono>
            {money(item.stakeCents)}
          </T>
          <View style={{ height: 5 }} />
          <StatusPill label={challengeStatusLabel(item.status)} />
        </View>
      </View>
    </GradientPanel>
  );
}
