import { createContext, useContext } from 'react';
import { TextStyle } from 'react-native';

/**
 * FPL Boardman brand palette (Brand Identity Guidelines v1.0, page 06).
 * Every colour the app uses is one of these, a tint of one of these, or a
 * darker/lighter shade of one of these where the pure colour would not be
 * legible (noted next to the value).
 */
export const Brand = {
  boardroomPurple: '#3D195B', // primary · 60%
  pitchGreen: '#00FF85', // accent · 15%
  captainCyan: '#04F5FF', // accent · 10%
  redCardPink: '#E90052', // alerts · 5%
  midnight: '#1A0B28', // dark UI
  white: '#FFFFFF',
  /** The page tone used throughout the guidelines document. */
  paper: '#F4F2F7',
} as const;

/** Colours that are the same in both themes (were AppColors in Flutter). */
export const AppColors = {
  ink: Brand.midnight, // was 0xFF06201B
  forest: Brand.boardroomPurple, // was 0xFF0B3A30
  lime: Brand.pitchGreen, // was 0xFF72F75C
  cyan: Brand.captainCyan, // was 0xFF49D7F2 (countdown)
  danger: Brand.redCardPink, // was 0xFFFF5D68
  /** The dark hero cards (was [0xFF0B4939, 0xFF271747]) and their body text (was 0xFFD1E3DC). */
  heroPanel: ['#4A1F6E', '#1A0B28'] as [string, string],
  heroText: '#DCCFEA',
  /** Functional colours kept from the original app (not brand colours). */
  amber: '#F5A524',
  orange: '#FF9800',
} as const;

export const AppSpacing = { xxs: 4, xs: 8, sm: 12, md: 16, lg: 24, xl: 32, xxl: 48 } as const;
export const AppMotion = { quick: 180, standard: 320, entrance: 520 } as const;

export type Scheme = {
  dark: boolean;
  /** Tint for text, icons, selection and focus. */
  primary: string;
  /** Filled call-to-action buttons: Pitch Green with Boardroom Purple text, as in the brand guide. */
  fill: string;
  onFill: string;
  primaryContainer: string;
  onPrimaryContainer: string;
  secondary: string;
  scaffold: string;
  surface: string;
  surfaceHigh: string;
  onSurface: string;
  text: string;
  display: string;
  onSurfaceVariant: string;
  outline: string;
  outlineVariant: string;
  inputFill: string;
  inputBorder: string;
  navBar: string;
  error: string;
  /** Money coming in, and "ok" confirmations. */
  positive: string;
  success: string;
  panel: [string, string];
  panelShadow: boolean;
  divider: string;
};

const light: Scheme = {
  dark: false,
  primary: Brand.boardroomPurple,
  fill: Brand.pitchGreen,
  onFill: Brand.boardroomPurple,
  primaryContainer: '#E7DEF1', // Boardroom Purple tint
  onPrimaryContainer: Brand.boardroomPurple,
  secondary: '#00838A', // Captain Cyan, darkened for contrast on white
  scaffold: Brand.paper,
  surface: Brand.white,
  surfaceHigh: '#ECE6F2',
  onSurface: Brand.midnight,
  text: Brand.midnight,
  display: Brand.midnight,
  onSurfaceVariant: '#655574',
  outline: '#8E7FA0',
  outlineVariant: '#D8CFE2',
  inputFill: Brand.white,
  inputBorder: '#DED6E8',
  navBar: Brand.white,
  error: Brand.redCardPink,
  positive: '#007F44', // Pitch Green, darkened for contrast on white
  success: '#007F44',
  panel: [Brand.white, '#EFE8F6'],
  panelShadow: true,
  divider: 'rgba(216,207,226,0.5)',
};

const dark: Scheme = {
  dark: true,
  primary: Brand.pitchGreen,
  fill: Brand.pitchGreen,
  onFill: Brand.boardroomPurple,
  primaryContainer: '#1F4A47',
  onPrimaryContainer: '#D6FFE9',
  secondary: Brand.captainCyan,
  scaffold: Brand.midnight,
  surface: '#26123A', // Midnight, lifted toward Boardroom Purple
  surfaceHigh: '#33194C',
  onSurface: Brand.white,
  text: '#EFE9F5',
  display: Brand.white,
  onSurfaceVariant: '#BBAACD',
  outline: '#8A76A0',
  outlineVariant: '#4B3463',
  inputFill: '#2A1541',
  inputBorder: '#4A2E66',
  navBar: '#21102F',
  error: '#FF4F8E', // Red Card Pink, lightened for contrast on Midnight
  positive: Brand.pitchGreen,
  success: '#00C96A',
  panel: [Brand.boardroomPurple, '#24103A'],
  panelShadow: false,
  divider: 'rgba(75,52,99,0.5)',
};

export const schemes = { light, dark };

export const ThemeContext = createContext<Scheme>(dark);
export const useScheme = () => useContext(ThemeContext);

/** Adds an alpha channel to a #RRGGBB colour. */
export function alpha(hex: string, a: number): string {
  if (!hex.startsWith('#') || hex.length !== 7) return hex;
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

// ---------------------------------------------------------------- type

/** Outfit for everything (brand headline + body face). */
const outfit: Record<number, string> = {
  400: 'Outfit_400Regular',
  500: 'Outfit_500Medium',
  600: 'Outfit_600SemiBold',
  700: 'Outfit_700Bold',
  800: 'Outfit_800ExtraBold',
  900: 'Outfit_900Black',
};
const mono: Record<number, string> = {
  400: 'JetBrainsMono_400Regular',
  500: 'JetBrainsMono_500Medium',
  700: 'JetBrainsMono_700Bold',
  800: 'JetBrainsMono_800ExtraBold',
  900: 'JetBrainsMono_800ExtraBold',
};

/** A font for a weight. Custom fonts need one family per weight on Android. */
export function font(weight: number = 400, numbers = false): TextStyle {
  const table = numbers ? mono : outfit;
  const key = Object.keys(table)
    .map(Number)
    .reduce((best, w) => (Math.abs(w - weight) < Math.abs(best - weight) ? w : best), 400);
  return { fontFamily: table[key] };
}

/** The Material 3 type scale the Flutter app used, with its overrides. */
export const type = {
  displaySmall: { fontSize: 36, lineHeight: 44, letterSpacing: -1.2, ...font(800) },
  headlineMedium: { fontSize: 28, lineHeight: 36, letterSpacing: -0.7, ...font(800) },
  headlineSmall: { fontSize: 24, lineHeight: 32, ...font(400) },
  titleLarge: { fontSize: 22, lineHeight: 28, ...font(800) },
  titleMedium: { fontSize: 16, lineHeight: 24, letterSpacing: 0.15, ...font(700) },
  titleSmall: { fontSize: 14, lineHeight: 20, letterSpacing: 0.1, ...font(500) },
  bodyLarge: { fontSize: 16, lineHeight: 24, letterSpacing: 0.5, ...font(400) },
  bodyMedium: { fontSize: 14, lineHeight: 20.3, letterSpacing: 0.25, ...font(400) },
  bodySmall: { fontSize: 12, lineHeight: 16, letterSpacing: 0.4, ...font(400) },
  labelLarge: { fontSize: 14, lineHeight: 20, letterSpacing: 0.1, ...font(500) },
  labelMedium: { fontSize: 12, lineHeight: 16, letterSpacing: 0.5, ...font(500) },
  labelSmall: { fontSize: 11, lineHeight: 16, letterSpacing: 0.5, ...font(500) },
} satisfies Record<string, TextStyle>;

export type TypeName = keyof typeof type;
