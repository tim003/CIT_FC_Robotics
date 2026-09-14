# Sesame Production Servo Translation Design

**Date:** 2026-09-14
**Status:** Approved

## Purpose

Make the existing `sesame-s3-pca9685` firmware safe to use with the assembled
ESP32-S3 Super Mini robot while retaining upstream Sesame movements, faces,
Wi-Fi control, serial control, and Sesame Studio compatibility.

The assembled robot has a physical PCA9685 channel order verified by an
all-eight-servo diagnostic. That physical order is not the same as upstream's
logical motor order. The firmware therefore needs an explicit translation at
the actuator boundary rather than a same-number channel assumption.

This design also records which parts of Grisha's ESP32-S2/PCA9685 work are
code-backed and adoptable, and deliberately keeps UWB runtime integration out
of this first production acceptance build.

## Evidence and provenance

### Local hardware evidence

On 2026-09-14, the eight-servo diagnostic sketch moved one PCA9685 channel at a
time and the displayed labels matched the user's observed physical joints:

| PCA9685 channel | Verified physical joint |
|---:|---|
| 0 | ULF — Upper Left Front |
| 1 | ULB — Upper Left Back |
| 2 | LLF — Lower Left Front |
| 3 | LLB — Lower Left Back |
| 4 | URF — Upper Right Front |
| 5 | URB — Upper Right Back |
| 6 | LRF — Lower Right Front |
| 7 | LRB — Lower Right Back |

This evidence supersedes the unverified documentary assumption that PCA9685
channel number equals upstream motor index. The netlist remains the wiring
source of truth and must be corrected to describe the verified physical build.

### Upstream logical order

Upstream `movement-sequences.h` and Sesame Studio use logical indices in this
order:

| Logical index | Upstream name | Physical meaning |
|---:|---|---|
| 0 | R1 | Upper Right Front |
| 1 | R2 | Upper Right Back |
| 2 | L1 | Upper Left Front |
| 3 | L2 | Upper Left Back |
| 4 | R4 | Lower Right Back |
| 5 | R3 | Lower Right Front |
| 6 | L3 | Lower Left Front |
| 7 | L4 | Lower Left Back |

The required logical-to-physical translation is therefore:

```text
upstream logical index:  0  1  2  3  4  5  6  7
PCA9685 channel:         4  5  0  1  7  6  2  3
```

Equivalently, the physical-channel table is:

| PCA channel | Physical label | Upstream name | Logical index |
|---:|---|---|---:|
| 0 | ULF | L1 | 2 |
| 1 | ULB | L2 | 3 |
| 2 | LLF | L3 | 6 |
| 3 | LLB | L4 | 7 |
| 4 | URF | R1 | 0 |
| 5 | URB | R2 | 1 |
| 6 | LRF | R3 | 5 |
| 7 | LRB | R4 | 4 |

### External audit sources

The external audit read these repositories at fixed commits:

- `henkaku-center/aps` at `b78a42c`, especially
  `docs/planning/aps-ii/PROCUREMENT-STATUS.md`;
- `henkaku-center/sim2real` at `591885c`, especially
  `reference/FIRMWARE-STATE.md`, `manifest/robot.yaml`, and
  `tools/karasu-usb-bridge/`;
- `dorianborian/sesame-robot` at `d106cbc`, including merged PR #76 commit
  `c458a9e`;
- the local project at its current working state.

Grisha's PCA9685 conversion is described in hardware logs but its exact source
was not found in any audited repository. No missing implementation detail may
be inferred from that log-only description.

The local copies of `face-bitmaps.h`, `movement-sequences.h`, and
`captive-portal.h` match both upstream `86d2bf8` and current `d106cbc` exactly.
Their SHA-256 values are:

| Header | SHA-256 |
|---|---|
| `face-bitmaps.h` | `722692894402d9eccf5c022ed7b4eb090c2de6b171b7872cedce55609dac1f06` |
| `movement-sequences.h` | `f77d713703e361dff2458f4fd02356ed397b8f47d83bd7a87587e8f6e899d2f1` |
| `captive-portal.h` | `f28273df29c4f38cce3005604f883ad161f920ae25168b1a62aa986886a5e8a4` |

## Architecture

### Shared mapping core

Create `firmware/common/sesame_servo_map.h` as the single authoritative code
definition for:

- eight logical Sesame servos;
- sixteen physical PCA9685 outputs;
- the eight verified physical channel labels;
- upstream logical names and indices;
- logical-to-PCA channel translation;
- production pulse counts `150..512` at 50 Hz;
- GPIO18 active-low output-enable control; and
- testable helpers for command translation and cleared-output activation.

Both Arduino sketches include this header by a relative include. Arduino CLI
has been checked with a throwaway sketch and accepts a header in a sibling
folder outside the sketch directory.

### Hardware-boundary translation

All movement files, serial commands, web commands, JSON API data, and subtrim
commands continue to address upstream logical indices `0..7`.

`setServoAngle(logicalIndex, angle)` performs these steps:

1. reject the command unless PCA9685 startup completed safely;
2. validate logical index `0..7`;
3. apply `servoSubtrim[logicalIndex]` and clamp to `0..180`;
4. translate logical index through `{4,5,0,1,7,6,2,3}`;
5. convert angle to PCA9685 counts using `150..512`; and
6. write the translated physical channel.

Subtrim remains attached to logical identity. For example, `subtrim 0 7`
adjusts upstream `R1` and therefore physical channel 4; it does not adjust
whatever happens to occupy physical channel 0.

The physical diagnostic sketch remains channel-oriented. Its OLED continues to
show `0 ULF` through `7 LRB`, because its purpose is to verify the harness and
PCA header positions rather than interpret upstream animation identities.

### Fail-safe PCA9685 startup

GPIO18/OE is driven HIGH before I2C initialization. The firmware probes
PCA9685 address `0x40` before enabling any output.

When the probe succeeds, firmware initializes the PCA9685, programs 50 Hz, sets
all sixteen outputs to the PCA9685 full-off state, and only then drives OE LOW.
Clearing all sixteen outputs protects against values left by any previous
diagnostic, including values on currently unused channels 8–15.

When the probe fails, firmware leaves OE HIGH, leaves the servo-ready flag
false, reports the fault over serial, and rejects later servo commands. Wi-Fi
and OLED diagnostics may continue; actuator output must remain disabled.

Boot never commands Rest, Stand, or another pose automatically. It changes the
face only and leaves the servos limp until the user sends a movement command.

## UWB boundary

This firmware contains no UWB driver, task, protocol, pin initialization, or
runtime behavior. Remove the stale direct-SPI UWB pin constants from the
production sketch so they cannot be mistaken for an implemented integration.

The physical optional raw-radio header remains documented in the netlist and
pin map. Future selected UWB integration remains the approved Makerfabs UART
coprocessor architecture and is governed by the existing Stage 2 plan. This
change neither assigns its UART pins nor modifies any UWB hardware document.

## Grisha/Henkaku adoption decisions

### Retain or adopt now

- Retain serial `face`/`fc` commands. They are already in local firmware and
  were merged upstream in PR #76 (`c458a9e`).
- Retain native USB CDC with `CDCOnBoot=cdc`.
- Retain per-logical-servo subtrim and the stock movement/API formats.
- Adopt the procedural acceptance sequence: verify electronics, test one servo
  before full harness use, validate Rest and Stand, then Wave, Walk, Stop, and
  HTTP control.
- Adopt the mechanical lesson: horn fitting follows the upstream build guide
  while motors hold the Stand pose, followed by repeated Rest/Stand checks.
  Temporary software offsets must not substitute for correct horn indexing.

### Defer

- Karasu Android/Termux USB bridging. Its code is available and transport-level
  compatible, but it is not needed for this directly connected first run.
- Host-side SafeAction. It belongs to later autonomous/sim2real control, not
  the stock firmware acceptance build.
- Rich PCA9685 register dumps. The Henkaku version is log-only; the existing
  address probe plus fail-safe activation is sufficient for this milestone.

### Reject for this build

- S2-specific I2C GPIO assignments and OLED power wiring;
- `ESP32Servo` and its version pin, because PWM is generated by PCA9685;
- Henkaku's bench power topology, because this robot uses the documented SPDT,
  LM2596S, star-ground design; and
- temporary mount offsets or inferred PCA9685 code without committed source.

## Documentation changes

Update these documents in the same change as firmware:

- `ARCHITECTURE.md`: replace the false same-number channel invariant with
  preservation of upstream logical identity through an explicit translation;
- `docs/wiring/netlist.md`: retain physical channels as soldering truth and
  associate each with the correct upstream logical joint;
- `docs/upstream/divergence.md`: describe translation rather than direct
  index equality;
- `firmware/sesame-s3-pca9685/README.md`: document map, fail-safe startup,
  UWB absence, and first-run sequence;
- `firmware/test/README.md`: distinguish physical diagnostic labels from
  upstream logical identities and record the calibration sequence;
- `docs/upstream/external-audit-2026.md`: correct the earlier same-channel
  assumption and preserve the code-backed versus log-only evidence matrix.

## Verification

### Host tests

Tests must prove:

- exact logical map `{4,5,0,1,7,6,2,3}`;
- exact physical labels and their logical identities;
- every physical channel is in `0..7` and appears once;
- every logical index is in `0..7` and appears once;
- an asymmetric subtrim remains attached to logical identity after mapping;
- invalid logical indices are rejected;
- translated angles clamp to `0..180`;
- safe activation clears all sixteen channels full-off before OE enable; and
- a failed PCA probe performs no clear or enable operation.

Existing tests continue to cover display pairing, OLED cell formatting, pulse
conversion, and OE configure/disable ordering.

### Build and document checks

- Clean Arduino compile for the production sketch.
- Clean Arduino compile for the eight-servo diagnostic sketch.
- Host C++ tests with `-std=c++17 -Wall -Wextra -Werror`.
- `scripts/check-wiring-docs.sh`.
- SHA-256 verification of all three unmodified upstream headers.
- A search confirming no `UWB_` symbol or DW3000 include remains in production
  firmware.
- `git diff --check`.
- Independent code review before hardware upload.

## Staged first production run

Hardware upload is a separate, user-confirmed acceptance step after code review.

1. Upload with the ESP32 isolated from the circuit because the assembled
   external circuit has already been shown to interfere with reset/boot entry.
2. Reinstall it and power servo V+ from the battery/LM2596 path, not laptop USB.
3. Raise the robot so its feet cannot strike the table and keep the physical
   power switch reachable.
4. Confirm boot causes no servo movement.
5. Confirm OLED output and the `Sesame-Controller` Wi-Fi portal.
6. Command Rest and inspect every joint.
7. Command Stand and alternate Rest/Stand to verify horn indexing.
8. If correct, run Wave while raised.
9. If correct, run Walk while raised and test Stop immediately.
10. Floor testing occurs only after the suspended checks pass.

Stop immediately on binding, buzzing, wrong-joint motion, regulator sag, reset,
or unexpected heating.

## Non-goals

- No modification of `movement-sequences.h`, `face-bitmaps.h`, or
  `captive-portal.h`.
- No new pose, calibration wizard, autonomous behavior, or movement on boot.
- No UWB runtime integration or new UWB pin assignment.
- No Android bridge installation.
- No physical rewiring of the verified PCA9685 servo channels.
- No deletion or promotion of the non-canonical
  `robotics_1stservo_test` sketch as part of this change.
