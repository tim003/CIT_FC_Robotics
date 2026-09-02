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
| 8-pin header | 1 | UWB expansion. Landed but unpopulated |
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

## Deliberately not purchased

**The UWB module.** The header is landed and the netlist specifies all eight
connections, but no module is fitted in the base build. Fitting one requires
re-checking the power budget in
[`../docs/wiring/power.md`](../docs/wiring/power.md) — the eight servos
already peak above the converter's continuous rating.

Either supported part drops into the same header. See
[`../docs/wiring/expansion.md`](../docs/wiring/expansion.md) for the
DWM1000 / DWM3000 comparison.

## Notes on substitutions

- **The battery pack must be protected.** This design contains no
  undervoltage cutoff of its own and relies on the pack's protection circuit.
  2S 14500 cells are electrically interchangeable at the same 7.4 V, differing
  only in capacity and size.
- **The LM2596S is adjustable and ships at an arbitrary voltage.** It is not a
  fixed-output part. Set it to 5.2 V under no load before connecting anything
  downstream.
