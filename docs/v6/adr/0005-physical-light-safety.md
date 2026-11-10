# ADR 0005: Physical-light safety policy

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Safety/Accessibility, Product Architecture, Hardware Qualification
- **Issues:** #11, #17, #20

## Context

Hue Board controls physical light output. Interface accessibility settings alone do not bound the brightness, contrast, timing, repetition, or duration of real fixtures.

The Philips Hue developer terms prohibit applications that trigger adverse health effects through light combinations or frequencies and require developers to inform users about possible adverse effects and advise them to stop if they experience discomfort.

Official reference checked 2026-11-10:

- https://developers.meethue.com/terms-of-use-and-conditions/

The current product includes Bridge-native dynamic scenes and low-rate REST Live. Future Entertainment and Sound modes would increase temporal fidelity and therefore require stronger scheduling, validation, measurement, and user controls.

## Decision

Hue Board treats physical-light safety as a separate product, architecture, validation, and release concern.

No dynamic mode ships without:

- informed first-use warning;
- conservative defaults;
- persistent emergency stop;
- a **Reduce Light Motion** control distinct from interface Reduce Motion;
- validation of built-in, imported, and generated scene parameters;
- real-fixture observation on the supported matrix;
- explicit limitations and no medical or wellness claims.

## User warning

Before the first dynamic physical-light session, Hue Board explains that:

- changing light combinations and motion may cause discomfort for some people;
- the user should stop immediately if they experience discomfort;
- Hue Board is an independent product, not a Signify or Philips Hue product;
- Bridge/API acceptance is not proof of physical output;
- emergency stop remains available while Hue Board owns output.

The warning is versioned. It is shown again when the safety policy materially changes.

## Emergency stop

During any Hue Board-owned dynamic output:

- Stop is reachable without navigating through settings.
- Stop cancels the active writer and prevents new frames or scene operations.
- Transport ownership is released before restore begins.
- The recovery journal is retained until restore succeeds or the user completes a separately confirmed destructive abandonment flow.
- Emergency off may send bounded off commands but never deletes the original baseline.
- Partial failures are listed and remain retryable.

## Reduce Light Motion

Reduce Light Motion is independent of SwiftUI Reduce Motion.

When enabled it must, at minimum:

- select or transform toward slower temporal behavior;
- reduce abrupt luminance and color contrast changes;
- suppress transient accent behavior that violates the approved profile;
- disable patterns classified as incompatible rather than pretending they were preserved;
- remain effective for built-in, imported, future generated, Ambient Live, Entertainment, and Sound scenes;
- be represented in diagnostics and release evidence without exposing household data.

The exact transform and thresholds are established from the approved safety profile and hardware qualification, not guessed in UI code.

## Safety profiles

Hue Board uses a versioned, testable physical-output safety profile. It can constrain:

```text
allowed transport and mode
maximum configured brightness
minimum transition duration
maximum luminance delta per transition
maximum color/contrast delta
repetition and reversal behavior
session duration
transient accent density
silence/loss fallback
fixture-specific output limits
```

This ADR intentionally does not assert a medical numeric threshold. Numeric limits must be documented with their source, measurement method, supported fixture assumptions, and revision history before release.

Until an approved profile exists:

- v6.0 may ship only the already conservative Bridge Play and long-transition Ambient Live behaviors that pass physical qualification;
- Entertainment 6.1 remains blocked;
- Sound 6.2 remains blocked;
- imported scenes outside the conservative envelope are rejected or require a safe transform with explicit disclosure.

## Built-in scenes

Every built-in scene receives:

- deterministic validation against the active safety profile;
- test coverage across brightness and fixture limits;
- Reduce Light Motion behavior;
- physical review on representative fixtures;
- a safety classification stored with the catalog revision.

No built-in scene deliberately implements strobe, rapid full-scale luminance inversion, or other behavior prohibited by the approved profile.

## Imported and generated scenes

Untrusted scene content is data, not authority.

Imports and future model-generated intents:

- cannot bypass safety validation;
- cannot raise fixture caps or target additional scopes implicitly;
- cannot select an unavailable transport silently;
- cannot execute arbitrary code or Hue requests;
- are previewed before Apply or Play;
- are rejected when no safe transformation preserves the stated intent;
- record any clamping or transformation in a user-visible change report.

## Bridge-native playback

Hue Board cannot inspect or control every internal temporal detail of a Bridge-native dynamic scene. Therefore:

- only qualified scene configurations are offered;
- the UI describes the result as Bridge-owned playback, not exact Hue Board choreography;
- Stop and restore remain available;
- real fixtures are observed during qualification;
- unexpected Bridge behavior blocks the affected matrix row.

## Entertainment and Sound

Entertainment and Sound require additional evidence before release:

- measured requested and observed cadence;
- dropped and late-frame metrics;
- bounded buffering and cancellation;
- interruption and takeover behavior;
- battery and thermal measurements;
- physical-light review under normal and Reduce Light Motion profiles;
- session-duration limits;
- silence, clipping, source-loss, and stale-feature behavior for Sound.

No silent fallback may move a user from a safer or lower-motion mode into a more dynamic mode.

## Accessibility relationship

Interface accessibility and physical-light safety overlap but are not identical.

- SwiftUI Reduce Motion governs interface animation.
- Reduce Transparency and contrast settings govern interface presentation.
- Reduce Light Motion governs physical fixtures.
- VoiceOver users must be able to identify the active mode, scope, progress, uncertainty, emergency stop, and recovery obligation.
- A safety warning cannot rely only on color, animation, or visual placement.

## Logging and evidence

Safety evidence records:

```text
app commit and build
safety-profile version
catalog revision
mode and transport
fixture capability classes
configured limits
requested cadence or transition timing
session duration
stop and restore results
battery and thermal observations where applicable
physical observation notes
```

Evidence must be redacted and must not include application keys, private addresses, household names, full stable identifiers, raw audio, or room layouts by default.

## Consequences

### Positive

- Dynamic lighting has explicit stop, warning, validation, and qualification gates.
- Imported, generated, and audio-reactive scenes cannot bypass limits.
- Accessibility and physical output are treated honestly as related but distinct systems.
- Entertainment and Sound cannot ship based on API acknowledgements alone.

### Costs

- Some patterns or parameters may be unavailable or transformed.
- Hardware qualification is required for every safety profile revision.
- The product must maintain safety metadata and tests across releases.

## Rejected alternatives

### Rely only on operating-system Reduce Motion

Rejected because it does not constrain physical fixtures.

### Publish a universal numeric threshold without evidence

Rejected because fixture output, room context, transport, and standards require documented qualification.

### Treat warnings as sufficient

Rejected because user-facing warnings do not replace conservative design, validation, emergency stop, and physical testing.

### Allow arbitrary imported patterns with a disclaimer

Rejected because unsafe output cannot be delegated entirely to user responsibility.

## Reversal and revision

Changes to warning text, safety profile semantics, dynamic-output limits, or emergency-stop behavior require a new ADR or a superseding safety ADR, updated consent version, regression fixtures, physical qualification, and release notes.
