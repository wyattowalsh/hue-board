# Background playback on iPhone

Hue Board supports two different ways to animate lights:

| Mode | Works after locking the iPhone? | What runs |
|---|---|---|
| **Play in background** | **Yes**, on compatible lamps | The Hue Bridge's native dynamic palette. No Scriptable loop is running. |
| **Advanced native effect** | **Yes**, where advertised | Each supported light's built-in effect, with no claim of synchronized choreography. |
| **Live Studio / cue sequence** | **No** | Procedural room-wide effects require an active, awake Scriptable controller. |

## From Hue Board

1. Select a **Hue room or zone** with compatible color lights. `All lights` is a local view, not a Hue scene group.
2. On **Lights** tap **Play in background**, or in **Scenes** pick a look and tap **Play in background**.
3. Let the app finish the one-time Bridge recall. After it reports success, you can lock the iPhone; the Bridge runs the scene.
4. To stop it, reopen Hue Board and use **Stop background**. **Restore** re-applies the static baseline saved before Hue Board modified the lights. Neither option automatically resumes a prior native effect.

The Bridge palette uses the chosen colors, **not** the exact spatial pattern, custom cue timeline, or sound input. Brightness is conservatively bounded by the lowest selected lamp trim and ceiling. Lamps assigned Task/Anchor remain static. Unsupported or streaming-owned lights are skipped or reported; no unauthorized takeover.

## Optional Shortcuts, no control deck required

Create an iOS Shortcut with **Scriptable → Run Script**, select your `Hue Board` script, and provide **Input** text:

- `background` to start the saved palette on the current room or zone.
- `background:ion-eclipse` to select and start the Ion Eclipse look's native palette.
- `stop-background` to stop Bridge playback that Hue Board previously delegated in the saved session.

Other preset IDs are listed in `src/presets.js`. Shortcuts execute one finite Bridge command and exit. They do **not** hold a persistent iOS background session. Configure and pair the Bridge in the normal app first. The Shortcuts action and saved Bridge still require permission and local network access.

## What is not possible with this build

Arbitrary continuous JavaScript timers, smooth spatial animation frames, and 12-step playlists **cannot be made reliable background processes just by enabling iOS Background App Refresh or calling Scriptable from Shortcuts**. Those need an independent always-on controller or an appropriate native transport. Hue Entertainment would be the route for frame-rate-accurate synchronized animation, but is not included here.

Bridge API acceptance is not optical telemetry. Inspect reported state and freshness after playing. Use trusted Wi-Fi: the Scriptable local transport currently disables certificate verification for Hue Bridge IPs.
