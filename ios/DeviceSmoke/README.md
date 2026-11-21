# Existing-installation device smoke check

This separate XCTest runner activates the already-installed
`com.wyattowalsh.HueBoard.dev` app. It has no app-target dependency and does not
reinstall Hue Board or reset its pairing/preferences.

The test navigates Lights, an individual-light sheet, Scenes/search, Studio,
and Room. It never presses power, Apply, Play, Start, or Stop & restore, and it
does not modify saved mixes, cues, or room layouts. It requires a connected
Bridge and no pending recovery record; it is not a restore test.

## Run

Use Xcode 27.2+ and XcodeGen 2.46.0+. Keep the paired phone unlocked.
Supply the actual device identifier and signing team through your local
environment; do not commit either or copy credentials into test source.

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

Use a new result path for each run; retain earlier failures for diagnosis.
Verbose failure diagnostics are disabled because their optional device
collection stalled in the source session. Assertions and screenshot attachments
remain enabled.

## Evidence limits

A UI pass alone does not establish that no lighting writes occurred. For that
claim, use the existing Debug `HUE_BOARD_WRITE_AUDIT=1` instrumentation, require
its positive activation marker, check zero write-attempt markers, and inspect
fresh on-device recovery/live-session state after the run. Keep app data and
raw evidence local: screenshots and XCTest diagnostics can contain Bridge
network details. Results, generated projects, and build products are ignored.

The source compiled in the earlier standalone runner, but its revised full
device pass was blocked by the locked phone. Generating this project does not
qualify its runtime behavior. See [candidate evidence](../README.md#installed-candidate-evidence)
for the actual installed version, partial checks, and remaining release gates.
