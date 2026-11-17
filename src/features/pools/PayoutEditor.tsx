import React, { useEffect, useState } from 'react';
import { View } from 'react-native';

import {
  PayoutChoice,
  PayoutMode,
  WinnerRule,
  defaultShares,
  parsePercent,
  percentInput,
  percentLabel,
  placeLabel,
  sharesProblem,
} from '@/domain/payout';
import { alpha, useScheme } from '@/theme/theme';
import { IconButton, TextButton } from '@/ui/Buttons';
import { Icon } from '@/ui/Icon';
import { SegmentedButton, TextField } from '@/ui/Inputs';
import { T } from '@/ui/Text';
import { ProgressBar } from '@/ui/widgets';

/** What is wrong with a number of winners, or null. */
export function winnersProblem(winners: number | null, rule: WinnerRule, maxMembers: number | null): string | null {
  if (winners == null) return 'Enter how many managers win.';
  if (winners < 2) return 'A split needs at least 2 winners. For one, choose Winner takes all.';
  if (winners > rule.maxWinners) return `A pool can have at most ${rule.maxWinners} winners.`;
  if (maxMembers != null && maxMembers > 0 && winners > rule.cap(maxMembers)) {
    const allowed = rule.cap(maxMembers);
    return `With at most ${maxMembers} managers, at most ${allowed} can win (${rule.description}). Allow more managers or choose fewer winners.`;
  }
  return null;
}

/** What is wrong with a choice, or null if it can be submitted. */
export function payoutProblem(choice: PayoutChoice, rule: WinnerRule, maxMembers: number | null): string | null {
  if (choice.mode !== 'split') return null;
  return winnersProblem(choice.winners, rule, maxMembers) ?? (choice.shares == null ? null : sharesProblem(choice.shares));
}

const intOrNull = (t: string) => (/^\d+$/.test(t.trim()) ? parseInt(t.trim(), 10) : null);

/**
 * "How the prize is paid" on the create and edit pool forms. Winner takes
 * all, or a split between a number of winners, with the suggested shares
 * shown and changeable. Problems are shown as they happen.
 */
export function PayoutEditor({
  initial,
  rule,
  maxMembers,
  onChanged,
  enabled = true,
}: {
  initial: PayoutChoice;
  rule: WinnerRule;
  /** The form's "Maximum managers" text: the winners must be payable when the pool is full. */
  maxMembers: string;
  onChanged: (choice: PayoutChoice) => void;
  enabled?: boolean;
}) {
  const s = useScheme();
  const muted = s.onSurfaceVariant;
  const [mode, setMode] = useState<PayoutMode>(initial.mode);
  const [winnersText, setWinnersText] = useState(String(initial.winners < 2 ? 3 : initial.winners));
  const [custom, setCustom] = useState(initial.shares != null);
  const sharesFor = (winnersT: string, given?: number[] | null) => {
    const typed = intOrNull(winnersT) ?? 0;
    const count = typed < 0 ? 0 : Math.min(typed, rule.maxWinners);
    const values = given && given.length === count ? given : defaultShares(count);
    return values.map(percentInput);
  };
  const [shareTexts, setShareTexts] = useState<string[]>(() => sharesFor(winnersText, initial.shares));

  const winnerCount = intOrNull(winnersText);
  const max = (() => {
    const v = intOrNull(maxMembers);
    return v == null || v <= 0 ? null : v;
  })();
  const typedShares = shareTexts.map((t) => parsePercent(t) ?? 0);

  // Tell the form about every change.
  useEffect(() => {
    onChanged({
      mode,
      winners: winnerCount ?? 0,
      shares: mode === 'split' && custom ? typedShares : null,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, winnersText, custom, shareTexts]);

  const setWinners = (text: string) => {
    setWinnersText(text);
    setShareTexts(sharesFor(text));
  };
  const step = (by: number) => {
    let next = (winnerCount ?? 1) + by;
    if (next < 2) next = 2;
    if (next > rule.maxWinners) next = rule.maxWinners;
    setWinners(String(next));
  };

  const splitSettings = () => {
    const winnersError = winnersProblem(winnerCount, rule, max);
    const shares = custom ? typedShares : defaultShares(winnerCount ?? 0);
    const sharesError = custom && winnersError == null ? sharesProblem(shares) : null;
    const top = shares.reduce((best, x) => (x > best ? x : best), 1);
    return (
      <View style={{ padding: 14, borderRadius: 16, backgroundColor: alpha(s.primaryContainer, s.dark ? 0.3 : 0.6) }}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <T v="titleSmall" style={{ flex: 1 }}>
            Number of winners
          </T>
          <IconButton
            variant="tonal"
            icon="remove_rounded"
            tooltip="Fewer winners"
            onPress={enabled && (winnerCount ?? 0) > 2 ? () => step(-1) : null}
          />
          <View style={{ width: 64, marginHorizontal: 4 }}>
            <TextField
              dense
              value={winnersText}
              editable={enabled}
              textAlign="center"
              keyboardType="number-pad"
              allow={/\d/}
              maxLength={4}
              error={winnersError == null ? null : ' '}
              hideErrorText
              inputStyle={{ fontSize: 16, fontFamily: 'Outfit_800ExtraBold' }}
              onChangeText={setWinners}
            />
          </View>
          <IconButton
            variant="tonal"
            icon="add_rounded"
            tooltip="More winners"
            onPress={enabled && (winnerCount ?? 0) < rule.maxWinners ? () => step(1) : null}
          />
        </View>
        <View style={{ height: 8 }} />
        {winnersError != null ? (
          <Message text={winnersError} error />
        ) : (
          <Message
            text={`All ${winnerCount} places are paid once ${rule.managersNeeded(winnerCount!)} managers have joined (${rule.description}, up to ${rule.maxWinners}). With fewer, fewer places are paid and their shares grow to cover the whole prize.`}
          />
        )}
        {winnersError == null ? (
          <>
            <View style={{ height: 14 }} />
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <T v="titleSmall" style={{ flex: 1 }}>
                {custom ? 'Your shares' : 'Suggested shares'}
              </T>
              <TextButton
                icon={custom ? 'restart_alt_rounded' : 'tune_rounded'}
                label={custom ? 'Use suggested' : 'Change shares'}
                onPress={
                  enabled
                    ? () => {
                        const next = !custom;
                        setCustom(next);
                        if (!next) setShareTexts(sharesFor(winnersText));
                      }
                    : null
                }
              />
            </View>
            <View style={{ height: 4 }} />
            {custom ? (
              shareTexts.map((text, i) => (
                <View key={i} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 4 }}>
                  <T v="labelLarge" style={{ width: 44 }}>
                    {placeLabel(i + 1)}
                  </T>
                  <View style={{ width: 92 }}>
                    <TextField
                      dense
                      value={text}
                      editable={enabled}
                      keyboardType="decimal-pad"
                      allow={/[0-9.,]/}
                      maxLength={6}
                      textAlign="right"
                      suffixText="%"
                      onChangeText={(v) => setShareTexts((prev) => prev.map((p, j) => (j === i ? v : p)))}
                    />
                  </View>
                  <View style={{ width: 12 }} />
                  <View style={{ flex: 1 }}>
                    <ProgressBar value={shares[i] >= top ? 1 : shares[i] / top} />
                  </View>
                </View>
              ))
            ) : (
              <ShareBars shares={shares} />
            )}
            {custom ? (
              <>
                <View style={{ height: 8 }} />
                {sharesError == null ? <Message text="Adds up to 100%." ok /> : <Message text={sharesError} error />}
              </>
            ) : (
              <T v="bodySmall" color={muted} style={{ paddingTop: 6 }}>
                Optional: tap "Change shares" to set your own. Each place gets at least as much as the one below it.
              </T>
            )}
          </>
        ) : null}
      </View>
    );
  };

  return (
    <View>
      <T v="titleMedium">How the prize is paid</T>
      <View style={{ height: 10 }} />
      <SegmentedButton<PayoutMode>
        disabled={!enabled}
        segments={[
          { value: 'winner_takes_all', label: 'Winner takes all', icon: 'emoji_events_outlined' },
          { value: 'split', label: 'Split', icon: 'groups_outlined' },
        ]}
        selected={mode}
        onChange={setMode}
      />
      <View style={{ height: 10 }} />
      {mode === 'winner_takes_all' ? (
        <Note icon="emoji_events_outlined" text="1st place takes the whole prize pool. If managers tie for 1st, the draw rule above decides." />
      ) : (
        splitSettings()
      )}
    </View>
  );
}

/** Beyond this many places the rest are summed up in one line. */
const SHOWN = 8;

function ShareBars({ shares }: { shares: number[] }) {
  const s = useScheme();
  const top = shares.length === 0 ? 1 : shares[0];
  const hidden = shares.length - SHOWN;
  return (
    <View>
      {shares.slice(0, SHOWN).map((share, i) => (
        <View key={i} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 3 }}>
          <T v="labelLarge" style={{ width: 44 }}>
            {placeLabel(i + 1)}
          </T>
          <View style={{ flex: 1 }}>
            <ProgressBar value={share / top} />
          </View>
          <T w={700} mono style={{ width: 64, textAlign: 'right' }}>
            {percentLabel(share)}
          </T>
        </View>
      ))}
      {hidden > 0 ? (
        <T v="bodySmall" color={s.onSurfaceVariant} style={{ paddingTop: 4 }}>
          {`…and ${hidden} more places, ${percentLabel(shares.slice(SHOWN).reduce((a, b) => a + b, 0))} between them.`}
        </T>
      ) : null}
    </View>
  );
}

function Note({ icon, text }: { icon: string; text: string }) {
  const s = useScheme();
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'flex-start',
        padding: 14,
        borderRadius: 16,
        backgroundColor: alpha(s.primaryContainer, s.dark ? 0.3 : 0.6),
      }}
    >
      <Icon name={icon} size={20} />
      <View style={{ width: 10 }} />
      <T style={{ flex: 1 }}>{text}</T>
    </View>
  );
}

/** One line under a field: an error in red, a confirmation in green, or a hint. */
function Message({ text, error = false, ok = false }: { text: string; error?: boolean; ok?: boolean }) {
  const s = useScheme();
  const color = error ? s.error : ok ? s.success : s.onSurfaceVariant;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
      <View style={{ paddingTop: 1 }}>
        <Icon
          name={error ? 'error_outline_rounded' : ok ? 'check_circle_outline_rounded' : 'info_outline_rounded'}
          size={16}
          color={color}
        />
      </View>
      <View style={{ width: 6 }} />
      <T v="bodySmall" color={color} style={{ flex: 1, lineHeight: 16 }}>
        {text}
      </T>
    </View>
  );
}
