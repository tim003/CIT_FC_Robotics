# Stage 1 as-built record and Makerfabs UWB transition design

**Date:** 2026-09-09
**Status:** Approved

## Purpose

Bring the wiring documentation into line with two new facts:

1. A colleague built and tested the photographed Stage 1 perfboard assembly for
   power, GPIO2/GPIO3 I2C, and three-servo movement.
2. Two Makerfabs **ESP32 UWB DW3000 WROOM** boards have been purchased for the
   next positioning experiment.

The photographs are valuable bench evidence, but they do not prove the hidden
underside netlist, an eight-servo load, Wi-Fi operation in the stacked physical
layout, or any UWB integration. The documentation must preserve that boundary
instead of describing the photographed board as a fully verified robot.

## Decisions

### Two Stage 1 records

The repository will document two related but different Stage 1 designs:

- **As-built bench assembly:** a historical, physical record matching
  `hardware/circuit layout/`. It records the component placement and the
  limited tests that passed.
- **Production target:** the safer electrical design in
  `docs/wiring/netlist.md`, including star power distribution, PCA9685 `OE`,
  local bulk capacitance, and radio antenna clearance.

The production netlist remains the source of truth for new construction. The
as-built record does not silently replace it.

### Verification boundary

The Stage 1 as-built assembly is verified only for:

- power-up;
- I2C on ESP32-S3 GPIO2/GPIO3; and
- movement of three servos.

It is not verified for:

- all eight servos or simultaneous load;
- Wi-Fi association or access-point operation in the photographed placement;
- the production power improvements;
- UWB; or
- complete hidden-net agreement with the production netlist.

### Antenna treatment

The photographed ESP32-S3 is mounted with its antenna end over the perfboard
and close to/under the stacked PCA9685. That placement does not satisfy the
conservative keep-out in `docs/wiring/antenna.md`. It may remain in the
historical as-built record, but it must not be copied into the production
layout without a completed in-assembly Wi-Fi acceptance test.

The production diagram will show the ESP32 antenna end overhanging the carrier
board with no PCA9685, LM2596S, copper, wiring bundle, screw, or bracket in the
keep-out region.

### Makerfabs replaces the direct-DWM3000 Stage 2 picture

The purchased Makerfabs product is a complete ESP32 + DW3000 board. It is not a
bare DWM3000 radio wired directly to the robot ESP32-S3 over SPI. The Stage 2
architecture is therefore:

```text
robot ESP32-S3 controller <-> provisional UART link <-> Makerfabs ESP32 UWB DW3000
```

The Makerfabs board owns UWB ranging and scheduling. The robot ESP32-S3 retains
servo, display, behaviour, and higher-level swarm control.

The current direct-SPI UWB header remains an unpopulated base-build reservation
until the delivered Makerfabs board revision and interfaces are inspected. No
GPIO assignment, power net, or soldering row changes in this documentation
pass. When the boards arrive, their schematic, header pins, current draw, and
UART behaviour must be verified before `pin-map.md` and `netlist.md` change.

### Diagram roles

The four generated SVGs are retained, including the user's current filenames:

| Diagram | New role |
|---|---|
| `1a-no-uwb-Paul.svg` | Stage 1 production target, no UWB |
| `1b-no-uwb-Claude.svg` | Stage 1 as-built perfboard and verification boundary |
| `2a-uwb-based-on-1a.svg` | Provisional one-robot Makerfabs UART architecture |
| `2b-uwb-based-on-1b.svg` | Provisional two-robot acceptance-test topology |

`generate.py` remains the only editable diagram source. Generated SVGs are not
hand-edited.

### Photo provenance

`hardware/circuit layout/README.md` will identify:

- `20260901_CircuitBoardDesign_002_Fixed.jpg` as the colleague's as-built layout
  reference;
- the files under `photos/` as assembly evidence; and
- the exact verification boundary above.

Photographs are not promoted to a soldering netlist. A photo cannot establish
all underside connections, wire gauge, source-selection behaviour, or measured
rail performance.

## Roadmap

### Stage 1 — partially bench-verified

Power, I2C, and three-servo movement have passed on the photographed assembly.
The production target still needs to be built and tested with all eight servos,
including rail sag/current measurements and a Wi-Fi acceptance test in the
final mechanical assembly.

### Stage 2 — hardware purchased, integration pending

Two Makerfabs ESP32 UWB DW3000 WROOM boards are purchased. On arrival:

1. Record board revision and compare the delivered board with the Makerfabs
   schematic.
2. Identify exposed power, ground, UART, and programming pins by primary source
   and continuity where necessary.
3. Measure idle and ranging current independently of the servo rail.
4. Run the supplied two-board ranging examples before writing integration code.
5. Establish the UART message boundary between UWB coprocessor and robot MCU.
6. Select robot GPIOs only after the interface is demonstrated.
7. Update `pin-map.md`, `netlist.md`, power budget, and diagrams together.

### Stage 3 — fleet scaling

Only after the two-board experiment succeeds: buy the remaining boards, define
four-node scheduling, and validate update rate and all-pairs ranging under
servo and Wi-Fi activity.

## Documentation changes

- Create `hardware/circuit layout/README.md`.
- Rework `docs/wiring/diagrams/generate.py` and regenerate all four SVGs.
- Update `docs/wiring/diagrams/README.md` to explain the new diagram roles.
- Update `docs/wiring/README.md`, `docs/wiring/expansion.md`,
  `hardware/bom.md`, `ARCHITECTURE.md`, and `AGENTS.md` with the stage and
  purchase status.
- Do not change the netlist or pin map in this pass.

## Verification

- Diagram tests assert the four filenames and semantic roles.
- All generated SVGs parse as XML.
- Regeneration is deterministic.
- `bash scripts/check-wiring-docs.sh` passes.
- Rendered diagrams receive a visual inspection for clipped labels, crossed
  wires, and incorrect stage markings.
- `.DS_Store`, unrelated files, and temporary renders are not staged.
