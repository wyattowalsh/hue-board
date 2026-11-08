# Hue Board 5.3: automatic phone-free Play

**Play** starts a compatible Hue Bridge dynamic palette immediately, while Scriptable is foregrounded, instead of requiring the old **Keep playing when I leave** preference. On Bridge acknowledgment, the dynamic palette continues when the phone locks or the user switches apps. This default changes only the selection of playback mode after the user explicitly presses **Play**: opening Hue Board still sends **no lighting writes**.

## Which mode should I use?

- **Play / Play preset:** on real Hue rooms and zones with dynamic-capable color lamps, delegates a native Hue dynamic scene. The Bridge owns the ongoing animation. Hue Board displays the Bridge acceptance state and may display a later readback; neither proves exact optical timing.
- **Live Studio · foreground:** runs the complete procedural pattern engine from Scriptable with per-lamp spatial mapping, gradients and precise Studio envelopes. Keep Scriptable active and the screen awake. Hue Board pauses new frames when its WebView is hidden or suspended.
- **Cue sequences:** require active Scriptable. Their timeline and custom choreography cannot be transferred to the Bridge as-is.
- **Unsupported room / All lights:** Play reports a clear error without silently starting a foreground show. Choose a supported Hue room/zone, or intentionally run Studio with the phone open.
- **Unconfirmed handoff:** a lost/failed Bridge recall acknowledgment leaves a recovery marker. The UI reports that the handoff is **uncertain**, rather than claiming phone-free playback succeeded. Inspect the physical state, stop the Bridge scene when possible, and review restore points before retrying.

The old saved `continueInBackground` preference is ignored in 5.3; no Hue pairing, physical room arrangement, lamp ceiling, old restore record or migrated Keychain entry is deleted. Turning an old setting on or off does not start lights.

## Why exact Studio can't run from Scriptable when locked

iOS may suspend a backgrounded Scriptable WebView, including its JavaScript timers and local network writer. A `visibilitychange` or `pagehide` callback is **not** a dependable time to perform the authenticated Bridge handoff. Hue Board delegates while it still has network access. Native Hue dynamic scenes can continue unaided, but cannot reproduce Hue Board's spatial 24-pattern choreography, gradient envelopes, cue progression or audio-reactive logic.

Exact background choreography requires a separate continuously running controller (for example, an opt-in local companion/always-on host), or a supported native architecture with appropriately validated execution and ownership. A browser/PWA on the iPhone does not provide such a daemon. No such background service or Entertainment/DTLS streaming is part of v5.3.

## Safety and recovery

- **Stop Bridge** is explicit; opening Hue Board does not stop an existing delegated scene.
- Avoid simultaneously running multiple Hue Board or external entertainment controllers for the same lights.
- Existing fixture trim and ceiling restrictions are preserved, but a shared native palette is conservatively capped by the most restrictive participating light.
- **Restore** uses saved *static* light state, not an earlier animation; it may overwrite changes made from other apps. Review snapshot timestamps.
- Bridge response/readback is not measurement of physical emitted light.
- This Scriptable transport relaxes local Bridge TLS certificate validation. Use trusted Wi-Fi only.

Hardware/iOS validation of the actual native palette and suspension boundary is still required.
