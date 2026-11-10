# Codex Handoff: Execute Hue Board 6 Finalization Program

## Mission

Advance `wyattowalsh/hue-board` from the signed baseline commit
`c82ac4d44a0e7c0dbda91145377b7a1c0cab90f3` to a qualified Hue Board 6.0
native-iPhone release.

This is an execution program, not a fresh product brainstorm or a rewrite.

Canonical inputs in this repository:

- `docs/v6/README.md`
- `docs/v6/defect-register.md`
- `docs/v6/work-packages.json`
- `docs/v6/issue-map.md`

## Release decision

- Scriptable 5.3.0 is the final Scriptable feature release and LTS fallback.
- Native 6.0.0 is the qualified native-iPhone GA core.
- Entertainment Live is a conditional 6.1 track.
- Microphone and local-file Sound are a conditional 6.2 track.
- Browser control, companion hosts, Foundation Models, cross-app audio,
  Apple Watch, cloud sync, MIDI, and desktop capture do not block 6.0.

Do not silently re-expand 6.0.

## Non-negotiable invariants

1. Opening, discovering, pairing, refreshing, navigating, importing, editing a
   draft, scrubbing a preview, and generating a preview issue no light writes.
2. Exactly one Hue Board writer owns a coordinated Bridge/scope at a time.
3. Every physical operation carries a writer epoch and operation ID.
4. Responses from a stale epoch cannot update current state.
5. Preview is structurally incapable of writing through `NullPreviewTransport`.
6. Bridge API acceptance or readback is not optical proof.
7. Unsupported or ambiguous outcomes are explicit, never represented as success.
8. Recovery is captured before the first possibly mutating operation.
9. Original pre-playback snapshots are immutable and append only for newly
   touched fixtures.
10. Partial restore retains unresolved fixtures.
11. Emergency off never discards the recovery journal.
12. Credentials stay in Keychain and never appear in logs, fixtures, screenshots,
    exports, URLs, or CI.
13. No silent Entertainment-to-REST fallback.
14. No P0 or P1 defect may remain open at release.
15. No App Store, hardware, accessibility, or safety claim without observed
    evidence on the exact commit.

## Operating model

Use trunk-based, short-lived work:

- one issue per worktree;
- one behavioral purpose per PR;
- no long-lived integration branch;
- interface PRs precede dependent implementations;
- generated artifacts are regenerated after rebase;
- every PR names affected invariants, validation performed, missing evidence,
  migration impact, and rollback behavior;
- independent QA reviews every P0/P1 path before merge.

Do not perform a repository-wide directory migration unless a concrete shared
boundary demonstrably requires it.

## Parallel subagent teams

### Team A: Release and governance

Own hosted CI, branch protection, Scriptable 5.3 publication, release evidence,
and the canonical issue hierarchy.

### Team B: Apple platform and device qualification

Own Xcode/Swift remediation, app/UI test targets, signing, archive validation,
and issue #4.

First command path on the authorized Mac:

```sh
git switch main
git pull --ff-only
cp ios/device.env.example ios/device.env
cd ios
make iphone-preflight
make iphone-list
make iphone-run
```

Preserve exact logs and `.xcresult` bundles. Redact secrets and home identifiers.

### Team C: Persistence and migration

Own the state envelope, migration registry, historical fixtures, backups,
quarantine, rollback, multi-profile isolation, and recovery durability.

Do not delete old state during first migration success. Do not couple recovery
durability to ordinary UI preferences.

### Team D: Core ownership and transports

Land in this order:

1. operation/error taxonomy;
2. `PlaybackCoordinator` and writer epochs;
3. `LightingTransport`;
4. `NullPreviewTransport`;
5. `BridgeSceneTransport`;
6. `RestAmbientTransport`;
7. focused AppModel coordinators;
8. engine/catalog ABI model.

### Team E: Native product

Own draft/live separation, Lights and Scenes UX, conditional Now Playing,
favorites, saved looks, import/export, capability inspection, settings and safe
App Intents.

Do not add Sound, Entertainment, browser, or AI placeholder controls to 6.0.

### Team F: QA infrastructure

Build `FakeHueBridge` before large UI rewrites. It must support REST, event-stream
fixtures, rate limiting, delayed replies, malformed payloads, disconnects, stale
scene IDs, competing controllers and partial failures.

### Team G: Security, privacy, safety and accessibility

Own the threat model, privacy manifest, diagnostics redaction, store disclosures,
physical-light warning, emergency stop, Reduce Light Motion, scene validation,
VoiceOver and Dynamic Type.

Physical-light motion reduction is distinct from interface Reduce Motion.

### Team H: Release qualification

Own App Store identity, TestFlight, evidence bundles, release candidates, phased
rollout, defect triage and rollback.

Do not enter RC while any P0/P1 remains open or evidence is missing.

### Team I: Conditional Entertainment

Do not begin product implementation until the EDK licensing and feasibility ADR
closes with a documented go decision.

### Team J: Conditional Sound

May build recorded-fixture prototypes in isolation, but no Sound product ships
before Entertainment transport qualification.

## Initial execution wave

Complete in dependency order:

1. Restore hosted CI and protected `main`.
2. Publish Scriptable 5.3.
3. Run the exact physical-device baseline.
4. Write and approve the scope, version, support, parity and safety ADRs.
5. Upgrade the release lane and add app/UI test targets.
6. Add persistence schema 2 and migration fixtures.
7. Introduce `PlaybackCoordinator`, writer epochs and transport protocol.
8. Add `NullPreviewTransport`.
9. Enforce draft/live separation.

Do not start broad UX work before steps 1–8 expose the real platform and
migration defects.

## Required PR template content

Every PR description must include:

```markdown
## Scope
## User-visible behavior
## Invariants affected
## Persistence/migration impact
## Security/privacy impact
## Physical-light safety impact
## Validation executed
## Evidence artifacts
## Missing evidence
## Rollback
## Follow-up issues
```

## Validation hierarchy

Evidence strength, strongest last:

1. static inspection;
2. parser/typecheck;
3. unit test;
4. integration test against `FakeHueBridge`;
5. simulator UI test;
6. signed physical-device execution;
7. real Bridge and fixture observation;
8. repeatable release-candidate matrix on the exact tag.

Never substitute a lower evidence tier for a higher-tier release claim.

## Defect triage

- P0: unsafe write, wrong target, secret exposure, recovery loss, destructive
  migration, unstoppable output, crash loop, impossible rollback.
- P1: supported core flow broken, misleading success, pairing/play/restore
  failure, inaccessible emergency action.
- P2: significant bounded defect.
- P3: polish.

Any P0 or P1 blocks the next beta or release candidate.

## Release outputs

Each candidate must produce the exact `release-evidence/` structure in the
execution program. Evidence must be tied to the exact commit and build number.

## Stop conditions

Stop the affected lane and open a blocking issue when:

- EDK distribution rights are unclear;
- a migration can overwrite unvalidated old state;
- preview can reach a physical transport;
- stale callbacks can affect a new writer epoch;
- recovery can be deleted by ordinary settings cleanup;
- certificate mismatch is bypassed;
- a dynamic pattern exceeds the approved physical-light safety envelope;
- the exact app target cannot compile or archive;
- an enabled platform surface is not testable;
- App Store privacy output disagrees with declared behavior.

## Completion report format

Return:

1. exact main SHA;
2. merged PRs and closed issues;
3. remaining dependency graph;
4. test/evidence summary by tier;
5. P0–P3 ledger;
6. migration compatibility table;
7. supported OS/device/Bridge/fixture matrix;
8. release evidence bundle paths;
9. known limitations;
10. honest release disposition.

Do not report “fully assured,” “App Store-ready,” “hardware-qualified,” or
“Entertainment-quality” unless every corresponding gate has observed evidence.
