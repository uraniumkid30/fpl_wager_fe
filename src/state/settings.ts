import { AppSettings, ThemeMode, defaultSettings } from '@/domain/models';
import { Prefs } from '@/core/storage';
import { authStore } from './auth';
import { gateway } from './gateway';
import { createStore } from './store';

export const settingsStore = createStore<AppSettings>(defaultSettings);

const bool = (v: string | null, d: boolean) => (v == null ? d : v === 'true');

export const settings = {
  async load() {
    const [theme, push, pool, challenge, marketing] = await Promise.all(
      ['theme_mode', 'push_notifications', 'pool_notifications', 'challenge_notifications', 'marketing_notifications'].map(
        Prefs.get,
      ),
    );
    settingsStore.set({
      themeMode: (theme === 'light' || theme === 'dark' ? theme : 'system') as ThemeMode,
      pushNotifications: bool(push, true),
      poolNotifications: bool(pool, true),
      challengeNotifications: bool(challenge, true),
      marketingNotifications: bool(marketing, false),
    });
  },
  async save(next: AppSettings) {
    const previous = settingsStore.get();
    settingsStore.set(next);
    await persist(next);
    if (authStore.get().session) {
      try {
        settingsStore.set(await gateway.updateSettings(next));
      } catch {
        settingsStore.set(previous);
        await persist(previous);
      }
    }
  },
};

async function persist(v: AppSettings) {
  await Promise.all([
    Prefs.set('theme_mode', v.themeMode),
    Prefs.set('push_notifications', String(v.pushNotifications)),
    Prefs.set('pool_notifications', String(v.poolNotifications)),
    Prefs.set('challenge_notifications', String(v.challengeNotifications)),
    Prefs.set('marketing_notifications', String(v.marketingNotifications)),
  ]);
}

export const useSettings = () => settingsStore.use();
