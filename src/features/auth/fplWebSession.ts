/**
 * Signing out of FPLboardman must also sign the FPL web view out, so the next
 * person on the phone does not continue as the last FPL account.
 *
 * The RN login web view runs with `incognito` storage (see FplLoginScreen):
 * nothing it holds outlives the screen, so there is nothing left to clear.
 * Kept as a function so sign-out reads the same as it did in Flutter.
 */
export async function clearFplWebSession() {}
