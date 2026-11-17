import { QueryClient, useQuery } from '@tanstack/react-query';

import { gateway } from './gateway';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: false,
      staleTime: 0,
      refetchOnWindowFocus: false,
    },
  },
});

/** Query keys: one per Riverpod provider in the Flutter app. */
export const keys = {
  dashboard: ['dashboard'] as const,
  wallet: ['wallet'] as const,
  pools: ['pools', 'active'] as const,
  pastPools: ['pools', 'past'] as const,
  gameweekHistory: ['gameweekHistory'] as const,
  poolAll: ['pool'] as const,
  pool: (id: string) => ['pool', id] as const,
  inviteAll: ['poolInvite'] as const,
  invite: (code: string) => ['poolInvite', code] as const,
  poolTerms: ['poolTerms'] as const,
  challenges: ['challenges'] as const,
  notifications: ['notifications'] as const,
  withdrawals: ['withdrawals'] as const,
  banks: ['banks'] as const,
  bankAccount: ['bankAccount'] as const,
  webLinks: ['webLinks'] as const,
  payment: (ref: string) => ['payment', ref] as const,
  paymentOptions: ['paymentOptions'] as const,
  campaignsAll: ['campaigns'] as const,
  campaigns: (placement: 'home' | 'pools') => ['campaigns', placement] as const,
  campaign: (slug: string) => ['campaign', slug] as const,
};

type Key = readonly unknown[];
export const invalidate = (...ks: Key[]) =>
  Promise.all(ks.map((queryKey) => queryClient.invalidateQueries({ queryKey })));

export const useDashboard = () => useQuery({ queryKey: keys.dashboard, queryFn: () => gateway.dashboard() });
export const useWallet = () => useQuery({ queryKey: keys.wallet, queryFn: () => gateway.wallet() });
export const usePools = () =>
  useQuery({
    queryKey: keys.pools,
    queryFn: async () =>
      (await gateway.pools()).filter((p) => p.status !== 'settled' && p.status !== 'cancelled'),
  });
export const usePastPools = () => useQuery({ queryKey: keys.pastPools, queryFn: () => gateway.pools({ view: 'past' }) });
export const useGameweekHistory = () =>
  useQuery({ queryKey: keys.gameweekHistory, queryFn: () => gateway.gameweekHistory() });
export const usePool = (id: string) => useQuery({ queryKey: keys.pool(id), queryFn: () => gateway.pool(id) });
export const usePoolInvite = (code: string) =>
  useQuery({ queryKey: keys.invite(code), queryFn: () => gateway.poolByInvite(code) });
export const usePoolTerms = () => useQuery({ queryKey: keys.poolTerms, queryFn: () => gateway.poolTerms() });
export const useChallenges = () => useQuery({ queryKey: keys.challenges, queryFn: () => gateway.challenges() });
export const useNotifications = () => useQuery({ queryKey: keys.notifications, queryFn: () => gateway.notifications() });
export const useUnreadCount = () => {
  const q = useNotifications();
  return q.data?.filter((n) => n.readAt == null).length ?? 0;
};
export const useWithdrawals = () => useQuery({ queryKey: keys.withdrawals, queryFn: () => gateway.withdrawals() });
export const useBanks = () => useQuery({ queryKey: keys.banks, queryFn: () => gateway.banks(), staleTime: Infinity });
export const useBankAccount = () => useQuery({ queryKey: keys.bankAccount, queryFn: () => gateway.bankAccount() });
export const useWebLinks = () => useQuery({ queryKey: keys.webLinks, queryFn: () => gateway.webLinks() });

export const usePaymentOptions = () =>
  useQuery({ queryKey: keys.paymentOptions, queryFn: () => gateway.paymentOptions() });
/** Live campaigns for Home or Pools. Kept for a minute: they change rarely, and the server announces changes. */
export const useCampaigns = (placement: 'home' | 'pools') =>
  useQuery({ queryKey: keys.campaigns(placement), queryFn: () => gateway.campaigns(placement), staleTime: 60_000 });
export const useCampaign = (slug: string) =>
  useQuery({ queryKey: keys.campaign(slug), queryFn: () => gateway.campaign(slug) });

/** What every pool action (create, join, leave, join by invite) refreshes. */
export const afterPoolAction = () => invalidate(keys.pools, keys.gameweekHistory, keys.dashboard, keys.wallet);
