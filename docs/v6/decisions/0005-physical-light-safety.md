# ADR 0005: Dynamic physical light requires an explicit safety policy

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Safety and Accessibility, Native Product, Hardware Qualification

## Context

Dynamic room lighting can cause discomfort and, for susceptible people, migraines, dizziness, nausea, or seizures. Signify's Hue developer terms require developers to avoid light combinations or frequencies that may cause adverse health effects, to warn users before use, and to advise them to stop if they experience discomfort. Interface Reduce Motion does not automatically make physical lighting safe.

## Decision

Hue Board 6 implements a physical-light safety layer that is separate from interface animation settings.

### Required product behavior

1. Show a written first-use warning before any dynamic physical-light mode.
2. Advise users to stop immediately if they experience discomfort.
3. Keep a one-tap emergency stop reachable whenever dynamic output is active.
4. Provide **Reduce Light Motion**, separate from interface Reduce Motion.
5. Start dynamic modes with conservative brightness and motion defaults.
6. Validate built-in, imported, and future generated scenes before physical playback.
7. Clamp or reject scene parameters outside the approved engineering envelope.
8. Never market a mode as medically safe or suitable for a health condition.
9. Record the safety-policy revision in release evidence.
10. Apply the system Dim Flashing Lights preference as an input where the platform API is available, while retaining Hue Board's own explicit light-motion setting.

### Interim engineering envelope

Until a dedicated physical-light review establishes stricter fixture-specific limits:

- no deliberate strobe mode;
- no repeated sequence with more than three flashes in any one-second interval;
- no rapid full-room saturated-red inversion;
- imported or generated content that cannot be analyzed is rejected for dynamic playback rather than assumed safe;
- Reduce Light Motion uses slow continuous transitions, suppresses transient accents, and limits large luminance reversals;
- the default scene intensity remains below the configured per-fixture cap and below full output;
- an operation is canceled when safety validation fails.

The three-flash limit is an interim conservative test rule adapted from established accessibility guidance. It is not a medical guarantee for physical room lighting.

### Validation

Safety fixtures cover:

- abrupt luminance changes;
- repeated alternating brightness;
- saturated-red transitions;
- prolonged high-output playback;
- imported scene data;
- malformed scene data;
- Reduce Light Motion;
- system Dim Flashing Lights changes;
- emergency stop during every transport mode.

Physical qualification observes actual fixtures. Bridge acknowledgements are not used as evidence of visible safety.

## Consequences

- Scene and transport interfaces carry a validated safety profile.
- Entertainment and Sound releases inherit this gate.
- Safety failures are release-blocking P0 defects.
- The policy can be tightened by a superseding ADR as physical measurement and specialist review improve the evidence.
