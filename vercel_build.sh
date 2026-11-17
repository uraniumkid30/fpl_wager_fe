#!/bin/bash
# Vercel build for the FPLboardman web app (React Native / Expo).
# Replaces the old Flutter vercel_build.sh: no Flutter SDK to clone any more.
# Vercel runs `npm ci` first (vercel.json installCommand), then this script.
#
# Set these in Vercel > Project > Settings > Environment Variables:
#   EXPO_PUBLIC_API_BASE_URL   https://api.yourdomain.com   (required, must be https)
#   EXPO_PUBLIC_USE_DEMO_DATA  false                        (optional; true = demo data, no server)
#   EXPO_PUBLIC_ENABLE_DEV_CREDIT false                     (optional; never true in production)
#   EXPO_PUBLIC_PAYMENT_CALLBACK_URL                         (optional override)
# EXPO_PUBLIC_* values are built into the site, so never put a secret in one.

set -euo pipefail

echo "Node $(node --version), npm $(npm --version)"

if [ "${EXPO_PUBLIC_USE_DEMO_DATA:-false}" != "true" ]; then
  case "${EXPO_PUBLIC_API_BASE_URL:-}" in
    https://*) echo "API: ${EXPO_PUBLIC_API_BASE_URL}" ;;
    "") echo "ERROR: EXPO_PUBLIC_API_BASE_URL is not set in Vercel's environment variables." >&2; exit 1 ;;
    *) echo "ERROR: EXPO_PUBLIC_API_BASE_URL must start with https:// (a site on https cannot call an http API)." >&2; exit 1 ;;
  esac
else
  echo "Demo data build: no API is used."
fi

if [ "${VERCEL_ENV:-}" = "production" ] && [ "${EXPO_PUBLIC_ENABLE_DEV_CREDIT:-false}" = "true" ]; then
  echo "ERROR: EXPO_PUBLIC_ENABLE_DEV_CREDIT must not be true in production." >&2
  exit 1
fi

echo "Type-checking..."
npx tsc --noEmit

echo "Building the website..."
rm -rf dist
npx expo export --platform web --output-dir dist

echo "Build completed."
ls -la dist
