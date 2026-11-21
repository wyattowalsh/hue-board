# Native 0.3.0 internal qualification

November 21, 2026 · Development app 0.3.0 (7) · Branch `native/0.3.0-internal`

The core candidate is `eb131cec767130979d33393f9ae467a08cf2160d`. The separate screen probe has its own source revision, `a8addd67d288701063524aa674fc7f0745ff1c36`. The intervening diff affects only the probe. The last verified physical installation was **0.2.2 (6)** from `41bc092a3007fec03a79b7ab1d47a305d131e920`. The execution ledger records evidence and outstanding work for each of the plan’s 166 tasks. [Task ledger](execution.tsv) · [Plan](../native-0.3.0-plan.md)

In the ledger, **source-implemented** means the named paths contain the behavior. **tests-authored** identifies assertions awaiting an applicable execution receipt. **package-passed** and **passed** identify observed checks at the cited revision. **partial**, **blocked** and **deferred** retain the missing evidence or product decision in the final column.

## Core behaviors

| Workflow | Scope of the candidate |
| --- | --- |
| Room | On entering a ready, idle room, discover saved Hue Entertainment positions and show matched fixtures. Preview and save positions locally. A separate sweep preview assigns phases to eligible moving fixtures. The app reads membership from the Hue Bridge. Apple Home geometry, ordinary-room coordinates and ongoing two-way layout sync are unavailable. |
| Studio | Rehearse an actual room or the offline sample, scrub the timeline, step through cues, inspect fixture targets and edit a mix. Native Live uses the same frame planner and bounded REST transport. Rehearsal values model the commands. Physical position, timing and emitted light require device observations. |
| Dynamic inputs | Preview an explicit microphone or local audio/video choice. Use audio level and current video tint within the existing caps. Stored Reduce Light Motion and the system Dim Flashing Lights preference govern reactive output. The main app supports Engine, Microphone and Local media. Cross-app capture remains in the separate probe. |
| Files | Export a whole setup or individual designs, preview per-section changes, choose specific compatible room layouts, inspect migration warnings, and explicitly import. Durable sections use a local transaction. The guide describes what persists as a mix and what reimporting a draft restores. Pairing credentials, consent, the physical recovery journal and media remain private. [Setup format](../native-setup-format.md) |
| Emergency and restore | Preempt and drain the writer, capture eligible fixtures before idle Off, retain pending baselines, and check saved power, brightness and the active XY or mirek before resolving a restore. Physical readback, including partial failures, requires the actual Bridge. |

## Build and test receipts

Linux ran Node 22.23.1 and pnpm 10.17.1 with the frozen lockfile at the exact core revision. All **201 JavaScript tests**, the **eight focused native-parity tests**, TypeScript, timing, and both pinned Scriptable bundle checks passed. Regenerating the engine and catalog produced zero tracked changes. The graph validator found 166 tasks, including 123 core tasks, and its eight tests passed at the core freeze. The later evidence-board revision passed ten graph and board tests. Chromium rendered the generated HTML at desktop and phone widths and verified status filtering, search and dependency navigation.

During integration, Xcode 27.2 (27B52) ran 112 Apple package tests at `3427fee`, 120 at `d30106f`, and 125 at `7e74c08`. At `7e74c08`, the generic iPhoneOS app, app tests and UI tests built. The development app and independent smoke runner also passed strict code-signature checks. The superseded Release archive and pre-manifest probe build were stopped to prioritize the frozen revisions. These results are specific to the indicated development commits.

On the frozen core, XcodeGen 2.46.0 generated the app and both standalone projects. The full Apple package run used warnings as errors, complete Swift concurrency checking and two build jobs. The last retrieved output showed compilation at step 34 of 73. Mac command and direct file reads subsequently timed out. The alternate desktop connector also returned an internal error. The queued operations only build or verify local artifacts and attempt isolated Mac-hosted model tests. Their final outcomes are unknown. That observation establishes neither a compiler error nor a test result. Exact-source package execution, app and UI execution, final signatures, the unsigned Release archive and the final signed probe remain open until their receipts can be inspected.

Local results are staged under the directory named by `ios/DerivedData/qualification/current-030-path` on the source Mac. The core uses `eb131cec` and the probe uses `a8addd67`. Each stage’s `.exit` file and its corresponding log record the command outcome. For the package extract distinct XCTest methods and skips, confirm the schema-2 fixed-11 512-frame method and the process-death case, and retain the actual assertion failure if either fails. Expected digest **`a0f636b65b3523d581179377f7164f06973a8b9d46ca0fafe8959a606a0900cb`**. The paired-device and Mac-hosted test paths use distinct bundle identities. Only the paired-device runner can produce the build 7 phone browse receipt.

The build 6 transfer oracle contains ten files generated by the historical Swift codec on Xcode 27.2. Its manifest SHA-256 is `39cd556120966f39ebeb3a4eee830b5dd56f4eaf76d4fa5c8b8eab545aff4abd`. The separate hand-authored household fixture contains two rooms and ten fixtures. Its SHA-256 is `4084f20d234c0924672cefe2e08b6d22bb49d52bce08124e8d29351fab129426`. [Build 6 fixture provenance](../../fixtures/native-transfer/build6/README.md)

## Privacy review

The core app uses its own UserDefaults domain and stores the Bridge application key separately in Keychain. Its manifest declares UserDefaults reason `CA92.1`, no tracking and an empty collected-data list. The Info.plist explains microphone and local network access. Discovery can contact the public Philips Hue broker as well as Bonjour. The broker receives ordinary connection metadata. Pairing, inventory and playback use the local Bridge. Media analysis retains derived levels or tints. An explicit Files export goes to the user’s chosen provider and may contain selected room layouts and fixture references.

The probe uses separate screen and app-audio stream outputs, has no Bridge writer, and declares local elapsed-time measurements under System Boot Time reason `35F9.1`. This review covers source and the specifically identified artifacts. Actual capture permissions, protected content, app switching, background continuity, resource measurements and physical playback each need their own device evidence. [Probe scope](../../ios/ScreenInputProbe/README.md)

## Physical qualification decision

Hold the installation and physical qualification of build 7. During this execution, both Apple's CoreDevice and xcdevice discovery exceeded bounded timeouts. CoreSimulator discovery also timed out and its launch process remained in an uninterruptible kernel wait. The coordinator issued no Mac restart, phone installation, credential change or lighting command. The original backup was present at reconciliation. The earlier six-fixture restore permission concerned a previous journal and run.

A fresh paired-device identity and checked pre/post state are required before interpreting a browse result. The independent runner must report a positive audit activation marker, complete the four-tab, search/keyboard, Room, Studio and Files assertions, and record the write-attempt count. Remaining hands-on checks include VoiceOver, Dynamic Type, reduced motion, room orientation, real microphone and file permissions, and separately authorized lighting and restoration runs. High-rate Entertainment streaming, gradient-strip editing and saved Hue scene copying remain outside the candidate. [DeviceSmoke](../../ios/DeviceSmoke/README.md) · [Physical checks](../../ios/DEVICE_TESTING.md)
