# Native 0.3.0 internal qualification

November 21, 2026 · Development app 0.3.0 (7) · Source integration on `main`

The repaired core source is `e2783e8bdfe100b75c5ad9e9f6e5a849fce13af5`. The screen probe’s last code change is `a8addd67d288701063524aa674fc7f0745ff1c36`. CI privacy and receipt handling is at `5986f98a745b32fdea5b8cf3bc9a86ce1b0055d4`. The public source includes these internal changes. The last verified physical installation was **0.2.2 (6)** from `41bc092a3007fec03a79b7ab1d47a305d131e920`. The execution ledger records evidence and outstanding work for each of the plan’s 166 tasks. [Task ledger](execution.tsv) · [Plan](../native-0.3.0-plan.md)

In the ledger, **source-implemented** means the named paths contain the behavior. **tests-authored** identifies assertions awaiting an applicable execution receipt. **package-passed** and **passed** identify observed checks at the cited revision. **partial**, **blocked** and **deferred** retain the missing evidence or product decision in the final column.

## Core behaviors

| Workflow | Scope of the candidate |
| --- | --- |
| Room | On entering a ready, idle room, discover saved Hue Entertainment positions and show matched fixtures. Preview and save positions locally. A separate sweep preview assigns phases to eligible moving fixtures. The app reads membership from the Hue Bridge. Apple Home geometry, ordinary-room coordinates and ongoing two-way layout sync are unavailable. |
| Studio | Rehearse an actual room or the offline sample, scrub the timeline, step through cues, inspect fixture targets and edit a mix. Native Live uses the same frame planner and bounded REST transport. Rehearsal values model the commands. Physical position, timing and emitted light require device observations. |
| Dynamic inputs | Preview an explicit microphone or local audio/video choice. Use audio level and current video tint within the existing caps. Stored Reduce Light Motion and the system Dim Flashing Lights preference govern reactive output. The main app supports Engine, Microphone and Local media. Cross-app capture remains in the separate probe. |
| Files | Export a whole setup or individual designs, preview per-section changes, choose specific compatible room layouts, inspect migration warnings, and explicitly import. Durable setup sections use a local transaction. All imports check persisted recovery and the current writer lease, including a cold launch with a migrated baseline and no active profile. The guide describes what persists as a mix and what reimporting a draft restores. Pairing credentials, consent, the physical recovery journal and media remain private. [Setup format](../native-setup-format.md) |
| Emergency and restore | Preempt and drain the writer, capture eligible fixtures before idle Off, retain pending baselines, and check saved power, brightness and the active XY or mirek before resolving a restore. Physical readback, including partial failures, requires the actual Bridge. |

## Build and test receipts

Linux ran Node 22.23.1 and pnpm 10.17.1 with the frozen lockfile on `5986f98`, which contains the repaired core. All **202 JavaScript tests**, the **eight focused native-parity tests**, TypeScript, timing, and both pinned Scriptable bundle checks passed. Regenerating the engine and catalog produced zero tracked changes. The graph validator found 166 tasks, including 123 core tasks, and its eight tests passed at the core freeze. The later evidence-board revision passed ten graph and board tests. Chromium rendered the generated HTML at desktop and phone widths and verified status filtering, search and dependency navigation.

During integration, Xcode 27.2 (27B52) ran 112 Apple package tests at `3427fee`, 120 at `d30106f`, and 125 at `7e74c08`. At `7e74c08`, the generic iPhoneOS app, app tests and UI tests built. The development app and independent smoke runner also passed strict code-signature checks. The superseded Release archive and pre-manifest probe build were stopped to prioritize the frozen revisions. These results are specific to the indicated development commits.

### Repaired core checks

The previous `eb131cec` candidate had two malformed Swift JSON test literals. Compiling the actual tests on Linux exposed both errors. The repaired source also fixes a file import that could change lighting safety preferences when cold launch had retained a recovery journal without an active profile. A successful individual-file import rechecks recovery, writer ownership, its review and its destination immediately before applying. A separate setup-codec repair handles valid nested JSON across Foundation implementations and rejects Boolean/number substitution and unknown fields.

| Runtime | Evidence at the repaired source |
| --- | --- |
| Swift 6.2.3, Ubuntu 24.04 x86_64 | **123 distinct XCTest methods passed**, zero failures or skips. Strict concurrency and warnings as errors. The package ran three real writer-process deaths and independent recovery reads, checked restored colors and writer handoffs, rejected invalid setup fields and imported the build 6 corpus. |
| Swift 6.4.3, Debian 13 x86_64 | **123 distinct XCTest methods passed**, zero failures or skips, with the same flags. The compiler came from the signed Swift 6.x release archive. Both Linux runs exercise the explicit unsupported-Apple-engine path. |
| JavaScriptCoreGTK 2.52.6 | The original bundled engine produced the frozen schema-2, fixed-11 digest for **512 frames** with JIT enabled by default and with JIT disabled. Both runs matched the eight diagnostic anchors. An independent formatter checked every canonical frame. SHA-256 `a0f636b65b3523d581179377f7164f06973a8b9d46ca0fafe8959a606a0900cb`. |
| App model on Linux with Apple services substituted | **25 unchanged XCTest cases passed** through the actual AppModel, bootstrap, import, persistence and recovery logic. Cases covered clean and recovery-blocked imports, scoped layouts, restore acceptance, consent and safety edits. The same cold-launch safety test produced three failing assertions on the previous source and passed on the repair. The harness substituted unavailable Apple services. This check does not exercise SwiftUI, the Apple JavaScriptCore framework, AVFoundation, real networking or physical lights. |
| App model with real JavaScriptCoreGTK | An extended Linux run passed **30 distinct unchanged methods**. It includes the preceding 25 and adds five methods covering a persisted sweep, fixture targets and Studio rehearsal. The adapter invokes the bundled engine through the GTK command-line runtime. This run exercises neither Apple’s JSContext nor physical timing or light output. |
| Apple-target Swift syntax | 77 files across the app, app tests, UI tests, standalone runner and capture probe parsed for arm64 iOS. Type checking against the SDK, running XCTest, reviewing rendered UI and development signing remain Apple-host gates. |

To reproduce the portable package result, run `swift test --package-path ios/Packages/HueBoardKit --jobs 4 -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` on either recorded Linux toolchain. The standalone parity verifier accepts an installed JavaScriptCore shell. [JavaScriptCore verifier](../../scripts/verify-native-jsc.py) · [App-model harness](../../tests/native-appmodel/README.md)

The package tree is `3b66b72d3ab457dd29629af470cb6f12d1921006`. Two new simulator audits use Apple's accessibility API on a filtered scene card and a saved layout at the largest Dynamic Type size. Their runtime evidence is pending.

The interrupted Mac run targeted the previous `eb131cec` source. The last retrieved line showed compilation at 34 of 73. Read-only retries later reported the Mac offline. Old run outputs, if available, are under the directory named by `ios/DerivedData/qualification/current-030-path` in that checkout. The repaired candidate needs its own Apple receipts. On main CI raw XCTest bundles and archives stay on the runner. The public job summary emits allowlisted counts and archive privacy checks.

### GitHub Actions on main

GitHub accepted `5986f98a745b32fdea5b8cf3bc9a86ce1b0055d4` as a fast-forward of the existing `main`. Both hosted jobs ended with zero executed steps and no assigned runner. Both check annotations state that an account billing lock prevented the job from starting. There was no hosted compiler, simulator, archive or signing result. The local Apple host was also offline at the last check. [Native iOS run](https://github.com/wyattowalsh/hue-board/actions/runs/44893642769) · [Verify run](https://github.com/wyattowalsh/hue-board/actions/runs/44893642737)

The build 6 transfer oracle contains ten files generated by the historical Swift codec on Xcode 27.2. Its manifest SHA-256 is `39cd556120966f39ebeb3a4eee830b5dd56f4eaf76d4fa5c8b8eab545aff4abd`. The separate hand-authored household fixture contains two rooms and ten fixtures. Its SHA-256 is `4084f20d234c0924672cefe2e08b6d22bb49d52bce08124e8d29351fab129426`. [Build 6 fixture provenance](../../fixtures/native-transfer/build6/README.md)

## Privacy review

The core app uses its own UserDefaults domain and stores the Bridge application key separately in Keychain. Its manifest declares UserDefaults reason `CA92.1`, no tracking and an empty collected-data list. The Info.plist explains microphone and local network access. Discovery can contact the public Philips Hue broker as well as Bonjour. The broker receives ordinary connection metadata. Pairing, inventory and playback use the local Bridge. Media analysis retains derived levels or tints. An explicit Files export goes to the user’s chosen provider and may contain selected room layouts and fixture references.

The probe uses separate screen and app-audio stream outputs, has no Bridge writer, and declares local elapsed-time measurements under System Boot Time reason `35F9.1`. This review covers source and the specifically identified artifacts. Actual capture permissions, protected content, app switching, background continuity, resource measurements and physical playback each need their own device evidence. [Probe scope](../../ios/ScreenInputProbe/README.md)

## Physical qualification decision

Hold the installation and physical qualification of build 7. During this execution, both Apple's CoreDevice and xcdevice discovery exceeded bounded timeouts. CoreSimulator discovery also timed out and its launch process remained in an uninterruptible kernel wait. The coordinator issued no Mac restart, phone installation, credential change or lighting command. The original backup was present at reconciliation. The earlier six-fixture restore permission concerned a previous journal and run.

A fresh paired-device identity and checked pre/post state are required before interpreting a browse result. The independent runner must report a positive audit activation marker, complete the four-tab, search/keyboard, Room, Studio and Files assertions, and record the write-attempt count. Remaining hands-on checks include VoiceOver, Dynamic Type, reduced motion, room orientation, real microphone and file permissions, and separately authorized lighting and restoration runs. High-rate Entertainment streaming, gradient-strip editing and saved Hue scene copying remain outside the candidate. [DeviceSmoke](../../ios/DeviceSmoke/README.md) · [Physical checks](../../ios/DEVICE_TESTING.md)
