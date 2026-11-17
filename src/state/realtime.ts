import { useEffect } from 'react';
import { AppState, AppStateStatus } from 'react-native';

import { apiClient } from '@/core/api';
import { AppConfig } from '@/core/config';
import { auth, useAuth } from './auth';
import { gateway } from './gateway';
import { invalidate, keys, queryClient } from './queries';
import { createStore } from './store';

/** Whether the realtime connection is open (the wallet poll slows down when it is). */
export const realtimeConnected = createStore(false);

function onResources(resources: Set<string>, resourceId: string | null) {
  if (resources.has('dashboard')) invalidate(keys.dashboard);
  if (resources.has('wallet') || resources.has('history')) invalidate(keys.wallet);
  if (resources.has('pools')) {
    // A pool settling moves it to the past pools and completes the gameweek in the history.
    invalidate(keys.pools, keys.pastPools, keys.gameweekHistory);
    if (resourceId) invalidate(keys.pool(resourceId));
    // A change to every pool, such as the delete fee.
    else invalidate(keys.poolAll, keys.poolTerms);
  }
  // A pool's leaderboard moved: only pages showing that pool reload.
  if (resources.has('pool_standings')) {
    if (resourceId) invalidate(keys.pool(resourceId));
    invalidate(keys.inviteAll, keys.gameweekHistory);
  }
  if (resources.has('challenges')) invalidate(keys.challenges);
  if (resources.has('account')) auth.refresh();
  if (resources.has('notifications')) invalidate(keys.notifications);
  if (resources.has('withdrawals')) invalidate(keys.withdrawals);
  if (resources.has('web_links')) invalidate(keys.webLinks);
  if (resources.has('bank_account')) invalidate(keys.bankAccount);
  // An administrator changed a campaign or the top-up provider.
  if (resources.has('campaigns')) {
    invalidate(keys.campaignsAll);
    if (resourceId) invalidate(keys.campaign(resourceId));
  }
  if (resources.has('payment_options')) invalidate(keys.paymentOptions);
}

function catchUp() {
  invalidate(
    keys.dashboard,
    keys.wallet,
    keys.pools,
    keys.pastPools,
    keys.gameweekHistory,
    keys.poolAll,
    keys.challenges,
    keys.notifications,
    keys.withdrawals,
    keys.campaignsAll,
    keys.paymentOptions,
  );
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Opens a WebSocket that resolves once open, or rejects (10 s timeout). */
function connect(url: string): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    let socket: WebSocket;
    try {
      socket = new WebSocket(url);
    } catch (e) {
      reject(e);
      return;
    }
    const timer = setTimeout(() => {
      socket.close();
      reject(new Error('The realtime connection timed out.'));
    }, 10_000);
    socket.onopen = () => {
      clearTimeout(timer);
      socket.onopen = null;
      socket.onerror = null;
      resolve(socket);
    };
    socket.onerror = () => {
      clearTimeout(timer);
      socket.onopen = null;
      socket.onerror = null;
      reject(new Error('The realtime connection failed.'));
    };
  });
}

/** Server pushes: each event names the resources that changed; those queries reload. */
class RealtimeSync {
  private disposed = false;
  private socket: WebSocket | null = null;
  private attempt = 0;
  private connectedBefore = false;

  start() {
    this.loop();
  }

  dispose() {
    this.disposed = true;
    this.socket?.close(1000, 'signed out');
    realtimeConnected.set(false);
  }

  private async loop() {
    while (!this.disposed) {
      try {
        const ticket = await apiClient.createRealtimeTicket();
        if (this.disposed) return;
        const socket = await connect(apiClient.realtimeUrl(ticket));
        if (this.disposed) {
          socket.close();
          return;
        }
        this.socket = socket;
        this.attempt = 0;
        realtimeConnected.set(true);
        if (this.connectedBefore) catchUp();
        this.connectedBefore = true;
        await new Promise<void>((done) => {
          socket.onmessage = (event) => this.handle(event.data);
          socket.onerror = () => done();
          socket.onclose = () => done();
        });
      } catch {
        // Network transitions are expected; the next try gets a fresh ticket.
      } finally {
        this.socket = null;
        realtimeConnected.set(false);
      }
      if (this.disposed) return;
      const exponent = Math.min(this.attempt++, 5);
      await sleep(Math.min(1000 * 2 ** exponent + Math.floor(Math.random() * 500), 30_000));
    }
  }

  private handle(data: unknown) {
    if (typeof data !== 'string') return;
    try {
      const event = JSON.parse(data);
      if (!event || typeof event !== 'object' || !Array.isArray(event.resources)) return;
      onResources(
        new Set(event.resources.filter((r: unknown) => typeof r === 'string')),
        typeof event.resource_id === 'string' ? event.resource_id : null,
      );
    } catch {
      // Ignore malformed messages; the next valid one is enough.
    }
  }
}

/** Keeps the realtime connection open while signed in. */
export function useRealtimeSync() {
  const { session } = useAuth();
  const signedIn = session != null;
  useEffect(() => {
    if (!signedIn || AppConfig.useDemoData) return;
    const sync = new RealtimeSync();
    sync.start();
    return () => sync.dispose();
  }, [signedIn]);
}

const WHEN_LIVE = 60_000;
const WHEN_OFFLINE = 10_000;

/**
 * Keeps the wallet balance in the header current: checks the balance-only
 * endpoint every 10 s without a live connection (60 s with one) and when the
 * app comes back to the foreground; reloads the wallet if it changed.
 */
export function useWalletLive() {
  const { session } = useAuth();
  const signedIn = session != null;
  useEffect(() => {
    if (!signedIn || AppConfig.useDemoData) return;
    let disposed = false;
    let checking = false;
    let lastCheck = Date.now();
    let foreground = AppState.currentState !== 'background';

    const check = async () => {
      if (checking || disposed) return;
      checking = true;
      try {
        const latest = await gateway.walletBalance();
        if (disposed) return;
        const state = queryClient.getQueryState(keys.wallet);
        const shown = queryClient.getQueryData<{ availableCents: number; lockedCents: number }>(keys.wallet);
        const changed = shown
          ? shown.availableCents !== latest.availableCents || shown.lockedCents !== latest.lockedCents
          : state?.status === 'error';
        if (changed) invalidate(keys.wallet, keys.dashboard);
      } catch {
        // Offline or busy. The next check will do.
      } finally {
        checking = false;
        lastCheck = Date.now();
      }
    };

    const sub = AppState.addEventListener('change', (s: AppStateStatus) => {
      const now = s === 'active' || s === 'inactive';
      if (now && !foreground) check();
      foreground = now;
    });
    const timer = setInterval(() => {
      if (!foreground || disposed) return;
      const due = realtimeConnected.get() ? WHEN_LIVE : WHEN_OFFLINE;
      if (Date.now() - lastCheck >= due) check();
    }, 5000);
    return () => {
      disposed = true;
      clearInterval(timer);
      sub.remove();
    };
  }, [signedIn]);
}
