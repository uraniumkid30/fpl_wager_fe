import { useSyncExternalStore } from 'react';

/** A tiny observable value, for app-wide state that is not server data. */
export function createStore<T>(initial: T) {
  let value = initial;
  const listeners = new Set<() => void>();
  return {
    get: () => value,
    set(next: T | ((prev: T) => T)) {
      value = typeof next === 'function' ? (next as (p: T) => T)(value) : next;
      listeners.forEach((l) => l());
    },
    subscribe(listener: () => void) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    use(): T {
      return useSyncExternalStore(this.subscribe, this.get, this.get);
    },
  };
}
