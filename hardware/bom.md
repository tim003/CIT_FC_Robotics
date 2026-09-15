# BOM delta vs upstream

**Delta only.** Upstream's full bill of materials is the baseline and is not
duplicated here — see
[`dorianborian/sesame-robot`](https://github.com/dorianborian/sesame-robot) @
`86d2bf8`. This file records only what differs.

## Added

| Part | Qty | Purpose |
|---|---|---|
| PCA9685 16-channel PWM breakout | 1 | Servo control over I2C. Replaces the Distro Board |
| LM2596S buck converter module | 1 | Battery → 5.2 V rail. Adjustable, must be set before use |
| SPDT switch | 1 | Source selection between battery and USB-C |
| 1000 µF electrolytic capacitor | 1 | Bulk capacitance at PCA9685 `V+` |
| 8-pin header | 1 | Optional bare-radio SPI UWB interface. Landed but unpopulated; not the selected Stage 2 route |
| Makerfabs ESP32 UWB DW3000 WROOM evaluation board | 2 purchased | Stage 2 UART-connected UWB coprocessor; intended quantity after acceptance is one per robot |
| ESP32-S3 Super Mini | 1 | MCU. Replaces upstream's S2 Mini / DevKitC |
| 2S 18650 pack, protected, XH2.54-2P | 1 | 7.4 V nominal supply, USB-charged |

## Removed

| Part | Note |
|---|---|
| Sesame Distro Board V1 / V3 | Superseded by the PCA9685 and the explicit power chain |

## Unchanged

Carried over from upstream without modification:

- 8 × MG90S servos
- SSD1306 OLED display
- All frame and mechanical hardware — CAD and STL assets stay upstream and are
  referenced by URL, not vendored here

## UWB purchase and integration status

On 2026-09-09, two evaluation boards of the exact product Makerfabs ESP32 UWB
DW3000 WROOM were purchased. They have not arrived or been integrated. The
selected architecture uses each Makerfabs onboard ESP32 as a UWB coprocessor
over UART, with an intended quantity after acceptance of one per robot.

Exact UART GPIOs, connector pins, logic levels, and the power feed remain
gated on delivered-board verification. Initial integration uses separate USB
power for the robot controller and Makerfabs board plus a common signal ground.
Sharing the servo rail requires measured Makerfabs idle, ranging-average, and
peak current plus explicit regulator-headroom approval against the servo
requirement. See the [expansion guide](../docs/wiring/expansion.md) and
[Makerfabs Stage 2 implementation
plan](../docs/superpowers/plans/2026-09-09-makerfabs-stage2-integration.md).

The 8-pin bare-radio SPI header remains an optional unpopulated alternative,
not the selected Stage 2 route. Its `RSTn` signal remains open-drain: drive it
low or leave it floating, never drive it high. A bare DWM1000 or DWM3000 fitted
to that header would require the power-budget review in
[`../docs/wiring/power.md`](../docs/wiring/power.md).

## Notes on substitutions

- **The battery pack must be protected.** This design contains no
  undervoltage cutoff of its own and relies on the pack's protection circuit.
  2S 14500 cells are electrically interchangeable at the same 7.4 V, differing
  only in capacity and size.
- **The LM2596S is adjustable and ships at an arbitrary voltage.** It is not a
  fixed-output part. Set it to 5.2 V under no load before connecting anything
  downstream.
