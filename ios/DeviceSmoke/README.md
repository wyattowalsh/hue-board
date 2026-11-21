# Existing-installation device smoke check

This separate XCTest runner activates the already-installed
`com.wyattowalsh.HueBoard.dev` app. It has no app-target dependency and does not
reinstall Hue Board or reset its pairing/preferences.

The build 5/6 comparison test navigates Lights, an individual-light sheet, Scenes, Studio, and Room.
It checks a known search result, an empty result, clearing and dismissing the
keyboard, Studio's preview and editing sections, and Room's fixture controls.
The comparison supports build 5’s navigation-bar search and build 6’s inline search and position sliders. The candidate uses the selectors below. All checks use browsing controls.

## Run

Use Xcode 27.2+ and XcodeGen 2.46.0+. Keep the paired phone unlocked.
Supply the device identifier and signing team through your local environment.
Keep both local.

```sh
cd ios/DeviceSmoke
: "${HUE_BOARD_DEVICE_ID:?Set your connected device identifier}"
: "${HUE_BOARD_DEVELOPMENT_TEAM:?Set your signing team}"
xcodegen generate
xcodebuild -project HueBoardDeviceSmoke.xcodeproj -scheme HueBoardDeviceSmoke \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData DEVELOPMENT_TEAM="$HUE_BOARD_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration build-for-testing
```

Before each run, identify the exact installed version and build. Verify a fresh
on-device state copy and confirm valid checksums, idle playback, and no recovery
journal or live-session descriptor. Keep preserved recovery backups intact.

Start a fresh process for the installed Debug app with `HUE_BOARD_WRITE_AUDIT=1`
in its environment and keep the console capture running. Confirm the
`HUE_BOARD_WRITE_AUDIT_ACTIVE` marker before browsing. A fresh process starts in
Lights with the default Scenes query and filters. The runner activates that
process and checks the initial catalog count.

```sh
mkdir -p Results
xcodebuild -project HueBoardDeviceSmoke.xcodeproj -scheme HueBoardDeviceSmoke \
  -configuration Debug -sdk iphoneos -destination "id=$HUE_BOARD_DEVICE_ID" \
  -derivedDataPath DerivedData DEVELOPMENT_TEAM="$HUE_BOARD_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:HueBoardDeviceSmoke/BrowseExistingHueBoard/testBrowsePairedInstallationWithoutLightActions \
  -resultBundlePath Results/Browse.xcresult test-without-building
```

Use a new result path for each run and retain earlier failures for diagnosis.
Export labeled screenshots to an ignored results folder.

```sh
xcrun xcresulttool export attachments --path Results/Browse.xcresult \
  --output-path Results/Browse-attachments
```

Review search screenshots with the keyboard visible, then check scrolling,
clipped content, and Room position controls. Check VoiceOver, accessibility
text sizes, and iOS Reduce Motion on the same installed binary.
Verbose failure diagnostics are disabled because their optional device
collection stalled in the source session. Assertions and screenshot attachments
remain enabled.

## Candidate selectors

Use the existing-installation selector above for the build 6 comparison. The
following selectors target the new candidate. Use one complete selector as
the value of `-only-testing` per run and give each run a new result path.
Identify the installed artifact and start a fresh audited Debug process for
each selector. Preflight and verify post-state as described above.

| Selector under `HueBoardDeviceSmoke/` | What it exercises |
| --- | --- |
| `BrowseCurrentWorkspace/testInspectLightsSearchScenesAndInspectRoomWithoutLightActions` | Opens an individual light, tests empty and matching scene searches, dismisses the keyboard and opens scene details. Opens Cue sequence and Saved mixes in Studio, then inspects Room position and output controls. |
| `BrowseRoomDiscovery/testBrowseSavedRoomLayoutsWithoutLightActions` | Opens Room and waits for the Bridge inventory. A match opens a preview and cancels. An empty or nonoverlapping result has its own screenshot. Match and orientation qualification requires a room with a known saved Entertainment layout. |
| `BrowseStudioRehearsal/testStepRoomRehearsalWithoutLightActions` | Opens the room rehearsal, steps the preview clock forward and back to zero, and opens the accessible fixture target list. Use a paired room with fixtures. |
| `BrowseStudioInputsAndSetup/testBrowseInputChoicesAndSetupWithoutLightActions` | Inspects the input choices, selects Audio or video file, cancels the system picker and returns to Patterns. Opens Export file → Export setup, changes the draft switch in the export form and cancels. Opens Import and cancels without selecting a file. |

On a paired personal installation these selectors browse, change transient
view state and cancel local previews. Keep attachments in private storage.
The picker checks leave personal media and setup files unopened. Microphone
permission, sensor readings, hardware output and restore have separate tests.

Use a simulator or an isolated test profile with synthetic fixture names, media,
setup files and limits for the full import and local-edit demonstration. On that
profile save the matching positions, scrub a two-cue rehearsal, preview the
synthetic local clip with the microphone off, export, and compare the local
data to the expected changes. Keep the write audit active through the entire
demonstration. A paired user's local layout or draft requires specific approval
for those edits and a verified way to return to its original state.

## Evidence limits

For the no-write result, match the confirmed audit activation marker and zero
write-attempt markers to the process that ran the completed assertions. Verify
fresh on-device checksums and idle playback without recovery or live-session
records after browsing. Keep app data and raw evidence local because
screenshots and XCTest diagnostics can include private Bridge details. Results,
generated projects and build products are ignored.

See the native README for the exact installed version, observed runtime results,
and remaining release gates. [Candidate evidence](../README.md#installed-candidate-evidence)
