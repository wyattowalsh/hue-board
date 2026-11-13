# One-command iPhone qualification

Hue Board's native runner verifies source, generates the Xcode project, builds with automatic signing, installs the app, and launches it on one configured iPhone. It never pairs a Hue Bridge, changes lights, weakens TLS, stores a Hue application key, or publishes a release.

The release-qualification path requires:

- macOS;
- Xcode 27.2 or newer;
- iPhoneOS SDK 27.2 or newer;
- an Apple Account configured in Xcode;
- an Apple Development signing identity;
- one paired, trusted, unlocked iPhone with Developer Mode enabled;
- the current iPhone-portrait-only Hue Board target.

## Configure once

From the repository root:

```sh
cp ios/device.env.example ios/device.env
```

Fill in the local, Git-ignored file:

```make
HUE_BOARD_TEAM_ID=YOUR_TEAM_ID
HUE_BOARD_DEVICE_ID=YOUR_PROVISIONING_UDID
HUE_BOARD_BUNDLE_ID=com.wyattowalsh.HueBoard.dev
```

Find the Team ID in **Xcode > Settings > Accounts**. Find the Provisioning UDID in Xcode Device Hub or with:

```sh
xcrun devicectl list devices
```

Use a unique reverse-DNS bundle identifier if the default is unavailable to your team.

## Fail-fast qualification doctor

Before a signed build:

```sh
cd ios
make iphone-preflight  # display toolchain, signing identities, and visible devices
make iphone-doctor     # strict sanitized qualification check
```

`iphone-doctor` fails before any build when:

- Xcode or the active iPhoneOS SDK is older than 27.2;
- Team ID, device ID, or bundle ID configuration is invalid;
- no Apple Development signing identity is visible;
- `devicectl` cannot see the configured iPhone.

It writes `ios/DerivedData/device/preflight.txt`. The report records the commit, clean-tree status, toolchain, SDK, bundle ID, supported surface, and pass/fail presence checks. It intentionally excludes the Team ID and device identifier.

The doctor performs no source build, network pairing, or Hue operation.

## Build, install, and launch

With the iPhone connected, trusted, paired, unlocked, and visible:

```sh
cd ios
make iphone-run
```

The command performs:

1. the strict qualification doctor;
2. frozen pnpm dependency installation;
3. verification of the currently published Scriptable artifact;
4. source and generated-asset builds;
5. native contract drift checks;
6. Node, timing, and shared Swift package tests;
7. pinned XcodeGen project generation;
8. an automatically signed Debug build for the exact configured iPhone;
9. installation with `devicectl`;
10. launch of the configured bundle ID.

Evidence is written under `ios/DerivedData/device/`:

```text
preflight.txt
HueBoard.xcresult
Build/Products/Debug-iphoneos/Hue Board.app
```

## Individual commands

```sh
make iphone-preflight       # descriptive toolchain/device listing
make iphone-doctor          # strict sanitized qualification gate
make iphone-prepare         # source checks, generated assets, Xcode project
make iphone-list            # devicectl and Xcode destinations
make iphone-simulator-build # unsigned generic simulator compile
make iphone-build           # doctor + signed physical-device build
make iphone-install         # install an existing device build
make iphone-launch          # launch the installed app
make iphone-open            # generate and open the Xcode project
make iphone-run             # doctor + prepare + build + install + launch
```

Select a nondefault Xcode without changing system `xcode-select`:

```make
HUE_BOARD_XCODE_PATH=/Applications/Xcode-beta.app
```

## User-controlled steps

Automation cannot approve:

- trusting the Mac on the iPhone;
- enabling Developer Mode and restarting the iPhone;
- signing in to an Apple Account in Xcode;
- device-registration or provisioning prompts;
- Local Network permission in Hue Board;
- pressing the physical Hue Bridge button before pairing.

After launch, follow [`DEVICE_TESTING.md`](DEVICE_TESTING.md). Start with no-write-on-open, one low-risk room, restrained brightness, automatic Bridge Play, and explicit baseline restoration.

The runner does not use `sudo`, pipe remote scripts into a shell, alter system Xcode selection, or bypass signing, TLS, recovery, and release gates.
