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

## Firmware changes made

Implemented in
[`firmware/sesame-s3-pca9685/`](../../firmware/sesame-s3-pca9685/README.md),
built as a byte-identical copy of upstream's sketch with six surgical edits —
166 changed lines total. Everything below was the predicted blast radius, and
nothing outside it moved.

**Status: Stage 1 is partially verified on hardware.** It builds clean for
`esp32:esp32:esp32s3` (core 3.3.11, Adafruit PWM Servo Driver 3.0.3) at 84 % of
program storage, and the pulse geometry below is verified arithmetically. The
[colleague-built perfboard evidence](../../hardware/circuit%20layout/README.md)
verifies power-up, I2C on GPIO2/GPIO3, and movement of three servos. It does not
verify all-eight-servo operation, complete animation, or Wi-Fi in the
photographed stacked assembly. Generated wiring diagrams were retired because
they were not confirmed build evidence.

Two Makerfabs ESP32 UWB DW3000 WROOM evaluation boards were purchased on
2026-09-09 but have not arrived or been integrated. They define the selected
Stage 2 route: each Makerfabs onboard ESP32 acts as a UWB coprocessor over UART.
Exact UART GPIOs, connector pins, and power wiring are not authoritative before
delivered-board verification. Initial integration uses separate USB power and
a common signal ground; sharing the servo rail requires measured-current and
regulator-headroom approval. The [Makerfabs Stage 2 implementation
plan](../superpowers/plans/2026-09-09-makerfabs-stage2-integration.md) defines
the audit and acceptance sequence. The raw-radio SPI header remains an optional
unpopulated interface, not the selected route, and its `RSTn` protection remains
open-drain: drive low or leave floating, never drive high.

| Upstream symbol | Change |
|---|---|
| `setServoAngle()` | Rewritten. Drives PCA9685 channels over I2C instead of `ESP32Servo` |
| `servos[i].attach(servoPins[i], 732, 2929)` × 8 | Removed. Replaced by a single PCA9685 initialisation |
| `I2C_SDA` / `I2C_SCL` defines | Repointed to GPIO2 / GPIO3 |
| `ESP32PWM::allocateTimer()` × 4 | Removed. PWM generation no longer happens on the MCU, so the timers are not needed |
| `#include <ESP32Servo.h>` | Replaced by `Adafruit_PWMServoDriver.h`. `ESP32Servo` is no longer a dependency |
| — *(new)* | PCA9685 `OE` on GPIO18, held HIGH through boot and released only after the PWM frequency is programmed |
| — *(new)* | UWB pin reservations, netlist rows 27–34. `#define`s only — `pinMode()` is deliberately never called, so an unpopulated header is never driven |

### The pulse-width bounds

This is the one part of the port that is easy to get wrong, so the arithmetic
is recorded rather than left to be rediscovered.

`attach(pin, min, max)` takes **microseconds** — not timer counts — and
ESP32Servo silently clamps the top end:

```c
// ESP32Servo.h
#define MIN_PULSE_WIDTH   500
#define MAX_PULSE_WIDTH  2500
// ESP32Servo.cpp — attach()
if (max > MAX_PULSE_WIDTH) max = MAX_PULSE_WIDTH;
```

**Upstream's effective sweep is therefore 732 – 2500 µs. The `2929` never
reached a servo.** `Servo::write(angle)` then applies
`map(angle, 0, 180, min, max)` internally.

The numbers still do not transfer directly, because the PCA9685 expresses
pulse width as a 12-bit count (4096 steps per period) against its own PWM
frequency — but the conversion is exact. `setPWMFreq(50)` programs prescale
121 → 50.03 Hz → 19988 µs period → **4.88 µs per count**:

| | µs | PCA9685 count |
|---|---|---|
| 0° | 732 | **150** |
| 180° | 2500 | **512** |
| *what upstream asked for and never got* | 2929 | 600 |

Worst deviation from upstream across all 181 integer angles is **6.1 µs
(0.62° of travel)** — under a third of one step of upstream's own 10-bit LEDC
timer, which quantises to ~19.5 µs. The port is finer than the original.

**`SERVOMAX 600` is the trap.** It is the unclamped value, and it is the
obvious thing to copy from both upstream's source and the Adafruit example.
It sweeps **17.1 % further** at the top end than any existing animation was
authored for, which risks linkage bind or servo stall once legs are attached.

Sources: [`madhephaestus/ESP32Servo`](https://github.com/madhephaestus/ESP32Servo)
(`ESP32Servo.h`, `ESP32Servo.cpp`) for the clamp; NXP PCA9685 datasheet for the
12-bit resolution; Adafruit PWM Servo Driver Library 3.0.3 for the prescale
calculation.

### I2C initialisation

There is no official `pins_arduino.h` variant for the ESP32-S3 Super
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
