# Physical-light safety contract

Hue Board distinguishes interface motion from emitted-light motion. System Reduce Motion affects interface animation. **Reduce Light Motion** changes Hue Board's dynamic lighting policy.

## First-use consent

Before the first Bridge Play or Ambient Live session, Hue Board presents a dynamic-light warning. Continuing stores only a local acknowledgement in an integrity-checked safety envelope. Canceling sends no physical command.

The warning tells users to start at low brightness, avoid looking directly at lamps, keep emergency off available, and stop immediately if anyone feels discomfort.

## Conservative defaults

- Dynamic brightness defaults to a maximum of 80% and is user-adjustable from 10–100%.
- Ordinary static power and brightness controls are not capped by the dynamic setting.
- Reduce Light Motion caps engine speed, energy, depth, tension, and effect speed, removes phase offset, and uses longer REST transitions.
- Bridge-owned scenes may still animate according to Bridge capabilities. Hue Board states this limitation rather than claiming that the setting controls Bridge firmware motion.

## Emergency behavior

`Turn off now` remains available during playback. It cancels Hue Board's active writer lease, targets only eligible lights in the selected or recoverable scope, reports unresolved lights, and retains the restore baseline.

## Limits

These controls are a conservative product policy, not a medical certification or guarantee. The supported physical-light envelope still requires real-device and real-fixture qualification under issues #4, #17, and #18.
