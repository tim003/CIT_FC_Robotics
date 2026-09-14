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
| Compute | ESP32-S3 Super Mini | — | Dual-core, BLE, Wi-Fi FTM capable |
| Actuation | PCA9685 → 8× MG90S servos | I2C `0x40` | ch0–7 legs; ch8 reserved; ch9–15 spare |
| Display | [MN096-12864-4 SSD1315 128×64 OLED](docs/wiring/display.md) | I2C `0x3C` | Shares the bus with PCA9685; uses the compatible Adafruit SSD1306 library |
| Power | LM2596S buck + USB-C, SPDT-selected | 5V rail | Star topology |
| Sensing *(Stage 2 selected)* | Makerfabs ESP32 UWB DW3000 WROOM | UART, pins gated | Onboard ESP32 is the UWB coprocessor; two evaluation boards purchased, not yet delivered or integrated |
| Sensing *(optional)* | Bare UWB radio, unpopulated | SPI, 8-pin header | DWM1000/DWM3000 agnostic; not the selected Stage 2 route |
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
5. **Upstream logical servo identity is preserved through an explicit
   translation.** Movement data and APIs use R1, R2, L1, L2, R4, R3, L3, L4 at
   logical indices 0–7; the verified PCA9685 channels are 4, 5, 0, 1, 7, 6, 2, 3
   respectively. Logical index must never again be assumed to equal physical
   channel.
6. **The netlist is the source of truth.** Evidence records describe tested
   assemblies; the netlist is what you wire from and what gets reviewed.

## Interfaces between subsystems

- **MCU ↔ actuation/display:** a single I2C bus, `SDA GPIO2` / `SCL GPIO3`.
  Two devices, distinct addresses. Adding an I2C sensor later needs no new pins.
- **MCU ↔ sensing (selected Stage 2 route):** UART to the Makerfabs onboard
  ESP32. The exact UART GPIOs, connector pins, logic levels, and power feed are
  not authoritative until delivered-board verification.
- **MCU ↔ bare radio (optional):** SPI on GPIO 10–13 plus control lines,
  exposed as an unpopulated 8-pin header. `RSTn` remains open-drain: drive it
  low or leave it floating, never drive it high.
- **Power ↔ everything:** one 5V rail, branched in a star, with a single ground
  star point.

## Roadmap

**Stage 1 — all eight physical PCA9685 channels and OLED labels verified
2026-09-14; production acceptance incomplete.** The
[colleague-built perfboard evidence](hardware/circuit%20layout/README.md)
verifies power-up, I2C on GPIO2/GPIO3, and movement of three servos on channels
0–2. The user's 2026-09-14 assembled-robot run of
[`firmware/test/robotics_esp32s3/`](firmware/test/robotics_esp32s3/) verified all
eight physical channels and their OLED joint labels. Complete production
animation and loaded floor operation remain pending. The production netlist, pin map, power design,
expansion notes, and assembly guide remain under
[`docs/wiring/`](docs/wiring/README.md), with the BOM delta in
[`hardware/bom.md`](hardware/bom.md). The generated wiring diagrams were
retired because they were not confirmed build evidence; Stage 1 now uses the
two raster sources and explicit evidence boundaries. Consistency is enforced
by `scripts/check-wiring-docs.sh`.

The diagnostic sketch in
[`firmware/test/robotics_esp32s3/`](firmware/test/robotics_esp32s3/) verified
the physical channel-to-joint mapping on hardware. The shared translation code
is host-tested and the production PCA9685 firmware in
[`firmware/sesame-s3-pca9685/`](firmware/sesame-s3-pca9685/README.md) compiles,
but that production sketch has not been uploaded. Animation data is untouched;
production animation and hardware acceptance remain pending. Blast radius and pulse-width arithmetic are recorded in
[`docs/upstream/divergence.md`](docs/upstream/divergence.md). Bring-up sketches
and the board acceptance test live in [`firmware/test/`](firmware/test/README.md).

**Stage 2 — Makerfabs UWB integration planned, hardware pending.** Two
Makerfabs ESP32 UWB DW3000 WROOM evaluation boards were purchased on
2026-09-09 but have not arrived or been integrated. The selected boundary uses
the Makerfabs onboard ESP32 as a UWB coprocessor over UART, with one board per
robot intended after acceptance. Exact UART GPIOs, connector pins, and power
wiring remain gated by delivered-board verification. Initial integration uses
separate USB power plus common signal ground; sharing the servo rail requires
measured-current and regulator-headroom approval. Follow the [Makerfabs Stage
2 implementation
plan](docs/superpowers/plans/2026-09-09-makerfabs-stage2-integration.md).
The optional raw-radio SPI header remains unpopulated, including its
open-drain `RSTn` protection; it is not the selected Stage 2 route.

**Later — swarm behaviour.** Inter-robot coordination built on the positioning
layer. Deliberately undesigned; the point of the reservations is that this stays
open.

## Deliberately out of scope

Recorded so they are not mistaken for oversights: IMU, audio, camera, battery
fuel gauge, mesh protocol design, custom PCB. Eleven GPIOs are assigned and the
I2C bus has address headroom, so none of these forces a redesign.

No exact free-GPIO count is published. The Super Mini is a generic module with
no official schematic, and the widely circulated third-party pinouts for it are
wrong in ways that would cost hardware — see
[`docs/wiring/pin-map.md`](docs/wiring/pin-map.md). Confirm any new pin against
the board in hand.

## Constraints that are settled

These were decided deliberately; reopening them means revisiting the spec.

- **ESP32-S3 Super Mini**, not S2 — BLE and Wi-Fi FTM are needed for the swarm
  goal. Retargeted from the Lolin S3 Mini: the Super Mini is the board the
  GPIO2/3 I2C bus was actually bench-proven on.
- **I2C on GPIO2/GPIO3**, not GPIO35/36. GPIO3 is a strapping pin, but it
  straps JTAG source selection only, gated by the `STRAP_JTAG_SEL` eFuse, which
  ships unburned. Do not burn that eFuse on these boards.
- **Dual-source power** with physical source selection, not diode-OR.
- **Makerfabs UART coprocessor** as the selected Stage 2 UWB route; exact pins
  and power await delivered-board verification.
- **Part-agnostic raw-radio SPI header** retained as an optional unpopulated
  interface, with open-drain `RSTn`; it is not the selected route.
- **Markdown + netlist** as schematic format, KiCad-ready but not KiCad-first.
- **Fresh repo**, upstream referenced rather than forked.

Full reasoning: [`docs/superpowers/specs/2026-08-28-pca9685-wiring-design.md`](docs/superpowers/specs/2026-08-28-pca9685-wiring-design.md).

## Relationship to upstream

Branched from `dorianborian/sesame-robot` @ `86d2bf8` (`main`). We do not merge
from upstream: servo control diverges structurally, so merges would conflict
permanently. Changes are tracked in `docs/upstream/divergence.md`.

Upstream remains the authority for CAD, STLs, printing, and the animation
format. Its large binary assets are deliberately not vendored here.
