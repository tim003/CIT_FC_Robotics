# GPIO pin map — ESP32-S3 Super Mini

Canonical GPIO assignments for this build. Every other wiring document cites
these numbers and must not restate them differently. Where the
[netlist](netlist.md) and this table disagree, the netlist is the source of
truth and this file is the bug.

**Board:** ESP32-S3 Super Mini. This is the board the I2C bus was bench-proven
on, not a substitute for one. See [Board identity](#board-identity) below —
picking the wrong S3 mini invalidates the free-pin list.

## Assignments

| Function | GPIO | Direction | Notes |
|---|---|---|---|
| I2C SDA | GPIO2 | bidirectional | OLED `0x3C` + PCA9685 `0x40`, shared bus |
| I2C SCL | GPIO3 | output | Strapping pin — qualified exception, see below |
| PCA9685 `OE` | GPIO18 | output | Active-low; HIGH disables all 16 channels |
| UWB SCK | GPIO12 | output | |
| UWB MOSI | GPIO11 | output | |
| UWB MISO | GPIO13 | input | |
| UWB CSn | GPIO10 | output | |
| UWB IRQ | GPIO14 | input | Interrupt-capable |
| UWB RSTn | GPIO21 | open-drain | **Never drive high** — pull low to reset, else release to high-Z |
| UWB WAKEUP | GPIO16 | output | DWM3000 only; leave unconnected for DWM1000 |
| UWB EXTON | GPIO17 | input | DWM3000 only; leave unconnected for DWM1000 |

Eleven pins assigned, all distinct. The UWB rows are specified but
**unpopulated** in the base build — see [expansion.md](expansion.md).

## Do not use

| GPIO | Reason |
|---|---|
| GPIO0 | Boot mode strapping, with GPIO46 |
| GPIO19 | USB D− |
| GPIO20 | USB D+ |
| GPIO26 – GPIO32 | In-package SPI flash / PSRAM bus. Reserved, never break out |
| GPIO43 | UART0 TX — reserved for the serial console |
| GPIO44 | UART0 RX — reserved for the serial console |
| GPIO45 | Strapping: flash/PSRAM voltage select at boot |
| GPIO46 | Strapping: boot mode with GPIO0 |
| GPIO47 | Reserved — do not use |
| GPIO48 | Onboard RGB LED (WS2812) |

## GPIO3 as I2C SCL — the qualified exception

GPIO3 is a strapping pin, so assigning it looks wrong at first glance. It is
safe here, for a specific and checkable reason.

On the ESP32-S3, GPIO3 does **not** select boot mode — that is GPIO0 with
GPIO46. GPIO3 selects the *JTAG signal source*, and that strapping role is
gated by the `STRAP_JTAG_SEL` eFuse. That eFuse ships **unburned**, and while
it is unburned GPIO3's level at reset is ignored entirely. The I2C pull-ups
holding the line high at boot are therefore harmless.

Two consequences, both binding:

- **Do not burn `STRAP_JTAG_SEL` on these boards.** Doing so makes GPIO3's
  reset level significant and turns the I2C pull-ups into a boot-behaviour
  hazard.
- Debug over the built-in **USB Serial/JTAG** interface, not external JTAG.

Sources: ESP32-S3 Hardware Design Guidelines (schematic checklist) and the
ESP-IDF "Configure Other JTAG Interfaces" documentation.

## Board identity

The design originally targeted a Lolin S3 Mini. It was retargeted to the
ESP32-S3 Super Mini because that is the board the GPIO2/3 I2C bus was actually
verified on. The two are not interchangeable for documentation purposes: they
break out different subsets of the same silicon.

The I2C bus used to sit on GPIO35/36, which carried an octal-PSRAM caveat —
those pins are consumed by the PSRAM bus on 8-line PSRAM parts. **That caveat
no longer applies to the I2C bus.** GPIO2 and GPIO3 are free regardless of
PSRAM configuration, so the bus is now portable across S3 variants. The caveat
still applies to GPIO33–GPIO37 generally: they are free only on quad-PSRAM
modules (the `…R2` parts). Confirm the marking on your module before using
them for anything.

There is no official `pins_arduino.h` variant for the Super Mini. Do not rely
on framework defaults for I2C — call `Wire.begin(2, 3)` explicitly.

## Free pins

Deliberately not enumerated as a list to solder against.

At the silicon level, every pin not named above is a general-purpose GPIO with
no reserved function. But *silicon-level free* and *available on your board*
are different claims, and only the first can be sourced from a datasheet. The
Super Mini is a generic module with no official schematic, and the widely
circulated third-party pinouts for it are demonstrably wrong (below).

**Before assigning any new pin, confirm it is physically broken out on the
board in front of you, and confirm the module marking for the PSRAM question.**

## Sources that are wrong about this board

Recorded because they are the top search results, and because trusting them
would have forced a needless rewrite of the UWB pin map.

`espboards.dev`'s ESP32-S3 Super Mini page claims GPIO10–14 are SPI flash
pins and strapping pins. Both claims are false. The community
`ESP32S3_SUPERMINI_PINOUT` header on GitHub repeats them — its own first line
states it is derived from that page — and additionally marks GPIO26–32 as
"safe", which is exactly backwards.

Checked against the ESP32-S3 datasheet v2.2 §2.3.3–2.3.4:

- **GPIO10–14 are Priority 2**: "GPIO pins can be freely used without
  restrictions." Their `FSPI*` names are IO-MUX alternate functions of SPI2,
  the general-purpose SPI peripheral — not the flash interface.
- **The flash/PSRAM interface is GPIO26–32** (Priority 4), in-package.
- **The strapping pins are GPIO0, GPIO3, GPIO45 and GPIO46** — no others.

The general lesson, per this repo's rules: verify pin claims against the
datasheet before writing them down. A wrong pin number costs a burnt module,
not a failing test.
