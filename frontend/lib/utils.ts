/** Source-owned shadcn cn helper. Static variants are mutually exclusive; no twMerge runtime needed. */
export function cn(...values:(string|false|null|undefined)[]):string{return values.filter(Boolean).join(' ')}
