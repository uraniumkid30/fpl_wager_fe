import React from 'react';
import Svg, { Circle, ClipPath, Defs, G, Rect } from 'react-native-svg';

import { useScheme } from '@/theme/theme';

/** The wallet glyph (a port of the Flutter CustomPainter, on a 24×24 grid). */
export function WalletIcon({ size = 20, color, strokeWidth = 1.6 }: { size?: number; color?: string; strokeWidth?: number }) {
  const s = useScheme();
  const c = color ?? s.onSurface;
  const line = { stroke: c, strokeWidth, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, fill: 'none' };
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Defs>
        <ClipPath id="wTop">
          <Rect x={0} y={0} width={24} height={7} />
        </ClipPath>
        <ClipPath id="wLeft">
          <Rect x={0} y={0} width={21.25} height={24} />
        </ClipPath>
      </Defs>
      <Rect x={2.75} y={7} width={18.5} height={12.5} rx={3.2} {...line} />
      <G clipPath="url(#wTop)">
        <G transform="rotate(-8 5 12)">
          <Rect x={5} y={4.4} width={12.5} height={8} rx={2} {...line} />
        </G>
      </G>
      <G clipPath="url(#wLeft)">
        <Rect x={15} y={11.2} width={9} height={4.1} rx={2.05} {...line} />
      </G>
      <Circle cx={17.5} cy={13.25} r={0.85} fill={c} />
    </Svg>
  );
}
