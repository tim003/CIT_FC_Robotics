# Final review fix evidence

**Date:** 2026-09-14 20:58:12 CST
**Base:** `6fcc081fc40aefaaaa77b51127143e779328bd39`

## Wiring-document checker

Command:

```bash
bash scripts/check-wiring-docs.sh
```

Result (exit 0):

```text
  ok: no placeholders
  ok: no forbidden GPIO assignments
  ok: I2C addresses correct
  ok: dual-supply invariant checked
  ok: RSTn warning present wherever RSTn appears
  ok: internal links resolve
  ok: every netlist GPIO is declared in the pin map
  ok: netlist row numbering consistent (34 rows)
  ok: physical servo channels map to upstream logical identities
all consistency checks passed
```

## Diff hygiene

Command:

```bash
git diff --check
```

Result (exit 0): no output.

## Focused evidence-attribution and production-status search

Command:

```bash
rg -n -C 1 'movement of three servos|user.s 2026-09-14 assembled-robot run' ARCHITECTURE.md docs/upstream/divergence.md
if rg -n 'boots on a real ESP32-S3|has exercised all|physical-to-logical translation is verified' ARCHITECTURE.md; then exit 1; else echo 'PASS: stale production-hardware claims absent'; fi
rg -n -C 1 'diagnostic sketch|shared translation code|has not been uploaded' ARCHITECTURE.md
```

Result (exit 0):

```text
ARCHITECTURE.md-78-[colleague-built perfboard evidence](hardware/circuit%20layout/README.md)
ARCHITECTURE.md:79:verifies power-up, I2C on GPIO2/GPIO3, and movement of three servos on channels
ARCHITECTURE.md:80:0–2. The user's 2026-09-14 assembled-robot run of
ARCHITECTURE.md-81-[`firmware/test/robotics_esp32s3/`](firmware/test/robotics_esp32s3/) verified all
--
docs/upstream/divergence.md-27-[colleague-built perfboard evidence](../../hardware/circuit%20layout/README.md)
docs/upstream/divergence.md:28:verifies power-up, I2C on GPIO2/GPIO3, and movement of three servos on channels
docs/upstream/divergence.md:29:0–2. The user's 2026-09-14 assembled-robot run of
docs/upstream/divergence.md-30-[`firmware/test/robotics_esp32s3/`](../../firmware/test/robotics_esp32s3/)
PASS: stale production-hardware claims absent
90-
91:The diagnostic sketch in
92-[`firmware/test/robotics_esp32s3/`](firmware/test/robotics_esp32s3/) verified
93:the physical channel-to-joint mapping on hardware. The shared translation code
94-is host-tested and the production PCA9685 firmware in
95-[`firmware/sesame-s3-pca9685/`](firmware/sesame-s3-pca9685/README.md) compiles,
96:but that production sketch has not been uploaded. Animation data is untouched;
97-production animation and hardware acceptance remain pending. Blast radius and pulse-width arithmetic are recorded in
```

## Focused Rest/Stand search

Command:

```bash
if rg -n 'Rest.*all servos at 0|Stand.*all servos at 90' firmware/sesame-s3-pca9685/README.md; then exit 1; else echo 'PASS: stale Rest/Stand angle claims absent'; fi
rg -n -C 1 'Rest.*90|Stand.*R1=135' firmware/sesame-s3-pca9685/README.md
```

Result (exit 0):

```text
PASS: stale Rest/Stand angle claims absent
231-
232:1. **Rest** — all eight logical servos are commanded to 90°; inspect every
233-   joint before continuing.
234:2. **Stand** — expect logical angles R1=135°, R2=45°, L1=45°, L2=135°,
235-   R4=0°, R3=180°, L3=0°, and L4=180°; verify the stance without binding.
```

## Focused stale-count and firmware-delta/OE search

Command:

```bash
if rg -n '166 changed lines|six surgical edits' docs/upstream/divergence.md; then exit 1; else echo 'PASS: stale fixed diff counts absent'; fi
if rg -n 'released only after the PWM frequency is programmed|held disabled through boot' docs/upstream/divergence.md firmware/sesame-s3-pca9685/README.md; then exit 1; else echo 'PASS: incomplete OE wording absent'; fi
rg -n 'new shared header|shared `firmware/common/sesame_servo_map.h`|successful `0x40` probe|all 16 outputs|sixteen PCA9685 channels.*full-off' docs/upstream/divergence.md firmware/sesame-s3-pca9685/README.md
```

Result (exit 0):

```text
PASS: stale fixed diff counts absent
PASS: incomplete OE wording absent
docs/upstream/divergence.md:54:| — *(new shared header)* | `firmware/common/sesame_servo_map.h` defines the verified logical-to-physical translation; `setServoAngle()` maps upstream logical indices through `LOGICAL_TO_PCA_CHANNEL` before writing PCA9685 outputs |
docs/upstream/divergence.md:55:| — *(new)* | PCA9685 `OE` on GPIO18 is held HIGH through boot and released only after a successful `0x40` probe, 50 Hz setup, and all 16 outputs being set full-off |
firmware/sesame-s3-pca9685/README.md:24:| — | **Added:** shared `firmware/common/sesame_servo_map.h`; `setServoAngle()` translates upstream logical indices through `LOGICAL_TO_PCA_CHANNEL` before writing PCA9685 outputs |
firmware/sesame-s3-pca9685/README.md:25:| — | **Added:** PCA9685 `OE` on GPIO18, held HIGH through boot and released only after a successful `0x40` probe, 50 Hz setup, and all 16 outputs being set full-off |
firmware/sesame-s3-pca9685/README.md:166:After a successful `0x40` probe, the PWM frequency is programmed and all
firmware/sesame-s3-pca9685/README.md:167:sixteen PCA9685 channels are set to full-off before `OE` is released LOW, so no
```
