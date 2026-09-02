# Pictorial wiring guides

Four pictorial guides, in two pairs. Pair **1** is without the UWB module, pair
**2** is with it. Within each pair, **a** is the CIT_FC design in this repo and
**b** is the Loftwork bench scheme from `Robotics/Design` test `_003`.

| File | Variant | UWB | Scheme |
|---|---|---|---|
| [`1a-no-uwb-citfc.svg`](1a-no-uwb-citfc.svg) | 1a | no | CIT_FC (this repo) |
| [`1b-no-uwb-loftwork.svg`](1b-no-uwb-loftwork.svg) | 1b | no | Loftwork bench `_003` |
| [`2a-uwb-citfc.svg`](2a-uwb-citfc.svg) | 2a | DWM3000 | CIT_FC (this repo) |
| [`2b-uwb-loftwork.svg`](2b-uwb-loftwork.svg) | 2b | DWM3000 | Loftwork bench `_003` + UWB |

> The netlist in `docs/wiring/` is the source of truth. These diagrams
> illustrate it. If a diagram and the netlist disagree, the netlist wins and
> the diagram gets fixed.

## Regenerating

All four come from one generator:

```bash
python3 docs/wiring/diagrams/generate.py
```

Edit `generate.py`, never the `.svg` files. Hand-editing four near-identical
diagrams is how they drift: the previous `with-dwm.svg` still showed
`35 SDA` / `36 SCL` on the board after the I2C bus had already moved to
GPIO2/3, because only its legend got updated.

## What the two schemes share

Both were bench-verified on the **ESP32-S3 Super Mini**, and agree on
everything that matters most:

- I2C on **GPIO2 (SDA) / GPIO3 (SCL)** — PCA9685 and SSD1306 in parallel
- PCA9685 at `0x40`, SSD1306 at `0x3C`
- Logic 3V3 for both peripherals taken from the S3's `3V3` pin
- LM2596S steps the 2S pack down to the 5 V rail
- The rail feeds the S3 `5V` pin **and** the PCA9685 `V+` terminal as two
  branches — servo current never returns through the ESP32
- Servo V+/GND come from the PCA9685's own 3-pin headers

## Where 1a/2a differ from 1b/2b

| | **a** — CIT_FC | **b** — Loftwork `_003` | Why it matters |
|---|---|---|---|
| Servo count | 8 → ch0–ch7 | 3 → ch0–ch2 *(drawn scaled to 8)* | `_003` is a functional bench test, not the quadruped. Scaled here so the comparison isolates real design choices. |
| Buck output | **5.2 V** no-load | **5.0 V** | 5.2 V deliberately offsets sag under simultaneous servo load so the rail settles near 5 V in practice. |
| Cells | 2S 18650, protected, XH2.54-2P | 2S 14500 | Same 7.4 V nominal; electrically interchangeable. Differ only in capacity and physical size. |
| PCA9685 `OE` | driven from **GPIO18** | **not connected** | The significant one — see below. |
| Bulk capacitance | 1000 µF at `V+` | none | Without it, simultaneous servo inrush pulls the rail down harder. |
| Source select | battery **or** USB-C via SPDT | battery only | Bench-safe bring-up without discharging the pack; no backfeed between sources. |
| Ground topology | star point | breadboard common rail | Star keeps servo return current out of the logic ground reference. |

### The `OE` difference is the one to be careful about

`OE` is the PCA9685's active-low output enable: LOW enables all 16 outputs,
HIGH puts them in high-impedance.

Leaving it unconnected on scheme **b** is *not* a floating-pin fault — the
common Adafruit-style breakout carries an onboard pull-down, so the pin sits
LOW and the outputs are simply always enabled. That is a deliberate, safe
default for a bench rig.

The cost is functional, not electrical. With `OE` unconnected the outputs are
live from the instant the rail comes up, so the servos are driven before
firmware has decided what angle it wants. On a 3-servo bench test that is
merely untidy. On an assembled quadruped the legs snap to whatever the PWM
registers happen to hold at reset, which can strike the chassis or the bench.

Driving `OE` from GPIO18 lets firmware hold the outputs off through boot and
release them only once the channels hold known-safe angles. That is the whole
reason scheme **a** spends a GPIO on it.

If you ever build around a *bare* PCA9685 rather than a breakout, check for the
pull-down and add one if it is absent.

## UWB pins (variants 2a / 2b)

`SCK 12 · MOSI 11 · MISO 13 · CSn 10 · IRQ 14 · RSTn 21 · WAKEUP 16 · EXTON 17`

**RSTn is open-drain — never drive it high.** Pull it low to reset and release
to high-Z; driving it high fights the module's internal pull-up.

These GPIOs were verified against the ESP32-S3 datasheet v2.2 §2.3.3–2.3.4
rather than a third-party pinout page:

- **GPIO10–14 are Priority 2** — "GPIO pins can be freely used without
  restrictions." Their `FSPI*` names are IO-MUX alternate functions of SPI2,
  the general-purpose SPI, not the flash interface.
- The flash/PSRAM interface is **GPIO26–32** (Priority 4), which the Super Mini
  does not break out.
- Strapping pins are **GPIO0, GPIO3, GPIO45, GPIO46** only.

This matters because at least one widely-cited third-party pinout page claims
GPIO10–14 are flash lines *and* strapping pins. Both claims are wrong, and
believing them would have forced a needless rewrite of the UWB pin map.

GPIO3 carries the I2C clock and is a strapping pin, but its strapping role
selects the JTAG signal source only and is gated by the `STRAP_JTAG_SEL` eFuse,
which ships unburned. Do not burn that eFuse on these boards; debug over the
USB Serial/JTAG interface instead.

## Source

Loftwork scheme transcribed from Notion → `LW Taiwan / Robotics / Design`,
section 測試機能_ESP32S3_20260830_SesameRobot_003, read 2026-09-02.
