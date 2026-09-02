# Upstream divergence

What this project changed relative to the Sesame robot it forked, and what it
deliberately did not.

## Branch point

[`dorianborian/sesame-robot`](https://github.com/dorianborian/sesame-robot) @
`86d2bf8` on `main`.

**We do not merge from upstream.** Servo control diverges structurally: PWM
generation has left the MCU entirely and moved to a PCA9685 on I2C. Upstream
firmware is a reference to read, not a branch to merge. Cherry-pick specific
fixes by hand if they are worth having.

## Firmware changes required

Not yet implemented — the project is still in its wiring phase. This is the
blast radius a future firmware task inherits, recorded now so it does not have
to be rediscovered.

| Upstream symbol | Change |
|---|---|
| `setServoAngle()` | Rewritten. Drives PCA9685 channels over I2C instead of `ESP32Servo` |
| `servos[i].attach(servoPins[i], 732, 2929)` × 8 | Removed. Replaced by a single PCA9685 initialisation |
| `I2C_SDA` / `I2C_SCL` defines | Repointed to GPIO2 / GPIO3 |
| `ESP32PWM::allocateTimer()` × 4 | Removed. PWM generation no longer happens on the MCU, so the timers are not needed |

The `attach()` calls carried upstream's pulse-width bounds as raw timer counts
(`732`, `2929`). Those numbers do not transfer — the PCA9685 expresses pulse
width as a 12-bit count against its own PWM frequency. They must be
recalculated for the new part, not copied.

Also note there is no official `pins_arduino.h` variant for the ESP32-S3 Super
Mini, so `Wire.begin(2, 3)` must be called explicitly rather than relying on
framework defaults. See [../wiring/pin-map.md](../wiring/pin-map.md).

## Deliberately unchanged

These stay portable, and keeping them portable was a design goal rather than a
happy accident:

- `face-bitmaps.h`
- `movement-sequences.h`
- the face and animation engine
- the JSON API
- Sesame Studio compatibility

**All of this works because PCA9685 channel ordering preserves upstream's
`servoPins[8]` indexing.** Channel *n* drives the leg that upstream's
`servoPins[n]` drove. Animation data is authored against those indices, so
existing sequences and anything produced by Sesame Studio keep working with no
translation layer.

That constraint is recorded in the [netlist](../wiring/netlist.md), rows
19–26. Reordering the servo channels to tidy the harness would silently break
every existing animation — the wiring would be fine and the robot would move
wrongly.

## Hardware divergence

Summarised in [`hardware/bom.md`](../../hardware/bom.md). The short version:
the Sesame Distro Board is gone, replaced by a PCA9685 plus an explicit power
chain, and the MCU is an ESP32-S3 Super Mini.
