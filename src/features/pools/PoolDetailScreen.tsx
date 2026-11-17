import * as Clipboard from 'expo-clipboard';
import { router } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import { AppState, ScrollView, View, useWindowDimensions } from 'react-native';

import { AppConfig } from '@/core/config';
import { AppException, errorMessage } from '@/core/errors';
import { money } from '@/core/format';
import {
  PayoutChoice,
  PayoutRule,
  Pool,
  PoolDrawMethod,
  PoolManage,
  PoolTerms,
  Prize,
  awaitingAdminApproval,
  canJoin,
  defaultPayoutChoice,
  defaultShares,
  hasJoined,
  hasLeft,
  isLive,
  isPendingMember,
  isPrivate,
  manageFeeLabel,
  ordinalSuffix,
  percentLabel,
  prizePercentLabel,
} from '@/domain/pool';
import { requireLinkedFplTeam } from '@/features/team/linkTeam';
import { openTopUpIfInsufficientFunds } from '@/features/wallet/insufficientFunds';
import { gateway } from '@/state/gateway';
import { afterPoolAction, invalidate, keys, usePool, usePoolInvite, usePoolTerms } from '@/state/queries';
import { realtimeConnected } from '@/state/realtime';
import { AppColors, AppSpacing, alpha, useScheme } from '@/theme/theme';
import { FilledButton, IconButton, OutlinedButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { AppBar, Scaffold, goBack } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { AlertDialogView, confirm, openDialog } from '@/ui/overlay';
import { AsyncContent, DeadlineCountdown, Divider, FitText, GradientPanel, Loading, StatusPill } from '@/ui/widgets';
import { DrawMethodPicker } from './CreatePoolDialog';
import { PayoutEditor, payoutProblem } from './PayoutEditor';
import { PoolLeaderboard } from './PoolLeaderboard';

const ordinal = (place: number) => `${place}${ordinalSuffix(place)}`;

/** A close button for a page opened on its own (from a link); null keeps the back arrow. */
function leadingFor() {
  return router.canGoBack() ? undefined : (
    <IconButton icon="close_rounded" tooltip="Close" onPress={() => router.replace('/pools')} />
  );
}
const closePage = () => goBack('/pools');

/** Shows why joining failed. A balance that is too low opens Top up instead. */
function showActionError(error: unknown, fallback: string) {
  if (openTopUpIfInsufficientFunds(error)) return;
  AppNotice.error(error ?? fallback);
}

/** A pool opened from the app's own lists, by its id. */
export function PoolDetailScreen({ poolId }: { poolId: string }) {
  const pool = usePool(poolId);
  const [busy, setBusy] = useState(false);

  const join = async (item: Pool) => {
    if (!(await requireLinkedFplTeam('pool'))) return;
    setBusy(true);
    try {
      const joined = await gateway.joinPool(poolId);
      afterPoolAction();
      invalidate(keys.pool(poolId));
      AppNotice.success(`You joined ${joined.name}.`);
    } catch (error) {
      afterPoolAction();
      showActionError(error, 'The pool could not be joined.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Scaffold appBar={<AppBar title="Pool details" leading={leadingFor()} />}>
      <AsyncContent
        query={pool}
        // The page reloads itself while the gameweek is live; one failed reload keeps the table.
        keepDataOnError
        onRetry={() => invalidate(keys.pool(poolId))}
        data={(item) => (
          <Body item={item} busy={busy} onJoin={() => join(item)} onChanged={() => invalidate(keys.pool(poolId))} />
        )}
      />
    </Scaffold>
  );
}

/** A private pool opened from its invite link or code; joining sends the code along. */
export function JoinPoolScreen({ code }: { code: string }) {
  const pool = usePoolInvite(code);
  const [busy, setBusy] = useState(false);
  const item = pool.data;
  // The creator, or someone already in it, has nothing to join: open the pool itself.
  const openInstead = !!item && (item.isCreator || hasJoined(item) || isPendingMember(item));
  useEffect(() => {
    if (openInstead && item) router.replace(`/pools/${item.id}`);
  }, [openInstead, item]);

  const join = async () => {
    if (!(await requireLinkedFplTeam('pool'))) return;
    setBusy(true);
    try {
      const joined = await gateway.joinPoolByInvite(code);
      afterPoolAction();
      invalidate(keys.invite(code));
      AppNotice.success(`You joined ${joined.name}. Good luck!`);
    } catch (error) {
      afterPoolAction();
      showActionError(error, 'The pool could not be joined.');
    } finally {
      setBusy(false);
    }
  };

  let body: React.ReactNode;
  if (item && !openInstead) {
    body = <Body item={item} busy={busy} invited onJoin={join} onChanged={() => invalidate(keys.invite(code))} />;
  } else if (pool.isError && !item) {
    body = <InviteProblem error={pool.error} onRetry={() => invalidate(keys.invite(code))} />;
  } else {
    body = <Loading />;
  }
  return <Scaffold appBar={<AppBar title="Pool invite" leading={leadingFor()} />}>{body}</Scaffold>;
}

/** What to show when an invite link or code does not lead to a pool. */
function InviteProblem({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const s = useScheme();
  const code = error instanceof AppException ? error.code : undefined;
  const notFound = code === 'INVITE_NOT_FOUND' || code === 'NOT_FOUND';
  return (
    <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', padding: AppSpacing.xl }}>
      <Icon name={notFound ? 'link_off_rounded' : 'cloud_off_rounded'} size={48} color={s.error} />
      <View style={{ height: 16 }} />
      <T v="titleLarge" center>
        {notFound ? 'This invite does not work' : 'We could not open the invite'}
      </T>
      <View style={{ height: 8 }} />
      <T center color={s.onSurfaceVariant}>
        {notFound
          ? "The link or code may be mistyped, or the pool's creator has replaced it or deleted the pool. Ask them for the latest link."
          : errorMessage(error)}
      </T>
      <View style={{ height: 20 }} />
      {!notFound ? (
        <>
          <FilledButton tonal label="Try again" onPress={onRetry} />
          <View style={{ height: 8 }} />
        </>
      ) : null}
      <TextButton label="Back to pools" onPress={closePage} />
    </ScrollView>
  );
}

function Body({
  item,
  busy,
  onJoin,
  onChanged,
  invited = false,
}: {
  item: Pool;
  busy: boolean;
  onJoin: () => void;
  /** Called after the creator changes the pool, so the page reloads it. */
  onChanged: () => void;
  invited?: boolean;
}) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const manage = item.manage;
  const live = item.status === 'draft' || item.status === 'open';
  useLiveRefresh(isLive(item), onChanged);
  return (
    <ScrollView contentContainerStyle={{ paddingHorizontal: AppSpacing.md, paddingTop: 8, paddingBottom: 48 }}>
      <GradientPanel colors={AppColors.heroPanel}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <StatusPill
            label={awaitingAdminApproval(item) ? 'awaiting approval' : item.status}
            color={awaitingAdminApproval(item) ? AppColors.orange : AppColors.lime}
          />
          <View style={{ flex: 1 }} />
          <T w={800} color="#FFFFFF">{`GW${item.gameweek}`}</T>
        </View>
        <View style={{ height: 18 }} />
        <T v="headlineSmall" w={900} color="#FFFFFF">
          {item.name}
        </T>
        {isPrivate(item) ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 6 }}>
            <Icon name="lock_outline_rounded" size={15} color={AppColors.heroText} />
            <View style={{ width: 6 }} />
            <T color={AppColors.heroText} style={{ flex: 1 }}>
              {item.isCreator
                ? 'Private pool · created by you'
                : item.creatorName
                  ? `Private pool · by ${item.creatorName}`
                  : 'Private pool · invite only'}
            </T>
          </View>
        ) : null}
        <View style={{ height: 16 }} />
        <View style={{ flexDirection: 'row' }}>
          <HeroValue label="STAKE" value={money(item.stakeCents)} color={AppColors.lime} />
          <HeroValue label="PRIZE POOL" value={money(item.prizePoolCents)} color={AppColors.cyan} />
        </View>
        <View style={{ height: 16 }} />
        <T color={AppColors.heroText}>FPL deadline</T>
        <View style={{ height: 4 }} />
        <HeroCountdown deadline={item.deadline} />
      </GradientPanel>
      <View style={{ height: 16 }} />
      {invited && canJoin(item) && !item.isCreator ? (
        <>
          <T v="bodyMedium" center color={muted}>
            {item.creatorName ? `${item.creatorName} invited you to this pool.` : 'You have been invited to this pool.'}
          </T>
          <View style={{ height: 10 }} />
        </>
      ) : null}
      {canJoin(item) ? (
        <FilledButton
          label={hasLeft(item) ? `Rejoin · ${money(item.stakeCents)}` : `Join · ${money(item.stakeCents)}`}
          busy={busy}
          onPress={onJoin}
        />
      ) : isPendingMember(item) ? (
        <FilledButton label="Pending manager approval" />
      ) : hasJoined(item) && item.status === 'open' ? (
        // An entry is final: there is no way to leave from here.
        <FilledButton label="You have joined this pool" />
      ) : awaitingAdminApproval(item) ? (
        <FilledButton label={item.isCreator ? 'Waiting for FPLboardman to approve' : 'Not open yet · awaiting approval'} />
      ) : null}
      {item.isCreator && manage && live ? (
        <>
          <View style={{ height: 22 }} />
          <OwnerPanel pool={item} manage={manage} onChanged={onChanged} />
        </>
      ) : null}
      {item.rules ? (
        <>
          <View style={{ height: 22 }} />
          <T v="titleLarge">Pool rules</T>
          <View style={{ height: 10 }} />
          <GradientPanel>
            <T>{item.rules}</T>
          </GradientPanel>
        </>
      ) : null}
      {item.status === 'settled' ? (
        <>
          <View style={{ height: 22 }} />
          <FinalResult pool={item} />
        </>
      ) : null}
      <View style={{ height: 26 }} />
      <PoolLeaderboard pool={item} />
      {item.status !== 'cancelled' ? (
        <>
          <View style={{ height: 26 }} />
          <T v="titleLarge">Prizes</T>
          <View style={{ height: 4 }} />
          <T v="bodyMedium" color={muted}>
            {prizeSentence(item)}
          </T>
          {item.status !== 'settled' && item.prizeSplit.length > 0 ? (
            <>
              <View style={{ height: 12 }} />
              <GradientPanel>
                <PrizeLadder prizes={item.prizeSplit} />
                {item.status === 'open' || item.status === 'draft' ? (
                  <T v="bodySmall" color={muted} style={{ marginTop: 10 }}>
                    Prizes grow as more managers join.
                  </T>
                ) : null}
              </GradientPanel>
            </>
          ) : null}
        </>
      ) : null}
    </ScrollView>
  );
}

/** The hero panel is always dark, so its countdown is white whatever the theme. */
function HeroCountdown({ deadline }: { deadline: Date }) {
  return (
    <View>
      <DeadlineCountdownWhite deadline={deadline} />
    </View>
  );
}
function DeadlineCountdownWhite({ deadline }: { deadline: Date }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const total = Math.max(0, Math.floor((deadline.getTime() - now) / 1000));
  const d = Math.floor(total / 86400);
  const h = Math.floor(total / 3600) % 24;
  const m = Math.floor(total / 60) % 60;
  return (
    <T v="headlineMedium" w={900} color="#FFFFFF">
      {`${d}d ${h}h ${m}m`}
    </T>
  );
}

/**
 * Reloads a pool that is in play every so often, so its leaderboard stays
 * current even without the live connection: every 20 s without it, once a
 * minute with it in case an announcement was missed.
 */
function useLiveRefresh(active: boolean, onRefresh: () => void) {
  const ticks = useRef(0);
  const latest = useRef({ active, onRefresh });
  latest.current = { active, onRefresh };
  useEffect(() => {
    const timer = setInterval(() => {
      if (!latest.current.active) return;
      // Nothing to keep current while the app is in the background.
      if (AppState.currentState === 'background') return;
      ticks.current++;
      if (!realtimeConnected.get() || ticks.current % 3 === 0) latest.current.onRefresh();
    }, 20_000);
    return () => clearInterval(timer);
  }, []);
}

/** The one line that sums up who wins what. */
function prizeSentence(item: Pool): string {
  const plan = item.payout;
  const entrants = plan?.entrants ?? item.memberCount;
  if (item.status === 'cancelled') return 'This pool was cancelled and every entry was refunded.';
  if (item.status === 'settled') {
    const paid = item.leaderboard.filter((m) => m.payoutCents > 0);
    const total = paid.reduce((sum, m) => sum + m.payoutCents, 0);
    if (paid.length === 0) return 'This pool has been settled.';
    return paid.length === 1
      ? `1 of ${entrants} managers won ${money(total)}.`
      : `${paid.length} of ${entrants} managers shared ${money(total)}.`;
  }
  const rule = item.payoutRule;
  if (plan == null || entrants === 0) {
    if (rule == null) return 'One manager in ten wins. Prizes show once someone joins.';
    return rule.mode === 'winner_takes_all'
      ? 'Winner takes all. Prizes show once someone joins.'
      : `Top ${rule.winners} share the prize (${rule.shares.map(percentLabel).join(' · ')}). Prizes show once someone joins.`;
  }
  const prize = money(plan.totalWinningCents);
  let line =
    plan.mode === 'winner_takes_all'
      ? `Winner takes all: ${prize}.`
      : plan.winners <= 1
        ? `1 of ${entrants} wins ${prize}.`
        : `Top ${plan.winners} of ${entrants} share ${prize}.`;
  // A split whose chosen places cannot all be paid yet says when they will.
  if (rule != null && plan.mode === 'split' && plan.winners < rule.winners) {
    const needed = rule.limit.managersNeeded(rule.winners);
    line = `${line} All ${rule.winners} places are paid once ${needed} managers have joined.`;
  }
  // A split tie is the default and needs no words; the others do.
  if (item.drawMethod === 'captains') return `${line} Ties go to captain points.`;
  if (item.drawMethod === 'number') return `${line} Ties go to the number of goals.`;
  return line;
}

/** What each paid place wins; the first few, and the rest on request. */
function PrizeLadder({ prizes }: { prizes: Prize[] }) {
  const s = useScheme();
  const COLLAPSED = 5;
  const [showAll, setShowAll] = useState(false);
  const hidden = prizes.length - COLLAPSED;
  const shown = showAll || hidden <= 0 ? prizes : prizes.slice(0, COLLAPSED);
  return (
    <View>
      {shown.map((prize) => (
        <View key={prize.place} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 5 }}>
          <T v="titleSmall" w={900} color={prize.place === 1 ? s.primary : undefined} style={{ width: 46 }}>
            {ordinal(prize.place)}
          </T>
          <T v="bodySmall" color={s.onSurfaceVariant} style={{ flex: 1 }}>
            {`${prizePercentLabel(prize)}%`}
          </T>
          <T v="titleMedium" w={900} mono>
            {money(prize.amountCents)}
          </T>
        </View>
      ))}
      {hidden > 0 ? (
        <View style={{ alignItems: 'flex-start' }}>
          <TextButton
            style={{ paddingHorizontal: 0, minHeight: 32 }}
            label={showAll ? 'Show fewer' : `Show all ${prizes.length} prizes`}
            onPress={() => setShowAll(!showAll)}
          />
        </View>
      ) : null}
    </View>
  );
}

function HeroValue({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <View style={{ flex: 1, paddingRight: 8 }}>
      <T w={800} color={AppColors.heroText} style={{ fontSize: 11, lineHeight: 14 }}>
        {label}
      </T>
      <View style={{ height: 4 }} />
      <FitText v="headlineSmall" w={900} mono color={color}>
        {value}
      </FitText>
    </View>
  );
}

/** The creator's own tools: the invite to share, and editing or deleting the pool. */
function OwnerPanel({ pool, manage, onChanged }: { pool: Pool; manage: PoolManage; onChanged: () => void }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const [busy, setBusy] = useState(false);
  const code = pool.inviteCode ?? '';
  const link = AppConfig.poolInviteUrl(code);
  const others = manage.otherEntries;

  const copyInvite = async () => {
    await Clipboard.setStringAsync(
      `Join my FPLboardman pool "${pool.name}" for Gameweek ${pool.gameweek} (${money(pool.stakeCents)} to enter):\n${link}\nOr open the app, tap "Join with a code" and enter ${code}`,
    );
    AppNotice.success('Invite copied. Paste it to the people you want in.');
  };
  const copyCode = async () => {
    await Clipboard.setStringAsync(code);
    AppNotice.success('Code copied.');
  };
  const resetInvite = async () => {
    const ok = await confirm({
      title: 'Replace the invite?',
      message:
        'The current link and code stop working straight away. Managers who have already joined stay in. Use this if the invite has reached people you did not mean to invite.',
      cancelLabel: 'Keep it',
      confirmLabel: 'Replace',
    });
    if (!ok) return;
    setBusy(true);
    try {
      await gateway.resetPoolInvite(pool.id);
      onChanged();
      AppNotice.success('New invite ready. The old one no longer works.');
    } catch (e) {
      AppNotice.error(e);
    } finally {
      setBusy(false);
    }
  };
  const edit = async () => {
    const updated = await openEditPoolDialog(pool);
    // Closed without a pool when the edit was refused because someone joined: reload.
    onChanged();
    if (!updated) return;
    invalidate(keys.pools);
    AppNotice.success(`${updated.name} was updated.`);
  };
  const remove = async () => {
    let current = pool;
    let changed = false;
    // Asked again if the entries changed between showing the amounts and deleting.
    for (;;) {
      const m = current.manage;
      if (!m || !m.canDelete) {
        onChanged();
        AppNotice.info('This pool can no longer be deleted.');
        return;
      }
      const ok = await openDialog<boolean>((close) => <DeletePoolDialog pool={current} manage={m} changed={changed} close={close} />);
      if (ok !== true) {
        if (changed) onChanged();
        return;
      }
      setBusy(true);
      try {
        await gateway.deletePool(current.id, m.deleteFeeCents);
      } catch (error) {
        setBusy(false);
        if (error instanceof AppException && error.code === 'DELETE_FEE_CHANGED') {
          try {
            current = await gateway.pool(current.id);
          } catch (reloadError) {
            AppNotice.error(reloadError);
            return;
          }
          changed = true;
          continue;
        }
        onChanged();
        if (openTopUpIfInsufficientFunds(error)) return;
        AppNotice.error(error);
        return;
      }
      invalidate(keys.pools, keys.dashboard, keys.wallet);
      const refunded = m.entries;
      const fee = m.deleteFeeCents;
      AppNotice.success(
        refunded === 0
          ? `${current.name} was deleted.`
          : fee === 0
            ? `${current.name} was deleted and your stake was refunded.`
            : `${current.name} was deleted. ${refunded} ${refunded === 1 ? 'entry was' : 'entries were'} refunded and ${money(fee)} was taken from your wallet.`,
      );
      closePage();
      return;
    }
  };

  return (
    <View>
      <T v="titleLarge">Invite managers</T>
      <View style={{ height: 4 }} />
      <T v="bodyMedium" color={muted}>
        {awaitingAdminApproval(pool)
          ? 'You can share this now. People can join as soon as the pool is approved.'
          : 'Only people with this link or code can see and join your pool.'}
      </T>
      <View style={{ height: 12 }} />
      <GradientPanel>
        {code ? (
          <>
            <T v="labelSmall" color={muted} style={{ letterSpacing: 0.7 }}>
              INVITE CODE
            </T>
            <View style={{ height: 4 }} />
            <T v="headlineSmall" w={900} mono selectable style={{ letterSpacing: 3 }}>
              {code}
            </T>
            <View style={{ height: 12 }} />
            <View style={{ padding: 12, borderRadius: 12, backgroundColor: alpha(s.primary, 0.08) }}>
              <T v="bodySmall" selectable>
                {link}
              </T>
            </View>
            <View style={{ height: 14 }} />
            <View style={{ flexDirection: 'row' }}>
              <View style={{ flex: 1 }}>
                <FilledButton icon="link_rounded" label="Copy invite" onPress={busy ? null : copyInvite} />
              </View>
              <View style={{ width: 10 }} />
              <View style={{ flex: 1 }}>
                <OutlinedButton icon="copy_rounded" label="Copy code" onPress={busy ? null : copyCode} style={{ minHeight: 54 }} />
              </View>
            </View>
            <View style={{ height: 4, }} />
            <View style={{ alignItems: 'flex-start' }}>
              <TextButton icon="refresh_rounded" label="Replace with a new link" onPress={busy ? null : resetInvite} />
            </View>
          </>
        ) : (
          <T>The invite for this pool is not available.</T>
        )}
        <Divider style={{ marginVertical: 14 }} />
        <T v="bodySmall" color={muted} style={{ lineHeight: 16 }}>
          {manage.entries === 0
            ? 'Nobody has joined yet, so you can still edit or delete this pool.'
            : others === 0
              ? `You are the only manager in it so far. You can still edit it, or delete it at no cost and get your ${money(pool.stakeCents)} back.`
              : `${others} other ${others === 1 ? 'manager has' : 'managers have'} joined. The pool can no longer be edited. Deleting it refunds everyone and costs you ${money(manage.deleteFeeCents)} (${manageFeeLabel(manage)}% of the entry fee).`}
        </T>
        <View style={{ height: 12 }} />
        <View style={{ flexDirection: 'row' }}>
          {manage.canEdit ? (
            <>
              <View style={{ flex: 1 }}>
                <OutlinedButton icon="edit_outlined" label="Edit" onPress={busy ? null : edit} />
              </View>
              <View style={{ width: 10 }} />
            </>
          ) : null}
          {manage.canDelete ? (
            <View style={{ flex: 1 }}>
              <OutlinedButton
                icon="delete_outline_rounded"
                label="Delete pool"
                color={s.error}
                busy={busy}
                onPress={busy ? null : remove}
              />
            </View>
          ) : null}
        </View>
      </GradientPanel>
    </View>
  );
}

/** Spells out what deleting the pool does before the creator agrees. */
function DeletePoolDialog({
  pool,
  manage,
  changed,
  close,
}: {
  pool: Pool;
  manage: PoolManage;
  changed: boolean;
  close: (v?: boolean) => void;
}) {
  const s = useScheme();
  const others = manage.otherEntries;
  const fee = manage.deleteFeeCents;
  const points =
    manage.entries === 0
      ? ['Nobody has joined, so there is nothing to refund and no fee.', 'The invite link and code stop working.']
      : others === 0
        ? [
            `Your ${money(pool.stakeCents)} stake goes back to your wallet.`,
            'No fee, because nobody else has joined.',
            'The invite link and code stop working.',
          ]
        : [
            `All ${manage.entries} entries are refunded in full (${money(pool.stakeCents)} each), yours included.`,
            `A fee of ${manageFeeLabel(manage)}% of the ${money(pool.stakeCents)} entry fee — ${money(fee)} — is taken from your wallet.`,
            `${others} ${others === 1 ? 'manager is' : 'managers are'} told the pool was cancelled.`,
          ];
  return (
    <AlertDialogView
      title={`Delete ${pool.name}?`}
      content={
        <View>
          {changed ? (
            <View style={{ padding: 12, borderRadius: 12, backgroundColor: alpha(AppColors.orange, 0.14), marginBottom: 14 }}>
              <T>The entries changed while you were deciding. Please check the amounts again.</T>
            </View>
          ) : null}
          {points.map((p) => (
            <View key={p} style={{ flexDirection: 'row', alignItems: 'flex-start', marginBottom: 10 }}>
              <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: s.onSurfaceVariant, marginTop: 7, marginRight: 10 }} />
              <T style={{ flex: 1 }}>{p}</T>
            </View>
          ))}
          {fee > 0 ? (
            <View
              style={{
                marginTop: 4,
                padding: 14,
                borderRadius: 12,
                backgroundColor: alpha(s.error, 0.1),
                flexDirection: 'row',
                alignItems: 'center',
              }}
            >
              <T style={{ flex: 1 }}>You pay</T>
              <T v="titleLarge" w={900} mono color={s.error}>
                {money(fee)}
              </T>
            </View>
          ) : null}
          <T v="bodySmall" color={s.onSurfaceVariant} style={{ marginTop: 12 }}>
            This cannot be undone.
          </T>
        </View>
      }
      actions={
        <>
          <TextButton label="Keep pool" onPress={() => close(false)} />
          <FilledButton
            compact
            danger
            height={40}
            label={fee > 0 ? `Delete and pay ${money(fee)}` : 'Delete pool'}
            onPress={() => close(true)}
          />
        </>
      }
    />
  );
}

/** Edits the creator's own pool (only while nobody has joined). Resolves with the updated pool. */
function openEditPoolDialog(pool: Pool): Promise<Pool | undefined> {
  let saving = false;
  return openDialog<Pool>((close) => <EditPoolDialog pool={pool} close={close} onSaving={(b) => (saving = b)} />, {
    dismissible: () => !saving,
  });
}

const sameShares = (a: number[], b: number[]) => a.length === b.length && a.every((x, i) => x === b[i]);
const choiceOf = (rule: PayoutRule | null): PayoutChoice =>
  rule == null || rule.mode !== 'split'
    ? defaultPayoutChoice
    : {
        mode: 'split',
        winners: rule.winners,
        // Keep the pool's own shares only if they differ from the suggestion.
        shares: sameShares(rule.shares, defaultShares(rule.winners)) ? null : rule.shares,
      };

function EditPoolDialog({ pool, close, onSaving }: { pool: Pool; close: (p?: Pool) => void; onSaving: (b: boolean) => void }) {
  const s = useScheme();
  const { height } = useWindowDimensions();
  const terms = usePoolTerms().data ?? new PoolTerms();
  const [name, setName] = useState(pool.name);
  const [stake, setStake] = useState(String(Math.trunc(pool.stakeCents / 100)));
  const [maxMembers, setMaxMembers] = useState(pool.maxMembers?.toString() ?? '');
  const [drawMethod, setDrawMethod] = useState<PoolDrawMethod>(pool.drawMethod);
  const initialPayout = useRef(choiceOf(pool.payoutRule)).current;
  const payout = useRef<PayoutChoice>(initialPayout);
  const payoutChanged = useRef(false);
  const firstPayoutCall = useRef(true);
  const [errors, setErrors] = useState<Record<string, string | null>>({});
  const [saving, setSavingState] = useState(false);
  const setSaving = (b: boolean) => {
    setSavingState(b);
    onSaving(b);
  };

  const validate = () => {
    const length = name.trim().length;
    const amount = /^\d+$/.test(stake.replace(/,/g, '').trim()) ? parseInt(stake.replace(/,/g, '').trim(), 10) : null;
    const maxText = maxMembers.trim();
    const max = /^\d+$/.test(maxText) ? parseInt(maxText, 10) : null;
    const next = {
      name: length < 3 ? 'Use at least 3 characters' : length > 80 ? 'Use 80 characters or fewer' : null,
      stake: amount == null ? 'Enter a whole amount in naira' : amount < 1000 ? 'The minimum amount is ₦1,000' : null,
      max: maxText && (max == null || max < 2) ? 'Use 2 or more, or leave empty for no limit' : null,
    };
    setErrors(next);
    return !next.name && !next.stake && !next.max;
  };

  const save = async () => {
    if (!validate()) return;
    const max = /^\d+$/.test(maxMembers.trim()) ? parseInt(maxMembers.trim(), 10) : null;
    const problem = payoutProblem(payout.current, terms.winnerRule, max);
    if (problem) {
      AppNotice.error(problem);
      return;
    }
    setSaving(true);
    try {
      const updated = await gateway.updatePool(pool.id, {
        name: name.trim(),
        stakeCents: parseInt(stake.replace(/,/g, '').trim(), 10) * 100,
        drawMethod,
        maxMembers: max,
        payout: payoutChanged.current || pool.payoutRule == null ? payout.current : undefined,
      });
      setSaving(false);
      close(updated);
    } catch (error) {
      AppNotice.error(error);
      // Someone joined, or the deadline passed, while the form was open.
      const code = error instanceof AppException ? error.code : undefined;
      setSaving(false);
      if (code === 'POOL_HAS_ENTRIES' || code === 'POOL_CLOSED') close();
    }
  };

  return (
    <AlertDialogView
      title="Edit pool"
      content={
        <View style={{ width: '100%', maxWidth: 460, maxHeight: height * 0.55 }}>
          <ScrollView keyboardShouldPersistTaps="handled">
            <View style={{ height: 8 }} />
            <TextField value={name} onChangeText={setName} autoCapitalize="sentences" label="Pool name" error={errors.name} />
            <View style={{ height: 16 }} />
            <TextField
              value={stake}
              onChangeText={setStake}
              keyboardType="number-pad"
              label="Stake per manager (₦)"
              hint="Minimum ₦1,000"
              error={errors.stake}
            />
            <View style={{ height: 16 }} />
            <T v="labelLarge">If managers finish level</T>
            <View style={{ height: 8 }} />
            <DrawMethodPicker value={drawMethod} onChange={setDrawMethod} disabled={saving} />
            <View style={{ height: 16 }} />
            <TextField
              value={maxMembers}
              onChangeText={setMaxMembers}
              keyboardType="number-pad"
              label="Maximum managers (optional)"
              hint="No limit"
              error={errors.max}
            />
            <View style={{ height: 20 }} />
            <PayoutEditor
              initial={initialPayout}
              rule={terms.winnerRule}
              maxMembers={maxMembers}
              enabled={!saving}
              onChanged={(c) => {
                payout.current = c;
                // The editor reports its starting value once; only later calls are edits.
                if (firstPayoutCall.current) firstPayoutCall.current = false;
                else payoutChanged.current = true;
              }}
            />
          </ScrollView>
        </View>
      }
      actions={
        <>
          <TextButton label="Cancel" onPress={saving ? null : () => close()} />
          <FilledButton compact height={40} label="Save changes" busy={saving} onPress={save} />
        </>
      }
    />
  );
}

/** The headline of a settled pool: where the user finished and what they won, or who won. */
function FinalResult({ pool }: { pool: Pool }) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const me = pool.leaderboard.find((m) => m.isMe);
  const winners = pool.leaderboard.filter((m) => m.payoutCents > 0);
  const entrants = pool.leaderboard.filter((m) => m.status === 'active').length;
  let title: string;
  let detail: string;
  let won: boolean;
  if (me && me.rank > 0) {
    won = me.payoutCents > 0;
    title = `You finished ${ordinal(me.rank)} of ${entrants}`;
    detail = won
      ? `You won ${money(me.payoutCents)} with ${me.points} points. It is in your wallet.`
      : `${me.points} points. No prize this time.`;
  } else {
    won = false;
    title = 'Final result';
    detail =
      winners.length === 0
        ? 'Nobody was paid in this pool.'
        : `Won by ${winners
            .slice(0, 3)
            .map((m) => m.displayName)
            .join(', ')}${winners.length > 3 ? ` and ${winners.length - 3} more` : ''}.`;
  }
  const accent = won ? s.positive : muted;
  return (
    <GradientPanel>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View
          style={{
            width: 48,
            height: 48,
            borderRadius: 24,
            backgroundColor: alpha(accent, 0.16),
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={won ? 'emoji_events_rounded' : 'flag_rounded'} color={accent} />
        </View>
        <View style={{ width: 14 }} />
        <View style={{ flex: 1 }}>
          <T v="titleMedium" w={800}>
            {title}
          </T>
          <View style={{ height: 4 }} />
          <T v="bodySmall" color={muted}>
            {detail}
          </T>
        </View>
      </View>
    </GradientPanel>
  );
}
