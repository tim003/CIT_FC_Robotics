# Stage 1 as-built perfboard

## Status

This is the colleague-built Stage 1 bench assembly, without UWB. It verified
power-up, I2C on GPIO2/GPIO3, and movement of three servos.

It does not verify all eight servos, simultaneous servo load, Wi-Fi in the
photographed stacked placement, UWB, or complete agreement of hidden underside
connections with the production netlist.

## Files

- `20260901_CircuitBoardDesign_002_Fixed.jpg` — as-built placement/wire reference.
- `photos/` — top, oblique, underside, and module-placement photographs.

## Visible placement

The ESP32-S3 Super Mini is at the lower-left, the LM2596S is rotated at the
right, and the PCA9685 is stacked across the upper part of the carrier.

## Antenna warning

The photographed ESP32 antenna end does not overhang the carrier and sits near
the stacked PCA9685. This placement is radio-unverified and does not satisfy
the production keep-out in
[`../../docs/wiring/antenna.md`](../../docs/wiring/antenna.md).

## Authority

These images are bench evidence, not a soldering netlist. New construction uses
[`../../docs/wiring/netlist.md`](../../docs/wiring/netlist.md); where a photo or
pictorial guide disagrees with the netlist, the netlist wins.
