import { AuthSession } from '@/domain/models';
import { clearFplWebSession } from '@/features/auth/fplWebSession';
import { gateway } from './gateway';
import { queryClient } from './queries';
import { createStore } from './store';

export type AuthState = { loading: boolean; session: AuthSession | null; error: unknown };

/** The signed-in session (authControllerProvider in Flutter). */
export const authStore = createStore<AuthState>({ loading: true, session: null, error: null });

export const auth = {
  async restore() {
    authStore.set((s) => ({ ...s, loading: true }));
    try {
      const session = await gateway.restoreSession();
      authStore.set({ loading: false, session, error: null });
    } catch (error) {
      authStore.set({ loading: false, session: null, error });
    }
  },
  accept(session: AuthSession) {
    // Anything loaded while signed out (failed requests) belongs to no one.
    queryClient.clear();
    authStore.set({ loading: false, session, error: null });
  },
  async logout() {
    await gateway.logout();
    await clearFplWebSession();
    queryClient.clear();
    authStore.set({ loading: false, session: null, error: null });
  },
  /** "account" changed on the server: reload the profile quietly. */
  async refresh() {
    try {
      const session = await gateway.restoreSession();
      authStore.set({ loading: false, session, error: null });
    } catch {}
  },
};

export const useAuth = () => authStore.use();
