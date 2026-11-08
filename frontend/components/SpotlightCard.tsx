import * as React from 'react';

/** Hue Board's original, MIT-licensed focus surface. No third-party animation dependency. */
export interface SpotlightCardProps extends React.HTMLAttributes<HTMLDivElement> {
  spotlightColor?: string;
  intensity?: number;
  spotlightSize?: number;
  softness?: number;
  borderGlow?: number;
  smoothing?: number;
  theme?: 'dark' | 'light';
  disabled?: boolean;
}

export default function SpotlightCard({
  children, className = '', style, spotlightColor = 'var(--primary)',
  intensity = 0.12, spotlightSize = 240, theme = 'dark', disabled = false,
  softness: _softness, borderGlow: _borderGlow, smoothing: _smoothing,
  onPointerMove, onPointerLeave, ...props
}: SpotlightCardProps) {
  const ref = React.useRef<HTMLDivElement>(null);
  const [point, setPoint] = React.useState<{x:number;y:number}|null>(null);
  const move = (event: React.PointerEvent<HTMLDivElement>) => {
    onPointerMove?.(event);
    if (disabled || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const rect = ref.current?.getBoundingClientRect();
    if (rect) setPoint({x:event.clientX-rect.left,y:event.clientY-rect.top});
  };
  return <div data-hue-board="focus-surface" ref={ref} className={'relative isolate overflow-hidden rounded-2xl border bg-card text-card-foreground '+className}
    style={style} onPointerMove={move} onPointerLeave={event=>{setPoint(null);onPointerLeave?.(event)}} {...props}>
    {point && !disabled ? <span aria-hidden="true" className="pointer-events-none absolute inset-0 rounded-[inherit]"
      style={{background:`radial-gradient(circle ${Math.max(40,spotlightSize)}px at ${point.x}px ${point.y}px, color-mix(in srgb, ${spotlightColor} ${(100*Math.min(.35,Math.max(0,intensity))*(theme==='light'?.6:1)).toFixed(1)}%, transparent), transparent 75%)`}} /> : null}
    <div className="relative">{children}</div>
  </div>;
}
