# PCA9685 Wiring Design — CIT_FC Robotics

**Date:** 2026-08-28
**Status:** Approved (design), pending implementation
**Upstream base:** [dorianborian/sesame-robot](https://github.com/dorianborian/sesame-robot) @ `86d2bf8099754fd548c7cf98ee11fc9e9cdb5092` (`main`)

---

## Purpose

Adapt the Sesame quadruped robot to a wiring approach we can actually build, and
reserve the expansion capacity needed for the project's real goal: AI-driven
swarm behaviour across multiple robots.

Upstream offers three wiring approaches. Two require Sesame Distro Boards
(V1/V3) that we do not have. The third is point-to-point hand wiring, which
upstream itself describes as producing "a lot of stray wires" and a "high
connection count." We replace all three with a **PCA9685 16-channel PWM driver**,
which moves all eight servos onto the I2C bus, frees eight GPIOs, and leaves
eight spare PWM channels for expansion.

This document specifies the electrical design only. Firmware changes and the
wiring documents themselves are downstream work.

## Goals

1. A complete, buildable wiring specification for a Sesame robot using PCA9685,
   OLED, LM2596S, ESP32-S3 Mini, and 8 servos.
2. **At least one reserved output** for future actuators.
3. **At least one reserved sensor input** for inter-robot positioning.
4. Preserve compatibility with upstream animations and Sesame Studio.

## Non-goals (explicitly out of scope)

Recorded so they are not rediscovered as "missing": IMU, microphone/audio,
camera, battery fuel gauge, inter-robot mesh protocol design, custom PCB
fabrication, and firmware implementation. The pin budget below leaves room for
all of them; none is designed here.

---

## Decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Microcontroller | **Lolin S3 Mini (ESP32-S3)** | Dual-core, BLE, more GPIO than S2; supports Wi-Fi FTM, which the swarm goal depends on |
| 2 | Power | **Dual-source 5V rail** (battery→LM2596S *or* USB-C), SPDT-selected | Bench-safe during bring-up, untethered for swarm work, no backfeed |
| 3 | UWB | **Part-agnostic 8-pin header** | DWM1000 and DWM3000 both drop in; avoids committing to an unpurchased part |
| 4 | Schematic format | **Markdown + Mermaid + netlist table**, KiCad-ready | Renders in Obsidian and GitHub, diffs cleanly, reviewable before soldering |
| 5 | Upstream relationship | **Fresh repo + documented divergence** | Servo control diverges structurally; upstream merges would conflict permanently |

---

## Architecture

### Subsystems

```
                    ┌───────────────┐
   USB-C 5V ──┐     │  Lolin S3 Mini│
              ├─SW──┤   (ESP32-S3)  │
 Batt→LM2596S─┘  │  └───┬───────┬───┘
                 │      │ I2C   │ SPI
            5V RAIL      │       │
              │    ┌─────┴─────┐ │  ┌──────────────┐
              ├────┤  PCA9685  │ └──┤ UWB header   │
              │    │   0x40    │    │ (8-pin, NC)  │
              │    └─────┬─────┘    └──────────────┘
              │          │ ch0-7        ch8-15 spare
              │     8x MG90 servos
              │    ┌───────────┐
              └────┤ OLED 0x3C │  (3V3)
                   └───────────┘
```

### Power

Single 5V rail fed by **either** a battery through the LM2596S buck converter
**or** USB-C, selected by an SPDT switch. Four rules:

1. **SPDT switch, not diode-OR.** A physical switch makes backfeed impossible
   and avoids a Schottky's ~0.3V drop, which matters when eight servos are
   already sagging the rail.
2. **Star topology.** PCA9685 `V+` and the ESP32 `5V` pin are separate branches
   from the rail node, never daisy-chained, so servo inrush cannot brown out the
   MCU.
3. **1000µF bulk capacitor** across PCA9685 `V+`/`GND`. Non-optional with eight
   MG90s.
4. **Set the LM2596S output to ~5.2V with a multimeter before connecting any
   load.** These modules ship at arbitrary voltages; connecting an ESP32 to an
   unadjusted one destroys it.

All grounds meet at a single star point.

### Buses

**I2C** — `SDA GPIO2`, `SCL GPIO3`. Shared by OLED `0x3C` and PCA9685 `0x40`; no
address conflict.

> **Changed 2026-09-02.** Previously `SDA GPIO35` / `SCL GPIO36` (Lolin S3 Mini
> defaults per the Arduino variant's `pins_arduino.h`). Moved to `2`/`3` to match
> the bench-tested wiring on the **ESP32-S3 Super Mini** — the board actually in
> hand — per Loftwork `Robotics/Design`, test `_003`. This also sidesteps the
> octal-PSRAM hazard below entirely.

**SPI** — reserved for the UWB header: `SCK 12`, `MOSI 11`, `MISO 13`, `CS 10`.
These are the board's declared SPI defaults and do not collide with I2C.

---

## Pin map

| Function | GPIO | Notes |
|---|---|---|
| I2C SDA | 2 | OLED + PCA9685 |
| I2C SCL | 3 | Strapping pin — qualified exception, see below |
| PCA9685 `OE` | 18 | Active-low. HIGH = all servos off; firmware kill switch |
| UWB SCK | 12 | |
| UWB MOSI | 11 | |
| UWB MISO | 13 | |
| UWB CSn | 10 | |
| UWB IRQ | 14 | Interrupt-capable input |
| UWB RSTn | 21 | **Open-drain + pull-up. Never drive high.** |
| UWB WAKEUP | 16 | Spare; DWM3000 only |
| UWB EXTON | 17 | Spare; DWM3000 only |
| Free | 1, 4–9, 33–40 | 9 are ADC-capable; `35`/`36` freed by the I2C move |

**Reserved — do not use:** GPIO `0` (boot button), `45`/`46` (strapping),
`19`/`20` (native USB), `43`/`44` (UART0), `47`/`48` (RGB LED).

> **`GPIO3` is a qualified exception.** Espressif does list it as a strapping
> pin, so the blanket "reserved" entry it previously carried here was
> over-conservative. `GPIO3` selects the **JTAG signal source only** — boot mode
> is set by `GPIO0` + `GPIO46`, never `GPIO3`. That role is gated behind the
> `EFUSE_STRAP_JTAG_SEL` eFuse, whose default is `0` (unburned), and "after
> reset, the strapping pins work as normal function pins." An I2C pull-up
> holding it high at boot is therefore harmless on a stock chip.
> **Do not burn `STRAP_JTAG_SEL` on these boards**; debug via USB Serial/JTAG.
> Sources: ESP32-S3 *Hardware Design Guidelines — Schematic Checklist*; ESP-IDF
> *Configure Other JTAG Interfaces*.

> **PSRAM caveat — now moot for I2C.** On ESP32-S3 boards with *octal* PSRAM,
> GPIO35/36/37 are consumed by the PSRAM bus and unusable. That hazard is
> precisely why I2C no longer lives there: `GPIO2`/`GPIO3` are free regardless of
> PSRAM configuration, so the bus is now portable across S3 variants. Keep the
> hazard in mind before reusing `35`–`37` for anything else.

---

## PCA9685 integration

**Two separate supplies, and conflating them is the most common failure:**

- `VCC` = **3.3V logic**, from the ESP32 `3V3` pin.
- `V+` = **5V servo power**, from the 5V rail.

These are different nets. Tying `V+` to `VCC` feeds 5V into the logic side.

**I2C pull-ups.** Both the OLED and PCA9685 breakouts ship with their own
pull-up resistors. Two sets in parallel roughly halves the effective resistance.
If the bus misbehaves, remove one set — document the check rather than assuming.

**Servo channel allocation:**

- **ch0–ch7** — the eight MG90 leg servos.
- **ch8** — designated reserved output (goal #2). Head, gripper, or LED driver.
  PCA9685 channels are 12-bit PWM, so non-servo loads work equally well.
- **ch9–ch15** — unallocated spare.

**Mapping compatibility:** channel order preserves upstream's `servoPins[8]`
*ordering* — upstream index 0 → PCA9685 ch0, and so on. Upstream's array is
`{1, 2, 4, 6, 8, 10, 13, 14}`; those GPIO numbers become irrelevant, but the
index order must not change. This keeps every existing Sesame Studio animation
and all of `movement-sequences.h` working untouched. Only `setServoAngle()`
changes internally.

---

## Expansion for AI / swarm

### Reserved output — satisfied

PCA9685 ch8 (plus seven more spare). No wiring change required to populate.

### Reserved sensor input — UWB header

An **8-pin, part-agnostic header**: `SCK, MOSI, MISO, CSn, IRQ, RSTn, WAKEUP,
EXTON`, plus `3V3` and `GND`.

Both DWM1000 and DWM3000 are 3.3V parts with 3.3V-logic SPI, requiring no level
shifting, and share the same six core signals. The two extra pins (`WAKEUP`,
`EXTON`) are DWM3000-only and left as no-connect for DWM1000 — two unused pins
buys freedom to switch parts without touching the harness.

| | DWM1000 | DWM3000 | Wiring impact |
|---|---|---|---|
| Extra control pins | — | WAKEUP, EXTON | Optional; deep-sleep duty-cycling only |
| Max SPI clock | ~20 MHz | ~36 MHz | None — firmware setting |
| Driver library | `DW1000`/`DW1000Ng` | Qorvo/Makerfabs DW3000 | None — zero wiring change |

> **`RSTn` is open-drain on both parts.** It must be driven **low or left
> floating**, never actively driven high. The GPIO must be configured as
> open-drain with a pull-up. Driving it high damages the module. This applies
> regardless of which part is fitted.

### Wi-Fi relative positioning — no extra hardware

Two mechanisms, tiered by precision:

- **RSSI trilateration** — works on any ESP32, but signal strength is a poor
  indoor distance proxy (multipath, body-blocking). Realistically ±3–5m.
- **802.11 FTM (Fine Timing Measurement)** — time-of-flight, ~1–2m, supported by
  ESP32-S3. Requires FTM support at both endpoints; since the swarm is all S3
  Minis, this is satisfied. **This is a direct payoff of Decision #1.**

Roadmap intent: **FTM as the always-available baseline** (no BOM cost), **UWB as
the precision layer** (~10cm) when the header is populated. Complementary, not
alternatives — FTM for coarse topology, UWB for tight formation work.

> **Power budget constraint.** The LM2596S delivers ~2A continuous in practice
> (3A peak rating). That is already sized for 8 servos + ESP32. Populating ch8
> with a 9th servo *and* fitting UWB (~150mA peak TX) requires re-checking the
> budget before running under load. Recorded here so it is designed for, not
> discovered by brownout.

---

## Deliverables

| File | Contents |
|---|---|
| `docs/wiring/README.md` | Main wiring guide; assembly order, safety |
| `docs/wiring/netlist.md` | Formal `from → to` connection table (source of truth) |
| `docs/wiring/pin-map.md` | GPIO budget and reservations |
| `docs/wiring/power.md` | Rail design, LM2596S setup, safety procedure |
| `docs/wiring/expansion.md` | Spare channels + UWB header |
| `docs/upstream/divergence.md` | Branch point and change record |
| `hardware/bom.md` | BOM delta vs upstream |

The **netlist table is the source of truth** — it is what prevents miswiring
during assembly, is human-reviewable before any solder melts, and is the exact
input a KiCad schematic needs if a custom board follows later.

### Netlist excerpt (illustrative form)

| # | From | To | Wire | Notes |
|---|---|---|---|---|
| 1 | LM2596S OUT+ | SPDT pole A | 22AWG red | Set 5.2V no-load first |
| 2 | USB-C 5V | SPDT pole B | 22AWG red | |
| 3 | SPDT common | 5V rail node | 22AWG red | Star point |
| 4 | 5V rail node | PCA9685 `V+` | 22AWG red | +1000µF across V+/GND |
| 5 | 5V rail node | S3 Mini `5V` | 22AWG red | Separate branch |
| 6 | GND star point | All module GNDs | 22AWG black | Single-point |
| 7 | S3 `3V3` | PCA9685 `VCC` | 30AWG | **Logic only — not V+** |
| 8 | S3 GPIO2 | PCA9685 + OLED `SDA` | 30AWG | |
| 9 | S3 GPIO3 | PCA9685 + OLED `SCL` | 30AWG | |
| 10 | S3 GPIO18 | PCA9685 `OE` | 30AWG | |
| 11–18 | PCA9685 ch0–7 | Servo 1–8 signal | 30AWG | Upstream order preserved |

Wire gauges follow upstream's guidance: **30AWG for data, 22AWG for power**.

---

## Upstream divergence

Branched from `86d2bf8` (`main`). Firmware changes required:

- `setServoAngle()` — rewritten to drive PCA9685 channels over I2C instead of
  `ESP32Servo`.
- The eight `servos[i].attach(servoPins[i], 732, 2929)` calls — removed; replaced
  by a single PCA9685 initialisation.
- `I2C_SDA`/`I2C_SCL` — repointed to GPIO2/3.
- `ESP32PWM::allocateTimer()` calls — no longer needed; PWM generation moves off
  the MCU entirely.

Unchanged and portable: `face-bitmaps.h`, `movement-sequences.h`, the face/
animation engine, the JSON API, and Sesame Studio compatibility.

---

## Verification

Before power-on:
1. LM2596S output measured at ~5.2V **with no load connected**.
2. Continuity check: PCA9685 `VCC` is on the 3.3V net, `V+` on the 5V net, and
   they are **not** connected to each other.
3. `i2cdetect` equivalent reports exactly `0x3C` and `0x40`.
4. Servo sweep on ch0–ch7 one channel at a time, current monitored.
5. `OE` HIGH confirmed to disable all outputs.

Nothing is UWB-related — the header is unpopulated at this stage by design.

## Open questions

None blocking. One remains deferred by choice: the specific UWB part (DWM1000
vs DWM3000), resolvable without redesign because the header is part-agnostic.

**Battery — resolved 2026-09-02.** A **2S 18650 pack, 7.4V nominal**, with an
integrated **protection circuit** and **XH2.54-2P** output plug, charged over
USB. Feeds `LM2596S IN+` / `IN-` directly.

- 7.4V nominal (8.4V fully charged, ~6.0V cutoff) sits comfortably above the
  LM2596S dropout for a 5.2V output across the whole discharge curve.
- The protection circuit is the pack's, not ours — this design adds no
  undervoltage cutoff of its own, so **do not substitute an unprotected pack.**
- Mate the XH2.54-2P to a matching header; do not solder cell leads directly.

> The Loftwork `Robotics/Design` bench notes specify **14500** cells at the same
> 2S / 7.4V. Electrically interchangeable here — same voltage, same connector
> convention — differing only in capacity and physical size. 18650 is the
> chosen part for the build; 14500 is fine for bench testing.
