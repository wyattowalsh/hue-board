# Background playback

Hue Board 5.2.0 adds **Keep playing when I leave** in **Scenes**, **Studio**, and **Settings → App & recovery**.

- **Off (default):** Play uses the interactive multi-light controller; keep Scriptable open and the iPhone awake.
- **On:** Play uses a supported Hue Bridge dynamic palette from the outset; when the Bridge confirms the recall, the iPhone can lock or switch apps. The scene runs independently on the Bridge.
- **Toggle on during live playback:** Hue Board attempts the Bridge handoff immediately while the application is foregrounded. Wait for the accepted/Bridge status before leaving. If the area or fixtures do not support native dynamics, no background-capability claim is made and the existing live show remains foreground only.
- **Cue sequences:** need an active controller and cannot run in this mode; disable the preference to run them. Native scenes cannot reproduce the exact Studio geometry, per-light gain envelopes, gradient choreography, audio reactivity, or custom cue timeline.
- **Turning the preference off:** changes future playback only. It does not stop an already delegated Bridge scene. Use **Stop Bridge** to stop that scene.
- **If unavailable:** choose a Hue room or zone containing compatible color/dynamic lamps. The virtual All lights view cannot be recalled as a Hue scene. Prior restore points and per-light ceilings remain preserved.

**Why not handoff only when iOS backgrounds?** Scriptable and WebView JavaScript can be suspended when the application leaves foreground. A `visibilitychange`/`pagehide` callback is not a reliable opportunity to finish multiple authenticated network requests. Hue Board starts Bridge playback *while the application is active* whenever that setting is enabled.

No microphone use, background service, or Hue Entertainment/DTLS streaming is added. The current Scriptable HTTP transport relaxes certificate validation on the home LAN; use only trusted Wi-Fi. API readback is not physical-output telemetry.
