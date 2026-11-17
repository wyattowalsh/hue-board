# Physical-light safety contract

Hue Board distinguishes interface motion from emitted-light motion. System Reduce Motion affects interface animation. **Reduce Light Motion** changes Hue Board's dynamic lighting policy.

## First-use consent

Before the first Bridge Play or Ambient Live session, Hue Board presents a dynamic-light warning. Continuing stores only a local acknowledgement in an integrity-checked safety envelope. Canceling sends no physical command.

The warning tells users to start at low brightness, avoid looking directly at lamps, keep emergency off available, and stop immediately if anyone feels discomfort.

## Conservative defaults

- Dynamic brightness defaults to a maximum of 80% and is user-adjustable from 10–100%.
- Ordinary static power and brightness controls are not capped by the dynamic setting.
- Reduce Light Motion caps engine speed, energy, depth, and tension, removes phase offset, and uses longer REST transitions. It also caps the speed value sent with Bridge Play at 0.25.
- The Bridge may still move a recalled scene after that request. Hue Board does not treat the setting as control of Bridge firmware.

## Emergency behavior

`Turn off now` remains available during playback from the playback banner on every tab and from the Lights screen, outside the everyday controls that playback disables. It cancels Hue Board's active writer lease, targets only eligible lights in the selected or recoverable scope, reports unresolved lights, and retains the restore baseline. The scene list shows a static palette illustration. That illustration does not sample the shared engine and does not write lights.

A baseline saved for a different Bridge stays visible after another Bridge connects. Everyday controls, Bridge Play, Ambient Live, emergency off, and Forget stay blocked until the original Bridge is reconnected and restored. Stop & restore is not offered against the wrong Bridge.

## Limits

A corrupt safety record is quarantined and replaced with the fail-closed settings: Reduce Light Motion on, the 80% dynamic cap, and consent required again.

These controls are a conservative product policy, not a medical certification or guarantee. The supported physical-light envelope still requires real-device and real-fixture qualification under issues #4, #17, and #18.
