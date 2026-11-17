import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

/**
 * Tokens: the Keychain / Keystore on phones. On the web there is no secure
 * enclave, so they live in localStorage, as flutter_secure_storage did on web.
 */
const secure = {
  async get(key: string): Promise<string | null> {
    if (Platform.OS === 'web') {
      try {
        return window.localStorage.getItem(key);
      } catch {
        return null;
      }
    }
    return SecureStore.getItemAsync(key);
  },
  async set(key: string, value: string) {
    if (Platform.OS === 'web') {
      try {
        window.localStorage.setItem(key, value);
      } catch {}
      return;
    }
    await SecureStore.setItemAsync(key, value);
  },
  async remove(key: string) {
    if (Platform.OS === 'web') {
      try {
        window.localStorage.removeItem(key);
      } catch {}
      return;
    }
    await SecureStore.deleteItemAsync(key);
  },
};

export type StoredTokens = { accessToken: string; refreshToken: string };

const ACCESS = 'access_token';
const REFRESH = 'refresh_token';

export const SessionStore = {
  async read(): Promise<StoredTokens | null> {
    const [access, refresh] = await Promise.all([secure.get(ACCESS), secure.get(REFRESH)]);
    if (access == null || refresh == null) return null;
    return { accessToken: access, refreshToken: refresh };
  },
  async write(tokens: StoredTokens) {
    await secure.set(ACCESS, tokens.accessToken);
    await secure.set(REFRESH, tokens.refreshToken);
  },
  async clear() {
    await Promise.all([secure.remove(ACCESS), secure.remove(REFRESH)]);
  },
};

/** Plain preferences (SharedPreferences in Flutter). */
export const Prefs = {
  get: (key: string) => AsyncStorage.getItem(key).catch(() => null),
  set: (key: string, value: string) => AsyncStorage.setItem(key, value).catch(() => undefined),
  remove: (key: string) => AsyncStorage.removeItem(key).catch(() => undefined),
};
