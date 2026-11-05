/** MIT-licensed original scene surface for Hue Board.
 * Decorative gradients visualize a design theme, never Bridge telemetry.
 */
import * as React from 'react';

export interface SpotlightCardProps extends React.HTMLAttributes<HTMLDivElement> {
  spotlightColor?: string;
  intensity?: number;
  spotlightSize?: number;
  softness?: number;
  borderGlow?: number;
  smoothing?: number;
  theme?: 'light' | 'dark';
  disabled?: boolean;
}

/** A quiet visual highlight without continuous animation or pointer tracking. */
export default function SpotlightCard({
  children,
  className = '',
  style,
  spotlightColor = 'var(--primary)',
  intensity = 0.12,
  spotlightSize = 240,
  theme = 'dark',
  disabled = false,
  // Retain the old caller's optional props without forwarding them to the DOM.
  softness: _softness,
  borderGlow: _borderGlow,
  smoothing: _smoothing,
  ...rest
}: SpotlightCardProps) {
  const opacity = disabled ? 0 : Math.min(0.13, Math.max(0, intensity)) * (theme === 'light' ? 0.6 : 1);
  return (
    <div
      data-hue-board-surface="scene"
      className={'relative isolate overflow-hidden rounded-2xl border bg-card text-card-foreground ' + className}
      style={style}
      {...rest}
    >
      {!disabled && <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 -z-10 rounded-[inherit]"
        style={{
          background: `radial-gradient(circle ${Math.max(40, spotlightSize)}px at 25% 5%, ${spotlightColor}, transparent 95%)`,
          opacity,
        }}
      />}
      {children}
    </div>
  );
}
