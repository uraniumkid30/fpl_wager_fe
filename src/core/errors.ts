export type AppErrorKind = 'network' | 'validation' | 'authentication';

export class AppException extends Error {
  constructor(
    message: string,
    readonly kind: AppErrorKind,
    readonly code?: string,
  ) {
    super(message);
  }
  override toString() {
    return this.message;
  }
}

export const isAuthError = (e: unknown) => e instanceof AppException && e.kind === 'authentication';
export const errorCode = (e: unknown) => (e instanceof AppException ? e.code : undefined);

/** What to show a person for an error. */
export function errorMessage(e: unknown, fallback = 'Something went wrong.'): string {
  if (e instanceof Error && e.message) return e.message;
  if (typeof e === 'string' && e) return e;
  return fallback;
}
