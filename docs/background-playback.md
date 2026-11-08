# Background playback

Hue Board 5.2.0 adds **Keep playing when I leave** in Scenes, Studio, and Settings → App & recovery.

- **Off (default):** Play uses the interactive multi-light controller. Keep Scriptable open and the iPhone awake.
- **On:** Play requests a supported Hue Bridge dynamic palette immediately, while the application is active. After the Bridge confirms recall, it can continue when the iPhone locks or switches apps.
- **Enabled during live playback:** Hue Board attempts a Bridge handoff immediately. Wait for the accepted/Bridge status before leaving. If the chosen area or lamps do not support native dynamics, no background-playback guarantee is made.
- **Cue sequences and exact Studio choreography** need a continuously active controller and cannot run on the Bridge as implemented.
- **Turning the preference off** affects future Play actions, not an already delegated scene. Use Stop Bridge to stop existing delegated playback.
- **Unsupported scopes:** choose a Hue room or zone with compatible color/dynamic lights. The local All lights scope is not a Hue scene group.

**Why not hand off only after backgrounding?** iOS may suspend Scriptable and WebView JavaScript when an app leaves foreground. A `visibilitychange`/`pagehide` event is not a reliable opportunity to complete authenticated network handoff. This setting selects Bridge playback *before* leaving so it does not depend on continued iOS execution.

No always-on iOS service, microphone capture, or Hue Entertainment/DTLS streaming was added. API readback is not optical telemetry. On the current Scriptable transport, use only trusted home Wi-Fi because Hue's local TLS certificate verification is relaxed.
