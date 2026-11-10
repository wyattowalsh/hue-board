# One-command iPhone development run

`ios/scripts/device-run.sh` automates the repeatable part of native-device testing: source verification, generated assets, pinned XcodeGen, automatic-signing build, installation, and launch. It never pairs a Hue Bridge, changes lights, disables certificate checks, publishes a release, or stores an application key.

The helper requires macOS, Xcode 26 or newer, an Apple Account configured in Xcode, and a paired iPhone with Developer Mode enabled. Apple’s tools remain the source of truth for signing and device availability.

## Configure once

From the repository root:

```sh
cp ios/device.env.example ios/device.env
cd ios
make iphone-preflight
make iphone-list
```

Fill `ios/device.env` with:

```make
HUE_BOARD_TEAM_ID=YOUR_TEAM_ID
HUE_BOARD_DEVICE_ID=YOUR_PROVISIONING_UDID
HUE_BOARD_BUNDLE_ID=com.wyattowalsh.HueBoard.dev
```

`ios/device.env` is ignored by Git. Team and device identifiers are not Hue credentials, but keeping machine-specific configuration local avoids accidental publication.

Find the Team ID in **Xcode > Settings > Accounts**. Find the device Provisioning UDID in Xcode Device Hub or in the output of:

```sh
xcrun devicectl list devices
```

Use a unique bundle ID if the default is unavailable to the selected team.

## Build, install, and launch

With the iPhone connected, trusted, paired, and unlocked:

```sh
cd ios
make iphone-run
```

The command performs these steps in order:

1. Verifies macOS, Xcode 26+, the active iPhoneOS SDK, Corepack, Swift, and Apple command-line tools.
2. Installs JavaScript dependencies with pnpm 10.17.1 and a frozen lockfile.
3. Verifies the currently published Scriptable artifact.
4. Builds the web/controller assets and regenerates the shared native contract.
5. Rejects generated native-resource drift.
6. Uses an installed XcodeGen or builds the repository-pinned XcodeGen commit.
7. Builds a signed Debug app for the exact device using automatic signing.
8. Installs the resulting `.app` with `devicectl`.
9. Launches the configured bundle ID on the iPhone.

The Xcode result bundle and derived data are stored under `ios/DerivedData/device/`.

## Individual commands

```sh
make iphone-preflight       # Toolchain, signing identity, and device visibility
make iphone-prepare         # Source checks, generated assets, and Xcode project
make iphone-list            # devicectl and xcodebuild destinations
make iphone-simulator-build # Unsigned generic simulator compile
make iphone-build           # Signed physical-device build
make iphone-install         # Install the existing device build
make iphone-launch          # Launch the installed application
make iphone-open            # Generate and open the Xcode project
make iphone-run             # Prepare + build + install + launch
```

The underlying commands are also available directly:

```sh
bash ios/scripts/device-run.sh help
```

## Selecting a nondefault Xcode

Set a local path without changing the system-wide `xcode-select` setting:

```make
HUE_BOARD_XCODE_PATH=/Applications/Xcode-beta.app
```

The helper applies that Xcode through `DEVELOPER_DIR` for `xcodebuild`, `xcrun`, and Swift commands.

## First-run interaction still required

Automation cannot approve these user-controlled steps:

- Trusting the Mac on the iPhone.
- Enabling Developer Mode and restarting the iPhone.
- Signing in to an Apple Account in Xcode.
- Accepting Xcode’s device registration or provisioning prompts when necessary.
- Allowing Local Network access in Hue Board.
- Pressing the physical Hue Bridge button before pairing.

After launch, continue with the conservative validation matrix in [`DEVICE_TESTING.md`](DEVICE_TESTING.md). Start with no-write-on-open, one low-risk room, restrained brightness, automatic Bridge Play, and explicit baseline restoration.

## Failure behavior

The helper fails before installation when:

- the host is not macOS;
- Xcode is older than 26;
- required account or device identifiers are absent;
- the published Scriptable artifact fails integrity checks;
- generated native resources differ from source;
- the device is unavailable to Xcode;
- signing or provisioning fails;
- no `Debug-iphoneos` app was produced.

It does not use `sudo`, pipe remote scripts into a shell, alter system Xcode selection, or bypass code-signing, TLS, recovery, and release gates.
