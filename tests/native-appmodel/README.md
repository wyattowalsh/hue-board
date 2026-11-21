# Linux AppModel checks

Run the following command from a Hue Board checkout with Docker available. From another directory, pass the absolute path to the same script.

```sh
sh tests/native-appmodel/run.sh
```

Docker uses the pinned Swift 6.2.3 Noble image and downloads it on first use if needed. The script mounts the checkout read-only and builds a temporary Swift package with two jobs in a network-isolated container. It runs the original app XCTest files against the shipping AppModel extensions, persistence and recovery actors, settings codecs, playback coordinator and Bridge client. The exit status reports the test result. Docker removes the container and temporary build files on exit.

The 0.3.0 selection exercises 25 tests across eight app suites. Coverage includes partial restore readback, foreign and unaccepted baselines, single-file and multi-room setup transfers, recovery-aware import at cold launch, room discovery and layout persistence, consent, emergency preemption and safety editing. The suite uses synthetic household data.

The harness supplies stand-ins for JavaScriptCore, Keychain, Bonjour, microphone capture, media playback, background scheduling and the system Dim Flashing Lights preference. Unsupported engine, hardware and credential operations stop the test if invoked. A CryptoKit adapter exposes the repository’s portable SHA-256 implementation for room-scope matching. The runner explicitly skips the room sweep test that renders a frame through JavaScriptCore. Apple UI, engine rendering, native audio/video, device storage and physical lights need their native qualification runs.

On Linux with Swift 6.2 or later and a matching JavaScriptCoreGTK `jsc` executable and library installed, run the extended selection locally:

```sh
sh tests/native-appmodel/run.sh --jsc
```

This adds the skipped room sweep and four rehearsal cases, for 30 cases across ten suites. It checks the bundled engine against its manifest, samples the actual JavaScript and converts its colors to Hue XY. The test adapter starts a fresh process per evaluation. These checks cover deterministic frame values. Apple’s JSContext integration and its performance require a separate Apple-runtime check. The host run requires no network or Docker. It uses a temporary package and preferences directory. `HUE_MODEL_JSC` can select a different executable, and `HUE_MODEL_JSC_LIBRARIES` can point its child process to an extracted library directory. The default Docker selection continues to reject any engine evaluation.
