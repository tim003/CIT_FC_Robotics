# Architecture — CIT_FC Robotics

The technical spine of this project: what the system is, how the parts fit
together, and which constraints are settled. Detail lives under `docs/`; this
file holds the shape and the reasoning.

**Read this first.** If something here contradicts a document under `docs/`,
this file is wrong and should be fixed — but say so rather than silently
diverging.

---

## What this is

A swarm-capable, AI-driven adaptation of the [Sesame
robot](https://github.com/dorianborian/sesame-robot) — an open-source ESP32
quadruped with eight servos and an expressive OLED face.

Two things distinguish this project from upstream:

1. **Different wiring.** Upstream's three approaches all assume either a Sesame
   Distro Board (which we do not have) or dense point-to-point hand wiring. We
   use a **PCA9685** 16-channel PWM driver instead, which moves all servos onto
   I2C, frees eight GPIOs, and leaves spare channels for expansion.
2. **Designed for swarms.** Each robot is intended to sense the relative
   position of its peers, enabling group behaviour. This drives every reservation
   decision in the pin budget.

## Subsystems

| Subsystem | Component | Interface | Notes |
|---|---|---|---|
| Compute | Lolin S3 Mini (ESP32-S3) | — | Dual-core, BLE, Wi-Fi FTM capable |
| Actuation | PCA9685 → 8× MG90 servos | I2C `0x40` | ch0–7 legs; ch8–15 spare |
| Display | SSD1306 128×64 OLED | I2C `0x3C` | Shares the bus with PCA9685 |
| Power | LM2596S buck + USB-C, SPDT-selected | 5V rail | Star topology |
| Sensing *(reserved)* | UWB module, unpopulated | SPI, 8-pin header | DWM1000/DWM3000 agnostic |
| Comms | ESP32-S3 Wi-Fi radio | — | RSSI baseline, FTM precision |

## Design invariants

Violating any of these is a bug, not a style choice.

1. **Servo current never flows through the ESP32.** The PCA9685 `V+` and the
   ESP32 `5V` pin are separate branches from the rail node.
2. **PCA9685 `VCC` (3.3V logic) and `V+` (5V power) are different nets.**
   Connecting them feeds 5V into the logic side.
3. **UWB `RSTn` is open-drain — driven low or left floating, never driven
   high.** True of both DWM1000 and DWM3000; driving it high damages the module.
4. **The LM2596S is adjusted to ~5.2V before any load is connected.** These
   modules ship at arbitrary output voltages.
5. **Servo channel *order* matches upstream's `servoPins[8]` indexing.** This is
   what keeps existing animations and Sesame Studio working.
6. **The netlist is the source of truth.** Diagrams illustrate; the netlist is
   what you wire from and what gets reviewed.

## Interfaces between subsystems

- **MCU ↔ actuation/display:** a single I2C bus, `SDA GPIO35` / `SCL GPIO36`.
  Two devices, distinct addresses. Adding an I2C sensor later needs no new pins.
- **MCU ↔ sensing:** SPI on GPIO 10–13 plus three control lines, exposed as an
  8-pin header. Unpopulated today.
- **Power ↔ everything:** one 5V rail, branched in a star, with a single ground
  star point.

## Roadmap

**Now — wiring.** Produce a complete, buildable wiring specification. No
firmware, no PCB.

**Next — firmware adaptation.** Replace direct GPIO servo control with PCA9685
driving. Isolated to `setServoAngle()` and initialisation; animation data is
untouched.

**Then — positioning.** Wi-Fi FTM first (no BOM cost, ~1–2m). UWB second
(~10cm) when the header is populated. Complementary layers, not alternatives.

**Later — swarm behaviour.** Inter-robot coordination built on the positioning
layer. Deliberately undesigned; the point of the reservations is that this stays
open.

## Deliberately out of scope

Recorded so they are not mistaken for oversights: IMU, audio, camera, battery
fuel gauge, mesh protocol design, custom PCB. The pin budget leaves 14 free
GPIOs (9 ADC-capable) and I2C headroom, so none of these forces a redesign.

## Constraints that are settled

These were decided deliberately; reopening them means revisiting the spec.

- **Lolin S3 Mini**, not S2 — BLE and Wi-Fi FTM are needed for the swarm goal.
- **Dual-source power** with physical source selection, not diode-OR.
- **Part-agnostic UWB header**, not a committed part.
- **Markdown + netlist** as schematic format, KiCad-ready but not KiCad-first.
- **Fresh repo**, upstream referenced rather than forked.

Full reasoning: [`docs/superpowers/specs/2026-08-28-pca9685-wiring-design.md`](docs/superpowers/specs/2026-08-28-pca9685-wiring-design.md).

## Relationship to upstream

Branched from `dorianborian/sesame-robot` @ `86d2bf8` (`main`). We do not merge
from upstream: servo control diverges structurally, so merges would conflict
permanently. Changes are tracked in `docs/upstream/divergence.md`.

Upstream remains the authority for CAD, STLs, printing, and the animation
format. Its large binary assets are deliberately not vendored here.
