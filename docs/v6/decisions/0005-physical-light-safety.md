# ADR 0005: Dynamic physical light requires an explicit safety policy

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Safety and Accessibility, Native Product, Hardware Qualification
- **Issues:** #11, #17, #18

## Context

Dynamic room lighting can cause discomfort and, for susceptible people, migraines, dizziness, nausea, or seizures. Signify’s Hue developer terms require developers to avoid light combinations or frequencies that may cause adverse health effects, warn users before use, and advise them to stop if they experience discomfort. Interface Reduce Motion does not automatically make physical lighting safe.

## Decision

Hue Board 6 implements a physical-light safety layer separate from interface animation preferences.

### Required product behavior

1. Show a written first-use warning before any dynamic physical-light mode.
2. Advise users to stop immediately if they experience discomfort.
3. Keep a one-tap emergency stop reachable whenever dynamic output is active.
4. Provide **Reduce Light Motion**, separate from interface Reduce Motion.
5. Start dynamic modes with conservative brightness and motion defaults.
6. Validate built-in, imported, and future generated scenes before physical playback.
7. Clamp or reject scene parameters outside the approved engineering envelope.
8. Never market a mode as medically safe or suitable for a health condition.
9. Record the safety-policy revision in scene validation and release evidence.
10. Use the system Dim Flashing Lights preference as an additional input where a documented platform API is available, while retaining Hue Board’s explicit setting.

### Interim engineering envelope

Until fixture-specific physical review establishes stricter limits:

- no deliberate strobe mode;
- no repeated sequence with more than three flashes in any one-second interval;
- no rapid full-room saturated-red inversion;
- imported or generated content that cannot be analyzed is rejected for dynamic playback rather than assumed safe;
- Reduce Light Motion uses slow continuous transitions, suppresses transient accents, and limits large luminance reversals;
- default intensity remains below the configured per-fixture cap and below full output;
- safety validation failure cancels the operation before transport ownership begins.

The three-flash rule is an interim conservative engineering guard adapted from established accessibility guidance. It is not a medical guarantee for physical room lighting.

## Consequences

- Scene and transport requests carry a validated safety profile and policy revision.
- Entertainment and Sound inherit the same gate.
- Safety failures capable of unsafe output are P0 defects.
- Safety settings cannot be hidden solely in advanced configuration.

## Migration impact

Stored scenes are not silently rewritten when the policy changes. They are revalidated before playback. A scene that no longer passes remains exportable and editable, but cannot start dynamic output until corrected or safely transformed with explicit user confirmation.

## Evidence required

Automated fixtures cover abrupt luminance changes, repeated alternation, saturated-red transitions, prolonged output, malformed and imported scenes, Reduce Light Motion, policy migration, and emergency stop in every transport. Physical qualification observes actual fixtures; API acknowledgements are not visible-safety evidence.

## Rejected alternatives

### Rely only on interface Reduce Motion

Rejected because UI animation preference does not constrain physical fixtures.

### Display a warning without enforcing limits

Rejected because disclosure alone does not prevent unsafe built-in, imported, or generated behavior.

### Claim a universal medically safe threshold

Rejected because fixture geometry, room conditions, individual susceptibility, and evidence vary. Hue Board uses conservative engineering limits without medical claims.

## Supersession conditions

A later ADR may tighten or replace the interim envelope after specialist review and physical measurement. Loosening a limit requires documented evidence, migration behavior, updated warnings, and a full supported-fixture qualification matrix.

## Sources

- https://developers.meethue.com/terms-of-use-and-conditions/
- https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html
