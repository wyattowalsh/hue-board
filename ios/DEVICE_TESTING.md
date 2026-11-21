# Test Hue Board on a physical iPhone

Use a Mac with Xcode and a paired iPhone to qualify a native development build. For an existing installation, preserve the app, pairing and recovery state. Use the [standalone DeviceSmoke runner](DeviceSmoke/README.md) for browse-only checks.

The app targets iOS 18 or later. A signed development installation establishes the build can run on that phone. The checks below qualify behavior on the tested app and hardware.

## 1. Prepare the Hue system

Before opening Xcode:

- Put the Mac, iPhone, and Hue Bridge on the same trusted home network.
- Confirm the official Hue app can discover the Bridge and control the intended test room.
- Avoid guest Wi-Fi, client isolation, VPN routing, or any network that blocks local-device traffic.
- Choose a small test room or zone. Start below 30% brightness and avoid critical household lighting.
- Keep the official Hue app available as an independent readback and recovery reference.

Hue Board does not change lights merely by opening, discovering, verifying, pairing, reconnecting, refreshing, browsing, or changing tabs.

## 2. Prepare the exact repository checkout

Use a dedicated checkout and the full candidate SHA from the qualification record.

```sh
: "${HUE_BOARD_CANDIDATE_SHA:?Set the full candidate commit SHA}"
git clone https://github.com/wyattowalsh/hue-board.git
cd hue-board
git switch --detach "$HUE_BOARD_CANDIDATE_SHA"
test "$(git rev-parse HEAD)" = "$HUE_BOARD_CANDIDATE_SHA"
git rev-parse HEAD

corepack prepare pnpm@10.17.1 --activate
pnpm install --frozen-lockfile
pnpm verify:release
pnpm build
pnpm export:ios-contract

git diff --exit-code -- \
  ios/Packages/HueBoardKit/Sources/HueBoardKit/Resources \
  ios/Packages/HueBoardKit/Sources/HueBoardAppleEngine/Resources
```

Record the commit printed by `git rev-parse HEAD` in every device-test result.

`pnpm verify:release` checks the pinned Scriptable release and `pnpm build` rewrites `dist/` locally. Generated bundle changes require a matching installer pin before publication.

## 3. Generate the Xcode project

### Simple local route

Install XcodeGen 2.46.0 or newer, then generate the ignored project:

```sh
brew install xcodegen
cd ios
xcodegen generate --spec project.yml
open HueBoard.xcodeproj
```

### Repository-pinned XcodeGen route

Use the same XcodeGen commit as CI when exact generator provenance matters:

```sh
rm -rf /tmp/HueBoard-XcodeGen
git clone --no-checkout https://github.com/yonaskolb/XcodeGen.git /tmp/HueBoard-XcodeGen
git -C /tmp/HueBoard-XcodeGen checkout 8445e778451c7e44237b90281bde622d764b0084
swift build --package-path /tmp/HueBoard-XcodeGen -c release --product xcodegen

/tmp/HueBoard-XcodeGen/.build/release/xcodegen \
  generate --spec ios/project.yml --project ios
open ios/HueBoard.xcodeproj
```

The generated `ios/HueBoard.xcodeproj` is intentionally ignored. Regenerate it after changing `ios/project.yml`.

## 4. Configure signing in Xcode

1. In **Xcode > Settings > Accounts**, sign in with the Apple Account used on the iPhone.
2. Open the **HueBoard** project, select the **HueBoard** target, then open **Signing & Capabilities**.
3. Enable **Automatically manage signing**.
4. Select your paid developer team or **Personal Team**.
5. If Xcode says the bundle identifier is unavailable, change it in the generated project to a unique development identifier such as `com.wyattowalsh.HueBoard.dev`.

A free Personal Team is sufficient for testing on your own iPhone, but its provisioning expires periodically and the app must be rebuilt and reinstalled. TestFlight and broader beta distribution require Apple Developer Program membership.

## 5. Connect and prepare the iPhone

1. Connect the iPhone to the Mac with a cable for the first installation.
2. Tap **Trust** on the iPhone if prompted and enter the device passcode.
3. In Xcode, select the iPhone as the run destination.
4. If Xcode requests device registration, allow automatic signing to register it.
5. On the iPhone, enable **Settings > Privacy & Security > Developer Mode**.
6. Restart when prompted, confirm Developer Mode after restart, and enter the passcode.
7. Return to Xcode and choose **Product > Run**, or press `⌘R`.

Xcode may offer to install the matching iOS platform support the first time the phone is selected.

## 6. First launch and Bridge pairing

Use these steps for a fresh setup. For an existing pairing, check the installed app version and preserve the current preferences and recovery backup before updating in place.

1. Launch Hue Board from Xcode and allow **Local Network** access.
2. Confirm that merely opening the app did not change any light.
3. Open **Connect Bridge**.
4. Tap **Discover Hue Bridges**.
5. Select the discovered Bridge. If discovery fails, enter the private IP or trusted `.local` name under **Manual address** and tap **Verify Bridge**.
6. Inspect the displayed Bridge ID, address, and certificate fingerprint.
7. Press the physical center button on the Hue Bridge.
8. Tap **Pair now**.
9. If pairing succeeded but inventory loading failed, use **Retry saved connection** rather than pairing again.

The first verified connection pins the Bridge certificate fingerprint and stores the Hue application key separately in Keychain. A later certificate change fails closed and requires deliberate verification.

## 7. Minimum safe device-test matrix

Perform these in order. Before any physical test in B–F, establish authorization for the specific room, fixtures, actions and restoration, and confirm support and single-writer ownership. Stop if the observed behavior contradicts the expected result.

### A. No-write and readback baseline

- Launch Hue Board with the official Hue app visible on another device if available.
- Confirm no light changes during launch, discovery, verification, pairing, refresh, or tab changes.
- Confirm rooms, zones, fixture names, power state, and brightness broadly match the official Hue app.
- Use DeviceSmoke for navigation, search, keyboard dismissal, Studio sections and Room controls on the paired installation. Capture fresh state and the Debug write audit as described in the runner guide.
- Inspect the screenshots for clipped controls and long-content reachability. Check search and Studio section jumps at a large accessibility text size. With iOS Reduce Motion enabled, verify section jumps reach the same sections without animated scrolling. Check VoiceOver labels for search, clear, the Studio section menu, and Room position sliders.
- In **Room**, use **Find saved Hue layouts** to check matching Hue Entertainment positions on an idle Bridge. Open a preview and cancel to check that the original layout stays in place. **Save positions** is a separate local edit that preserves fixture selection, phase, roles, trim and ceilings. Apple's public Home API supplies room membership, while the import reads positions from the Hue Bridge.

**Pass** when the requested assertions and visual checks pass, inventory and readback are credible, the audit is active with zero write attempts, and fresh state before and after browsing shows idle playback without recovery or live-session records.

### B. Everyday control

- Open **Lights**, select the approved room or zone, and open the individual-light sheet for one eligible fixture.
- Set draft brightness to approximately 20%. Check that moving the draft control leaves the physical fixture unchanged.
- Use the approved **Turn on**, **Turn off**, or **Apply brightness & turn on** action. Confirm the official Hue app and physical fixture reflect the accepted command.
- Use **Stop & restore** as authorized and confirm the baseline returns.

**Pass:** targeted fixtures change, unrelated fixtures remain unchanged, and readback converges.

### C. Automatic phone-free Bridge Play

- Open **Scenes**.
- Choose a restrained scene and tap **Play**.
- Wait for Hue Board to report accepted Bridge playback.
- Lock the iPhone for at least two minutes.
- Confirm the scene continues while the phone is locked.
- Unlock, inspect status, then use **Stop & restore**.

**Pass:** accepted Play continues independently of the phone and explicit restore returns the captured static baseline. A Bridge acknowledgement is not by itself proof of emitted optical output, so inspect the actual lamps.

### D. Native Live foreground behavior

- Open **Studio**.
- Check the draft preview, custom palette, saved mix and cue controls before starting a session.
- Select the approved composition, keep brightness conservative, choose the shortest available duration, and tap **Start Studio Live**. Use **Start cue sequence** for the approved cue test.
- Keep Hue Board in the foreground for several transition cycles.
- Confirm updates are smooth enough for the low-rate REST fallback and that only the selected area changes.
- Tap **Stop & restore**.

**Pass:** Native Live is bounded, interruptible, single-area, and recoverable. Do not expect high-rate Hue Entertainment fidelity.

For separately approved Live input checks, choose **Microphone** or **Local media** under Studio **Playback**. Confirm selecting the input or a local file sends no lighting commands. With the approved fixtures and brightness limit, test permission denial, changes between quiet and loud audio, video tint, and moving Hue Board to the background. Capture and media playback should stop on backgrounding. Verify the saved baseline before continuing with further lighting actions.

### E. Native Live background behavior

For animation-only Live on iOS 26 or later:

- Start Studio Live from the foreground.
- Background the app without force-quitting it.
- Observe the system continued-processing UI and Hue Board progress.
- Let the session finish or cancel it, then reopen Hue Board and restore if needed.

On iOS 18 through 25, Native Live is foreground-only. Use **Play** in Scenes for phone-free Bridge playback.

**Pass:** behavior matches the platform contract. The system may queue, cancel, or expire continued processing; force-quitting ends it.

### F. Recovery persistence

- Start Bridge Play or Native Live, then leave Hue Board and relaunch it.
- Confirm the app retains a recovery obligation.
- Use **Stop & restore**.
- Verify unresolved fixtures remain in recovery state if any restore command fails.

**Pass:** recovery survives relaunch and is never silently discarded.

## 8. Evidence to capture

Keep raw qualification evidence in ignored local storage. Record the exact source SHA, installed version and build, device model and OS, Xcode version and build, and the result for each matrix section. Keep screenshot and recording review, the audit activation and write-attempt counts, and fresh checksum/state results with that run.

Use sanitized summaries for any authorized sharing. Keep preference backups, raw console logs, screenshots with household or Bridge details, credentials, device identifiers and signing data private.

## 9. Common blockers

### Signing or provisioning failure

- Select a Team and keep automatic signing enabled.
- Use a unique bundle identifier if the default identifier is unavailable.
- With a Personal Team, reinstall when the short-lived provisioning profile expires.

### Developer Mode is missing

Pair the iPhone with Xcode first. Developer Mode appears after pairing has been initiated.

### Local Network prompt was denied

Open iPhone **Settings > Privacy & Security > Local Network** and enable Hue Board. If the app is absent, inspect the installed app and pairing state before retrying the normal permission prompt. Preserve the paired installation and recovery data.

### Bridge discovery returns nothing

- Confirm the official Hue app works on the same Wi-Fi.
- Check whether VPN routing prevents local-network access.
- Avoid a guest network or access point with client isolation.
- Use the private Bridge IP shown by the official Hue app and tap **Verify Bridge**.

### Certificate mismatch

Do not bypass the check. Confirm that the physical Bridge is the intended device. Certificate rotation or Bridge replacement requires deliberate re-verification and possibly pairing again.

### Build error around iOS 26 continued processing

Use Xcode 27.2 or newer. `make iphone-doctor` rejects an older toolchain before any build. The project deploys to iOS 18+, and its continued-processing code is availability-gated.

## 10. TestFlight later

Direct Xcode installation is the correct first step because it exposes signing, runtime, Local Network, pairing, TLS, and console failures immediately.

After the device matrix passes and an Apple Developer Program account is available:

1. Create an App Store Connect app record with the final bundle identifier.
2. Select **Any iOS Device**, choose **Product > Archive**, and validate the archive.
3. In Organizer, choose **Distribute App > TestFlight & App Store** or **TestFlight Internal Only**.
4. Upload the build, provide beta test information, and add internal testers.

Do not start external TestFlight distribution until privacy disclosures, support contact details, export-compliance answers, and the physical qualification matrix are complete.

## Official references

- Apple: Running your app on simulated or physical devices  
  https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices
- Apple: Enabling Developer Mode on a device  
  https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- Apple: Developer account and Personal Team limits  
  https://developer.apple.com/help/account/basics/about-your-developer-account
- Apple: Distributing beta builds with TestFlight  
  https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
- Philips Hue: Developer getting started  
  https://developers.meethue.com/develop/get-started-2/
