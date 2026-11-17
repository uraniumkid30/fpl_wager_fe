# FPL Boardman — React Native (Android, iOS, web)

This is the main FPLboardman app (`fplboardman`, previously Flutter) rebuilt in
React Native with Expo. One codebase builds the Android app, the iOS app and the
website. The screens, layout, copy and behaviour follow the Flutter app.
The logo, colours and type now come from the *Brand Identity Guidelines v1.0* PDF.

## Stack

| Concern | Flutter | React Native |
|---|---|---|
| Framework | Flutter 3 | Expo SDK 58 · React Native 0.88 · React 19.3 · TypeScript |
| Routing | go_router | expo-router (file routes in `src/app/`) |
| State and data | Riverpod `FutureProvider` and `invalidate` | TanStack Query (`src/state/queries.ts`); same keys and invalidation map |
| HTTP | dio | `fetch` (`src/core/api.ts`): same timeouts, 401 → refresh once → retry, same error mapping |
| Token storage | flutter_secure_storage | expo-secure-store (Keychain/Keystore); localStorage on web |
| Settings | shared_preferences | AsyncStorage |
| FPL login | webview_flutter | react-native-webview (incognito) |
| GlobalPay/Paystack checkout | webview_flutter | react-native-webview (full-screen page) |
| QR code (web sign-in) | qr_flutter | react-native-qrcode-svg |
| QR scanner | mobile_scanner | expo-camera |
| Realtime | WebSocket + ticket | WebSocket + ticket (`src/state/realtime.ts`), same back-off |

## Run it

```bash
npm ci
cp .env.example .env.local        # set EXPO_PUBLIC_API_BASE_URL if not production
npx expo start                    # press a (Android), i (iOS) or w (web)
```

Demo mode needs no server: set `EXPO_PUBLIC_USE_DEMO_DATA=true`, then sign in
with any email and the code `123456`.

Checks:

```bash
npm run typecheck                                          # tsc --noEmit
npx expo export --platform web --output-dir dist           # website build
npx expo export --platform android --platform ios          # native JS bundles (Hermes)
```

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `EXPO_PUBLIC_API_BASE_URL` | `https://api.fplboardman.com` | The API. Replaces `--dart-define=API_BASE_URL`. |
| `EXPO_PUBLIC_USE_DEMO_DATA` | `false` | In-memory demo data. |
| `EXPO_PUBLIC_ENABLE_DEV_CREDIT` | `false` | Shows "Add development credit" (test servers only). |
| `EXPO_PUBLIC_PAYMENT_CALLBACK_URL` | (computed) | Overrides where the provider returns after checkout. |

`EXPO_PUBLIC_*` values are compiled into the app. Never put secrets in them.

## Android and iOS builds (EAS)

```bash
npm i -g eas-cli && eas login
eas build:configure                  # first time only: links the project
eas build -p android --profile preview      # installable APK for testing
eas build -p android --profile production   # AAB for Play Store
eas build -p ios --profile production       # needs an Apple Developer account
eas submit -p android|ios
```

- Bundle id and package: `com.fplboardman.app`. Change them in `app.json` before the first store upload if you use a different id.
- Deep-link scheme: `fplboardman://`. `fplboardman:///join/CODE` opens a pool invite and `fplboardman:///link/CODE` opens a browser approval, as in Flutter.
- Camera permission text is set in `app.json` (`expo-camera` plugin and `NSCameraUsageDescription`).
- App icon, adaptive icon and splash are generated from the logo in the PDF (`assets/`).

## Website on Vercel

`vercel.json` replaces `vercel_build.sh`: it runs `npx expo export --platform web`
into `dist/` and rewrites every path to `index.html`. Set `EXPO_PUBLIC_API_BASE_URL`
in the Vercel project's environment variables.

Changes from the Flutter website:

- Addresses are now real paths: `/join/CODE` instead of `/#/join/CODE`. Old `/#/…`
  links still work: `index.js` moves them onto the path before the router starts.
- The payment callback on the web is now `https://<site>/payments/callback`, and
  cancel goes to `/wallet/top-up`. If the API keeps an allow-list of callback URLs,
  add these two addresses.
- The API's CORS allow-list must still include the website's origin.

## Brand: logo and colours

The logo artwork is taken directly from the PDF (`assets/brand/`): the icon, plus
the "FPL / Boardman" wordmark in purple for light backgrounds and white for dark
ones. It is not redrawn or recoloured. `BrandMark` in `src/ui/widgets.tsx`
replaces the old trophy-in-a-green-square mark everywhere it was used.

Every colour is in `src/theme/theme.ts`:

| Role | Flutter colour | Now |
|---|---|---|
| Dark page background | `#031C17` | Midnight `#1A0B28` |
| Ink and text (light) | `#06201B` | Midnight `#1A0B28` |
| Forest panels and hero cards | `#0B3A30`, `#0B4939 → #271747` | Boardroom Purple `#3D195B` → Midnight |
| Accent (lime) | `#72F75C` | Pitch Green `#00FF85` |
| Filled buttons | lime / green with dark text | Pitch Green with Boardroom Purple text (as in the guide's mock-ups) |
| Prize pool and secondary | Purple `#B43CFF` | Captain Cyan `#04F5FF` (dark), `#00838A` (light, for contrast) |
| Countdown timer | `#49D7F2` | Captain Cyan |
| Errors and money out | `#FF5D68` | Red Card Pink `#E90052` (`#FF4F8E` on dark, for contrast) |
| Money in (light theme) | `#119D58` | `#007F44` (Pitch Green darkened, for contrast on white) |
| Light page background | `#F3F7F2` | `#F4F2F7` (the guide's page tone) |

Kept as before (not brand colours): amber for the delete-fee warning, orange for
"pending" and "in play", and gold/silver/bronze leaderboard medals.

Type follows the guide: Outfit for all text and JetBrains Mono for money and figures.

## Project layout

```
index.js                 entry: old /#/ links → paths, then expo-router
src/app/                 routes (one file per page; mirrors app_router.dart)
src/features/…           screens, ported one-to-one from lib/features/…
src/ui/                  shared widgets (GradientPanel, StatusPill, buttons, fields,
                         dialogs/sheets, notices, header, wallet icon, countdown)
src/state/               gateway instance, queries and keys, auth, settings, realtime
src/core/                config, API client, gateway (remote + demo), storage, format
src/domain/              models and rules (payout rules mirror the server)
src/theme/theme.ts       brand palette, light/dark schemes, type scale
```

## Top-ups and campaigns

- **Top-ups** go through the provider an administrator picks in the admin app
  (Zenith GlobalPay by default, Paystack the other option). The Top up page no
  longer has a provider switch: it shows "Secure payment by …" from
  `GET /v1/payments/options`, and updates live when an admin switches. Against an
  older API without that endpoint it falls back to Paystack as before.
  On the web the payment reference is kept in session storage during the
  redirect, so the return page finds it even if a provider drops it from the URL.
- **Campaigns** (`src/features/campaigns/`): the marketing slot at the top of Home
  (under the greeting) and Pools (top of Active). One live campaign shows as a
  banner; several become a swipeable row with dots. Tapping opens
  `/campaigns/<slug>` with the hero, countdown, body and numbered rules. Content,
  theme (`rumble`, `pitch`, `cyan`, `gold`, `midnight`), placements and the button
  come from the admin's Campaigns page; nothing is hard-coded except the theme
  colours. No live campaign means no slot.

## Security notes (unchanged behaviour)

- FPL login sends only the refresh token. `access_token`, `refresh_token`, `id_token`,
  `session_state` and `code_verifier` are stripped from the session before it is sent.
  No token is logged.
- The FPL web view only accepts a session posted from `fantasy.premierleague.com`. It
  runs incognito, so nothing from FPL outlives the screen. As a result, signing out
  also signs FPL out on the phone, as before.
- The checkout never sees card details and never tells the server that a payment
  succeeded. The server verifies it with the provider.
- Withdrawals keep the same idempotency key across retries.

## What has been tested and what has not

- Tested: TypeScript type-check (clean), web export, and Android and iOS JS bundles
  compiled to Hermes bytecode.
- Tested in demo mode in headless Chromium, at phone width, at desktop width (navigation
  rail), and in light and dark themes:
  - welcome and QR sign-in, email sign-in, Home
  - Pools (active), link-team dialog, create-pool dialog with split payouts, pool detail
    and leaderboard, head to head
  - Profile, Wallet, Top up, Settings, Withdraw, Bank account and bank picker
  - invite links (`/join/CODE` and old `/#/join/CODE`) opened while signed out
  - the Royal Rumble banner on Home and Pools, and its campaign page
- Not tested:
  - Device builds (no Android or iOS build has been run).
  - The FPL login web view, the GlobalPay/Paystack checkout and the QR camera scanner.
    These need a real phone.
  - Requests against the live API, token refresh, and the realtime socket.
