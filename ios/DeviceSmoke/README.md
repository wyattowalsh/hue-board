# Existing-installation device smoke check

This separate XCTest runner activates the already-installed
`com.wyattowalsh.HueBoard.dev` app. It has no app-target dependency and does not
reinstall Hue Board or reset its pairing/preferences.

The test navigates Lights, an individual-light sheet, Scenes, Studio, and Room.
It checks a known search result, an empty result, clearing and dismissing the
keyboard, Studio's preview and editing sections, and Room's fixture controls.
The runner supports the earlier navigation-bar search and the current inline
search and position sliders. All checks use browsing controls.

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
text sizes, and iOS Reduce Motion on the same installed binary. The iOS setting
governs Studio section-jump animation.
Verbose failure diagnostics are disabled because their optional device
collection stalled in the source session. Assertions and screenshot attachments
remain enabled.

## Evidence limits

For the no-write result, match the confirmed audit activation marker and zero
write-attempt markers to the process that ran the completed assertions. Verify
fresh on-device checksums and idle playback without recovery or live-session
records after browsing. Keep app data and raw evidence local because
screenshots and XCTest diagnostics can include private Bridge details. Results,
generated projects and build products are ignored.

See the native README for the exact installed version, observed runtime results,
and remaining release gates. [Candidate evidence](../README.md#installed-candidate-evidence)
