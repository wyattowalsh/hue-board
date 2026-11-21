# iPhone screen and app-audio probe

An isolated iOS 27+ development app measures one source selected through Apple’s system content-sharing picker. An in-app run uses `presentForCurrentApplication()`. A full-display run uses `present()`. The app attaches exactly one stream output. Screen color uses `.screen` with audio capture disabled. App audio uses `.audio` with audio capture enabled. Both picker configurations hide the microphone and camera controls. A returned filter requesting either input ends the trial. [Apple iOS capture sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios) · [Stream output types](https://developer.apple.com/documentation/screencapturekit/scstreamoutputtype)

The probe has its own bundle ID and container. Its target has zero dependencies on Hue Board, Keychain or the Bridge. The only background mode is `screen-capture` for full-display trials. The target consumes incoming sample buffers during the callback and keeps one derived RMS or RGB reading. Stop and stream failures clear that reading. Aggregate counters survive until the next run. A user can play the in-app synthetic tone at their chosen device volume. The probe creates no media files.

## Build and qualification status

Use a two-engineering-day investigation for the optional screen lane. Source and build receipts belong to the exact probe revision. A checked build or an available SDK symbol establishes no cross-app, background or lighting behavior. At implementation handoff, device trials X06–X08 were **pending**. The last recorded connection stalled in CoreDevice before the Hue Board browse check. Confirm current phone capabilities and access independently before a run. Hue Board’s shipping candidate and its microphone and Files modes have separate evidence.

From the repository root, the build coordinator can generate and compile this target with Xcode 27 or later and XcodeGen:

```sh
(cd ios/ScreenInputProbe && xcodegen generate)
xcodebuild -project ios/ScreenInputProbe/HueBoardScreenProbe.xcodeproj \
  -scheme HueBoardScreenProbe -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ios/DerivedData/screen-input-probe \
  CODE_SIGNING_ALLOWED=NO build
```

For a separately authorized iOS 27+ phone trial, sign and install this bundle under its own identity. Record the binary hash, derived Info.plist, signing outcome, OS and scope privately. Its app ID is `com.wyattowalsh.HueBoard.ScreenInputProbe`. Leave the paired Hue Board installation and preferences in place.

Inspect the probe bundle’s `PrivacyInfo.xcprivacy` alongside its Info.plist. The probe uses system uptime for elapsed capture, sample-age and stop measurements. Its manifest declares `NSPrivacyAccessedAPICategorySystemBootTime` with reason `35F9.1`, empty collected-data and tracking-domain lists, and tracking disabled. The probe keeps uptime values on the device. [Apple’s allowed reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)

## Device matrix

1. Select **This app → Screen color → Choose content**. Cancel the picker once and verify Idle. Repeat and grant the selection. Toggle between red and blue synthetic panels. The average color should shift toward the selected panel while playback remains silent. A valid black picture is a measurement.
2. Select **This app → App audio** and grant the selection. Keep the picture static. Compare silence with **Play two-second test tone**. Each reading is linear normalized RMS. Confirm that a tone can affect the result with microphone and camera controls absent. A valid silent sample is zero. Missing or unsupported audio is displayed as **Unavailable**.
3. Repeat each source under **Full display** with a controlled, unprotected second app showing the synthetic colors or playing the tone. Keep the probe backgrounded during the source changes. Use a controlled sequence and check the terminal background-only counters. Screen trials count red-dominant and blue-dominant samples (channel margin above 20/255). Audio trials count quiet RMS below 0.002 and reference signal RMS above 0.015. These counts exclude samples presented before the probe backgrounded. The UI shows a live reading, and the terminal receipt retains only aggregate counts. A signal from the probe’s own test source only qualifies the in-app case. Label unavailable or unobserved cells explicitly.
4. Use system Stop Sharing, picker cancellation, app Stop, lock and a content interruption. End any remaining sharing from iOS if the UI reports **Stop unconfirmed**. Intake closes before waiting for stream teardown. Test content-provider restrictions through ordinary sharing controls. A blank frame or silence alone cannot classify content as protected. A new trial always begins with a fresh system selection.
5. Repeat the permitted source for ten minutes. Record seen, delivered, throttled, unavailable and stale readings, maximum reduction time, elapsed time, CPU and peak RSS. Peak RSS is the process lifetime high-water mark in bytes. For an isolated comparison relaunch between runs. Complement the aggregate CPU value with an Instruments trace if investigating a spike. Record thermal state and user/system stop-to-drain latency.

The callback queue performs synchronous reduction, throttled to four eligible samples per second. Screen input requests 192 × 108 and accepts complete frames. Audio input requests one channel at 48 kHz and inspects at most 1,024 PCM samples per reading. Signals more than two seconds old expire. The null sink rejects all real output by construction. A fresh, isolated calibration checks its attempt hook moves from zero to one before each process can activate a run. Require a `PROBE_ATTEMPT_AUDIT_ACTIVE` line and its matching `PROBE_ATTEMPT_AUDIT_END` line with `attempts=0`. The probe counter measures attempts at its synthetic boundary. Production lighting, restoration and the production write audit require separate candidate tests.

Keep screen imagery, source audio and household information out of receipts. Report only the supported source, picker scope, tested device/OS, exact artifact and observed outcome. A capture-only pass can advance the feasibility decision. Production integration requires a separately frozen candidate and explicit physical qualification.
