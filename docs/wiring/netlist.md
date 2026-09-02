# Netlist — the wiring source of truth

Every connection in the robot, as `from → to`. This document is what someone
solders from. Diagrams illustrate it; where a diagram disagrees, the diagram
is wrong and gets fixed.

Net names are defined in [power.md](power.md). GPIO numbers are defined in
[pin-map.md](pin-map.md); every GPIO referenced here is declared there, and
`scripts/check-wiring-docs.sh` enforces that mechanically.

Wire gauge: **22AWG** for power and ground, **30AWG** for data and logic.

## Power

| # | From | To | Gauge | Notes |
|---|---|---|---|---|
| 1 | Battery + | LM2596S `IN+` | 22AWG red | Via the pack's XH2.54-2P plug — never soldered direct to cells |
| 2 | Battery − | `GND_STAR` | 22AWG black | |
| 3 | LM2596S `OUT+` | SPDT pole A | 22AWG red | **Set 5.2 V no-load first** |
| 4 | LM2596S `OUT−` | `GND_STAR` | 22AWG black | |
| 5 | USB-C 5 V | SPDT pole B | 22AWG red | Bench supply, alternate source |
| 6 | USB-C GND | `GND_STAR` | 22AWG black | |
| 7 | SPDT common | `5V_RAIL` | 22AWG red | Rail node |
| 8 | `5V_RAIL` | PCA9685 `V+` | 22AWG red | Branch 1 — servo supply |
| 9 | `5V_RAIL` | ESP32-S3 `5V` | 22AWG red | Branch 2 — **not** daisy-chained from row 8 |
| 10 | 1000 µF + | PCA9685 `V+` | — | Observe polarity |
| 11 | 1000 µF − | `GND_STAR` | — | |

## Logic

| # | From | To | Gauge | Notes |
|---|---|---|---|---|
| 12 | ESP32-S3 `3V3` | PCA9685 `VCC` | 30AWG | **Logic only — this is not `V+`** |
| 13 | ESP32-S3 `3V3` | SSD1306 `VCC` | 30AWG | |
| 14 | ESP32-S3 `3V3` | UWB header `3V3` | 30AWG | |
| 15 | ESP32-S3 `GND` | `GND_STAR` | 22AWG black | |
| 16 | ESP32-S3 `GPIO2` | PCA9685 `SDA` + SSD1306 `SDA` | 30AWG | Shared bus |
| 17 | ESP32-S3 `GPIO3` | PCA9685 `SCL` + SSD1306 `SCL` | 30AWG | Shared bus |
| 18 | ESP32-S3 `GPIO18` | PCA9685 `OE` | 30AWG | Active-low |

Rows 16 and 17 are one bus, not four point-to-point wires. Both peripherals
sit on it in parallel: SSD1306 at `0x3C`, PCA9685 at `0x40`.

## Servos

One row per channel. Servo V+ and GND come from the **PCA9685's own 3-pin
headers**, not from separate runs to the rail — that is what keeps servo
current out of the ESP32.

| # | From | To | Gauge | Notes |
|---|---|---|---|---|
| 19 | PCA9685 `ch0` signal | Servo — upstream `servoPins[0]`, leg 1 | 30AWG | |
| 20 | PCA9685 `ch1` signal | Servo — upstream `servoPins[1]`, leg 2 | 30AWG | |
| 21 | PCA9685 `ch2` signal | Servo — upstream `servoPins[2]`, leg 4 | 30AWG | |
| 22 | PCA9685 `ch3` signal | Servo — upstream `servoPins[3]`, leg 6 | 30AWG | |
| 23 | PCA9685 `ch4` signal | Servo — upstream `servoPins[4]`, leg 8 | 30AWG | |
| 24 | PCA9685 `ch5` signal | Servo — upstream `servoPins[5]`, leg 10 | 30AWG | |
| 25 | PCA9685 `ch6` signal | Servo — upstream `servoPins[6]`, leg 13 | 30AWG | |
| 26 | PCA9685 `ch7` signal | Servo — upstream `servoPins[7]`, leg 14 | 30AWG | |

**Channel index must equal the upstream `servoPins[8]` index.** Upstream's
array is `{1, 2, 4, 6, 8, 10, 13, 14}`. Preserving this ordering is what keeps
existing animations and Sesame Studio working unchanged — see
[../upstream/divergence.md](../upstream/divergence.md).

## UWB header — unpopulated

Land these pads in the base build; do not fit a module. Populating the header
requires re-checking the power budget in [power.md](power.md).

| # | From | To | Gauge | Notes |
|---|---|---|---|---|
| 27 | ESP32-S3 `GPIO12` | UWB header `SCK` | 30AWG | |
| 28 | ESP32-S3 `GPIO11` | UWB header `MOSI` | 30AWG | |
| 29 | ESP32-S3 `GPIO13` | UWB header `MISO` | 30AWG | |
| 30 | ESP32-S3 `GPIO10` | UWB header `CSn` | 30AWG | |
| 31 | ESP32-S3 `GPIO14` | UWB header `IRQ` | 30AWG | Interrupt-capable |
| 32 | ESP32-S3 `GPIO21` | UWB header `RSTn` | 30AWG | **Open-drain — never drive high.** Pull low to reset, otherwise release to high-Z |
| 33 | ESP32-S3 `GPIO16` | UWB header `WAKEUP` | 30AWG | DWM3000 only; leave unconnected for DWM1000 |
| 34 | ESP32-S3 `GPIO17` | UWB header `EXTON` | 30AWG | DWM3000 only; leave unconnected for DWM1000 |

## Total

A total of **34** connections: 11 power, 7 logic, 8 servo, 8 UWB.

Of these, 26 are made in the base build. Rows 27–34 are the unpopulated UWB
header.

## Invariants this netlist encodes

Three things here are load-bearing. Changing any of them destroys hardware or
silently breaks the animation format.

1. **Servo current never flows through the ESP32.** Row 9 draws the MCU's 5 V
   from the rail node, not from the PCA9685's `V+` terminal, and servo power
   comes off the PCA9685's own headers rather than separate rail runs.
2. **PCA9685 `VCC` (row 12) is the 3V3 logic net, not `V+` (row 8).** They are
   different supplies on the same board. Wiring 5 V into `VCC` destroys it.
3. **`RSTn` (row 32) is open-drain.** Driving it high fights the module's
   internal pull-up.
