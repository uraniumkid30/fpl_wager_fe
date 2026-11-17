import React, { useState } from 'react';
import { View } from 'react-native';

import { errorMessage } from '@/core/errors';
import { Dashboard, FplManager, managerName } from '@/domain/models';
import { gateway } from '@/state/gateway';
import { invalidate, keys, queryClient } from '@/state/queries';
import { AppColors, alpha, useScheme } from '@/theme/theme';
import { FilledButton, TextButton } from '@/ui/Buttons';
import { FormDialog } from '@/ui/FormDialog';
import { Icon } from '@/ui/Icon';
import { TextField } from '@/ui/Inputs';
import { T } from '@/ui/Text';
import { AppNotice } from '@/ui/notice';
import { openDialog } from '@/ui/overlay';
import { GradientPanel, StatusPill } from '@/ui/widgets';

export type TeamProtectedAction = 'pool' | 'challenge';

/** Opens the "Link your FPL team" dialog (the /link-team route in Flutter). Resolves true once linked. */
export async function openLinkTeamDialog(reason?: TeamProtectedAction): Promise<boolean> {
  let busy = false;
  const result = await openDialog<boolean>(
    (close) => <LinkTeamDialog reason={reason} close={close} onBusy={(b) => (busy = b)} />,
    { dismissible: () => !busy, inset: { horizontal: 18, vertical: 24 } },
  );
  return result === true;
}

/** True when the user has a linked team; otherwise asks them to link one first. */
export async function requireLinkedFplTeam(action: TeamProtectedAction): Promise<boolean> {
  try {
    const cached = queryClient.getQueryData<Dashboard>(keys.dashboard);
    const dashboard = cached ?? (await queryClient.fetchQuery({ queryKey: keys.dashboard, queryFn: () => gateway.dashboard() }));
    if (dashboard?.team != null) return true;
  } catch {
    AppNotice.error('We could not check your FPL team. Please try again.');
    return false;
  }
  return openLinkTeamDialog(action);
}

const reasonText = (reason?: string) =>
  reason === 'pool'
    ? 'Link a verified team before creating a pool.'
    : reason === 'challenge'
      ? 'Link a verified team before creating a head-to-head.'
      : 'Connect the team you use in Fantasy Premier League.';

function LinkTeamDialog({
  reason,
  close,
  onBusy,
}: {
  reason?: string;
  close: (v?: boolean) => void;
  onBusy: (b: boolean) => void;
}) {
  const s = useScheme();
  const [teamId, setTeamId] = useState('');
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [manager, setManager] = useState<FplManager | null>(null);
  const [validatedId, setValidatedId] = useState<number | null>(null);
  const [loading, setLoadingState] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const setLoading = (b: boolean) => {
    setLoadingState(b);
    onBusy(b);
  };

  const validate = async () => {
    const id = /^\d+$/.test(teamId.trim()) ? parseInt(teamId.trim(), 10) : NaN;
    if (!(id >= 1)) {
      setFieldError('Enter the numeric ID from your FPL URL');
      return;
    }
    setFieldError(null);
    setLoading(true);
    setError(null);
    try {
      setManager(await gateway.validateTeam(id));
      setValidatedId(id);
    } catch (e) {
      setManager(null);
      setError(e);
    } finally {
      setLoading(false);
    }
  };

  const link = async () => {
    if (validatedId == null) return;
    setLoading(true);
    setError(null);
    try {
      await gateway.linkTeam(validatedId);
      await invalidate(keys.dashboard);
      close(true);
    } catch (e) {
      setError(e);
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setValidatedId(null);
    setManager(null);
    setError(null);
  };

  return (
    <FormDialog title="Link your FPL team" subtitle={reasonText(reason)} onClose={loading ? null : () => close(false)} maxWidth={640}>
      <GradientPanel colors={AppColors.heroPanel}>
        <Icon name="verified_rounded" color={AppColors.lime} size={34} />
        <View style={{ height: 14 }} />
        <T v="headlineSmall" w={900} color="#FFFFFF">
          One ID. Your real team.
        </T>
        <View style={{ height: 6 }} />
        <T color={AppColors.heroText} style={{ lineHeight: 20 }}>
          Preview the public manager profile before linking it. We never ask for your FPL password.
        </T>
      </GradientPanel>
      <View style={{ height: 20 }} />
      <TextField
        value={teamId}
        onChangeText={setTeamId}
        editable={manager == null && !loading}
        keyboardType="number-pad"
        autoFocus
        label="FPL Team ID"
        hint="e.g. 1234567"
        prefixIcon="tag_rounded"
        error={fieldError}
        onSubmitEditing={() => {
          if (!loading && manager == null) validate();
        }}
      />
      {error ? (
        <>
          <View style={{ height: 12 }} />
          <T color={s.error}>{errorMessage(error)}</T>
        </>
      ) : null}
      <View style={{ height: 16 }} />
      {manager == null ? (
        <FilledButton icon="search_rounded" label="Find team" busy={loading} onPress={validate} />
      ) : (
        <ManagerPreview manager={manager} busy={loading} onChange={reset} onConfirm={link} />
      )}
      <View style={{ height: 24 }} />
      <T v="titleMedium">Where to find it</T>
      <View style={{ height: 8 }} />
      <Step n="1" text="Open fantasy.premierleague.com and view your team." />
      <Step n="2" text="Copy the number after /entry/ in the page URL." />
      <Step n="3" text="Paste it above and confirm the profile is yours." />
      <View style={{ height: 12 }} />
      <TextButton label="Cancel" onPress={loading ? null : () => close(false)} />
    </FormDialog>
  );
}

function ManagerPreview({
  manager,
  busy,
  onChange,
  onConfirm,
}: {
  manager: FplManager;
  busy: boolean;
  onChange: () => void;
  onConfirm: () => void;
}) {
  const s = useScheme();
  return (
    <GradientPanel>
      <StatusPill label="Verified public profile" />
      <View style={{ height: 14 }} />
      <T v="titleLarge">{manager.teamName}</T>
      <T color={s.onSurfaceVariant}>{`${managerName(manager)} · Team ${manager.entryId}`}</T>
      <View style={{ height: 18 }} />
      <View style={{ flexDirection: 'row' }}>
        <Metric label="Overall points" value={String(manager.overallPoints)} />
        <Metric label="Overall rank" value={manager.overallRank == null ? '—' : `#${manager.overallRank}`} />
      </View>
      <View style={{ height: 18 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1 }}>
          <TextButton label="Use another ID" onPress={busy ? null : onChange} />
        </View>
        <View style={{ width: 10 }} />
        <View style={{ flex: 1 }}>
          <FilledButton label="Confirm and link" busy={busy} onPress={onConfirm} />
        </View>
      </View>
    </GradientPanel>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ flex: 1 }}>
      <T v="labelSmall">{label.toUpperCase()}</T>
      <View style={{ height: 4 }} />
      <T v="titleLarge" mono>
        {value}
      </T>
    </View>
  );
}

function Step({ n, text }: { n: string; text: string }) {
  const s = useScheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 7 }}>
      <View
        style={{
          width: 32,
          height: 32,
          borderRadius: 16,
          backgroundColor: alpha(s.primary, 0.14),
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <T w={900} color={s.primary}>
          {n}
        </T>
      </View>
      <View style={{ width: 12 }} />
      <T style={{ flex: 1 }}>{text}</T>
    </View>
  );
}
