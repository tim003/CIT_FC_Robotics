# Sesame Production Servo Translation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make stock Sesame commands drive the assembled robot's verified physical PCA9685 channels safely, without changing upstream movement data or adding UWB runtime behavior.

**Architecture:** A shared header owns the physical channel table, upstream logical identities, pulse geometry, command translation, and PCA output-enable safety helpers. Production commands remain in upstream logical order and translate through `{4,5,0,1,7,6,2,3}` only at `setServoAngle()`; the diagnostic sketch remains physical-channel-oriented.

**Tech Stack:** ESP32 Arduino core, Adafruit PWM Servo Driver 3.0.3, Adafruit SSD1306/GFX/BusIO, C++17 host tests, Bash documentation checks, Markdown.

**Spec:** [`docs/superpowers/specs/2026-09-14-sesame-production-mapping-design.md`](../specs/2026-09-14-sesame-production-mapping-design.md)

## Global Constraints

- The netlist remains the soldering source of truth and records physical PCA9685 channels.
- Upstream logical order remains `R1,R2,L1,L2,R4,R3,L3,L4` at indices `0..7`.
- The exact logical-to-PCA mapping is `{4,5,0,1,7,6,2,3}`.
- Physical channel labels remain `ULF,ULB,LLF,LLB,URF,URB,LRF,LRB` at channels `0..7`.
- `servoSubtrim[]` remains indexed by upstream logical identity, not physical channel.
- Servo pulse bounds remain PCA9685 counts `150..512` at 50 Hz.
- GPIO18 is active-low PCA9685 OE and stays HIGH until all sixteen outputs are explicitly full-off.
- A failed PCA9685 `0x40` probe must leave OE HIGH and servo commands disabled.
- Do not modify `movement-sequences.h`, `face-bitmaps.h`, or `captive-portal.h`.
- Production firmware contains no UWB include, pin constant, task, protocol, or runtime behavior.
- Do not add `firmware/test/robotics_1stservo_test/` to a commit; it is non-canonical user reference material with unsafe pulse limits.
- No hardware upload occurs until automated verification and independent review pass and the user explicitly confirms the physical test state.

---

### Task 1: Create the shared translation and output-safety core

**Files:**
- Create: `firmware/common/sesame_servo_map.h`
- Create: `tests/sesame_servo_translation_test.cpp`
- Modify: `firmware/test/robotics_esp32s3/robotics_esp32s3_servo_map.h`
- Verify: `firmware/test/robotics_esp32s3/robotics_esp32s3.ino`
- Verify move: `firmware/test/robotics_esp32s3.ino` → `firmware/test/robotics_esp32s3/robotics_esp32s3.ino`
- Test: `tests/robotics_esp32s3_servo_map_test.cpp`

**Interfaces:**
- Consumes: verified physical channel order and upstream logical order from the spec.
- Produces: `SERVO_COUNT`, `PCA9685_OUTPUT_COUNT`, `SERVO_MAP`, `LOGICAL_TO_PCA_CHANNEL`, `pcaChannelForLogicalServo()`, `translateServoCommand()`, `holdServoOutputsDisabled()`, and `enableClearedPcaOutputs()` for Task 2.

- [ ] **Step 1: Preserve the existing diagnostic-sketch move**

Confirm the canonical Arduino layout exists:

```text
firmware/test/robotics_esp32s3/robotics_esp32s3.ino
firmware/test/robotics_esp32s3/robotics_esp32s3_servo_map.h
```

Confirm the old tracked path is deleted:

```bash
test ! -e firmware/test/robotics_esp32s3.ino
```

Do not stage `firmware/test/robotics_1stservo_test/`.

- [ ] **Step 2: Write the failing translation test**

Create `tests/sesame_servo_translation_test.cpp` with real assertions against the planned shared interface:

```cpp
#include <cassert>
#include <cstdint>
#include <cstring>

#include "sesame_servo_map.h"

struct FakePwm {
  uint8_t channels[PCA9685_OUTPUT_COUNT] = {};
  uint16_t onValues[PCA9685_OUTPUT_COUNT] = {};
  uint16_t offValues[PCA9685_OUTPUT_COUNT] = {};
  uint8_t callCount = 0;

  void setPWM(uint8_t channel, uint16_t on, uint16_t off) {
    channels[callCount] = channel;
    onValues[callCount] = on;
    offValues[callCount] = off;
    ++callCount;
  }
};

struct FakeOutputEnable {
  uint8_t configuredPin = 255;
  uint8_t disabledPin = 255;
  uint8_t enabledPin = 255;
  uint8_t enableCount = 0;

  void configureOutput(uint8_t pin) { configuredPin = pin; }
  void disable(uint8_t pin) { disabledPin = pin; }
  void enable(uint8_t pin) {
    enabledPin = pin;
    ++enableCount;
  }
};

int main() {
  constexpr uint8_t expectedChannels[SERVO_COUNT] = {4, 5, 0, 1, 7, 6, 2, 3};
  constexpr const char* expectedPhysical[SERVO_COUNT] = {
      "ULF", "ULB", "LLF", "LLB", "URF", "URB", "LRF", "LRB"};
  constexpr const char* expectedLogicalByPhysical[SERVO_COUNT] = {
      "L1", "L2", "L3", "L4", "R1", "R2", "R3", "R4"};
  constexpr uint8_t expectedLogicalIndexByPhysical[SERVO_COUNT] = {
      2, 3, 6, 7, 0, 1, 5, 4};

  bool seenPhysical[SERVO_COUNT] = {};
  bool seenLogical[SERVO_COUNT] = {};
  for (uint8_t logical = 0; logical < SERVO_COUNT; ++logical) {
    const uint8_t channel = pcaChannelForLogicalServo(logical);
    assert(channel == expectedChannels[logical]);
    assert(channel < SERVO_COUNT);
    assert(!seenPhysical[channel]);
    seenPhysical[channel] = true;
  }
  assert(pcaChannelForLogicalServo(SERVO_COUNT) == INVALID_PCA9685_CHANNEL);

  for (uint8_t channel = 0; channel < SERVO_COUNT; ++channel) {
    const ServoDefinition& servo = SERVO_MAP[channel];
    assert(servo.channel == channel);
    assert(std::strcmp(servo.abbreviation, expectedPhysical[channel]) == 0);
    assert(std::strcmp(servo.logicalName, expectedLogicalByPhysical[channel]) == 0);
    assert(servo.logicalIndex == expectedLogicalIndexByPhysical[channel]);
    assert(!seenLogical[servo.logicalIndex]);
    seenLogical[servo.logicalIndex] = true;
  }

  int8_t trims[SERVO_COUNT] = {7, 0, 0, 0, -11, 0, 0, 0};
  const TranslatedServoCommand r1 = translateServoCommand(0, 90, trims);
  assert(r1.valid && r1.pcaChannel == 4 && r1.adjustedAngle == 97);
  const TranslatedServoCommand r4 = translateServoCommand(4, 90, trims);
  assert(r4.valid && r4.pcaChannel == 7 && r4.adjustedAngle == 79);
  assert(translateServoCommand(0, -20, trims).adjustedAngle == 0);
  assert(translateServoCommand(0, 200, trims).adjustedAngle == 180);
  assert(!translateServoCommand(8, 90, trims).valid);

  FakePwm failedPwm;
  FakeOutputEnable failedOe;
  assert(!enableClearedPcaOutputs(failedPwm, failedOe, false));
  assert(failedPwm.callCount == 0);
  assert(failedOe.enableCount == 0);

  FakePwm readyPwm;
  FakeOutputEnable readyOe;
  assert(enableClearedPcaOutputs(readyPwm, readyOe, true));
  assert(readyPwm.callCount == PCA9685_OUTPUT_COUNT);
  for (uint8_t channel = 0; channel < PCA9685_OUTPUT_COUNT; ++channel) {
    assert(readyPwm.channels[channel] == channel);
    assert(readyPwm.onValues[channel] == 0);
    assert(readyPwm.offValues[channel] == 4096);
  }
  assert(readyOe.enabledPin == PCA9685_OUTPUT_ENABLE_PIN);
  assert(readyOe.enableCount == 1);
}
```

- [ ] **Step 3: Run the new test and verify RED**

Run:

```bash
c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp \
  -o /tmp/sesame_servo_translation_test
```

Expected: compilation fails because `sesame_servo_map.h` does not exist.

- [ ] **Step 4: Implement the minimal shared header**

Create `firmware/common/sesame_servo_map.h` with this public shape and exact tables:

```cpp
#ifndef SESAME_SERVO_MAP_H
#define SESAME_SERVO_MAP_H

#include <stdint.h>

constexpr uint8_t SERVO_COUNT = 8;
constexpr uint8_t PCA9685_OUTPUT_COUNT = 16;
constexpr uint8_t INVALID_PCA9685_CHANNEL = 0xFF;
constexpr uint16_t SERVO_MIN_PULSE = 150;
constexpr uint16_t SERVO_MAX_PULSE = 512;
constexpr uint8_t SERVO_FREQUENCY_HZ = 50;
constexpr uint8_t PCA9685_OUTPUT_ENABLE_PIN = 18;

struct ServoDefinition {
  uint8_t channel;
  const char* abbreviation;
  uint8_t logicalIndex;
  const char* logicalName;
};

constexpr ServoDefinition SERVO_MAP[SERVO_COUNT] = {
    {0, "ULF", 2, "L1"}, {1, "ULB", 3, "L2"},
    {2, "LLF", 6, "L3"}, {3, "LLB", 7, "L4"},
    {4, "URF", 0, "R1"}, {5, "URB", 1, "R2"},
    {6, "LRF", 5, "R3"}, {7, "LRB", 4, "R4"},
};

constexpr uint8_t LOGICAL_TO_PCA_CHANNEL[SERVO_COUNT] = {4, 5, 0, 1, 7, 6, 2, 3};

constexpr uint8_t pcaChannelForLogicalServo(uint8_t logicalIndex) {
  return logicalIndex < SERVO_COUNT
             ? LOGICAL_TO_PCA_CHANNEL[logicalIndex]
             : INVALID_PCA9685_CHANNEL;
}

struct TranslatedServoCommand {
  bool valid;
  uint8_t pcaChannel;
  uint8_t adjustedAngle;
};

constexpr TranslatedServoCommand translateServoCommand(
    uint8_t logicalIndex, int angle, const int8_t trims[SERVO_COUNT]) {
  if (logicalIndex >= SERVO_COUNT) {
    return {false, INVALID_PCA9685_CHANNEL, 0};
  }
  int adjusted = angle + trims[logicalIndex];
  adjusted = adjusted < 0 ? 0 : adjusted;
  adjusted = adjusted > 180 ? 180 : adjusted;
  return {true, pcaChannelForLogicalServo(logicalIndex),
          static_cast<uint8_t>(adjusted)};
}

constexpr uint16_t servoAngleToPulse(uint8_t angle) {
  return angle >= 180
             ? SERVO_MAX_PULSE
             : SERVO_MIN_PULSE +
                   ((SERVO_MAX_PULSE - SERVO_MIN_PULSE) * angle) / 180;
}

template <typename OutputEnable>
void holdServoOutputsDisabled(OutputEnable& outputEnable) {
  outputEnable.configureOutput(PCA9685_OUTPUT_ENABLE_PIN);
  outputEnable.disable(PCA9685_OUTPUT_ENABLE_PIN);
}

template <typename PwmDriver, typename OutputEnable>
bool enableClearedPcaOutputs(PwmDriver& pwm, OutputEnable& outputEnable,
                             bool pcaReady) {
  if (!pcaReady) return false;
  for (uint8_t channel = 0; channel < PCA9685_OUTPUT_COUNT; ++channel) {
    pwm.setPWM(channel, 0, 4096);
  }
  outputEnable.enable(PCA9685_OUTPUT_ENABLE_PIN);
  return true;
}

#endif
```

- [ ] **Step 5: Make the diagnostic header consume the shared core**

At the top of `firmware/test/robotics_esp32s3/robotics_esp32s3_servo_map.h`, add:

```cpp
#include "../../common/sesame_servo_map.h"
```

Remove its duplicate definitions of `ServoDefinition`, `SERVO_COUNT`, pulse
constants, OE pin, `SERVO_MAP`, `servoAngleToPulse()`,
`holdServoOutputsDisabled()`, and the old enable-only helper. Keep display
pairing, test angles, and `formatServoCell()` in this diagnostic-specific
header.

Change the diagnostic sketch's final startup call from:

```cpp
enableServoOutputs(servoOutputEnable);
```

to:

```cpp
enableClearedPcaOutputs(pwm, servoOutputEnable, true);
```

The helper clears all sixteen channels before lowering OE; remove the now
redundant eight-channel startup-clear loop from the sketch.

- [ ] **Step 6: Update the existing host test for the new activation helper**

In `tests/robotics_esp32s3_servo_map_test.cpp`, retain physical labels and OLED
pair assertions. Replace its direct `enableServoOutputs()` assertion with a
fake PWM plus `enableClearedPcaOutputs(..., true)` assertion, or leave complete
all-sixteen sequencing coverage solely in `sesame_servo_translation_test.cpp`
and remove the obsolete helper call. Keep the configure→disable assertions for
`holdServoOutputsDisabled()`.

- [ ] **Step 7: Run both host tests and verify GREEN**

Run:

```bash
c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp \
  -o /tmp/sesame_servo_translation_test && \
  /tmp/sesame_servo_translation_test

c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/test/robotics_esp32s3 \
  tests/robotics_esp32s3_servo_map_test.cpp \
  -o /tmp/robotics_esp32s3_servo_map_test && \
  /tmp/robotics_esp32s3_servo_map_test
```

Expected: both exit 0 without output.

- [ ] **Step 8: Clean-compile the diagnostic sketch**

Run:

```bash
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/test/robotics_esp32s3
```

Expected: exit 0 and flash/RAM use below board limits.

- [ ] **Step 9: Commit the shared core and canonical diagnostic**

Run:

```bash
git add \
  firmware/common/sesame_servo_map.h \
  firmware/test/robotics_esp32s3.ino \
  firmware/test/robotics_esp32s3/robotics_esp32s3.ino \
  firmware/test/robotics_esp32s3/robotics_esp32s3_servo_map.h \
  tests/robotics_esp32s3_servo_map_test.cpp \
  tests/sesame_servo_translation_test.cpp
git diff --cached --check
git commit -m "Add verified Sesame servo translation core"
```

Verify `git status --short` still shows
`?? firmware/test/robotics_1stservo_test/` and that it was not committed.

---

### Task 2: Apply translation and fail-safe startup to production firmware

**Files:**
- Modify: `firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino:1-190`
- Modify: `firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino:728-840`
- Modify: `firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino:1143-1153`
- Test: `tests/sesame_servo_translation_test.cpp`

**Interfaces:**
- Consumes: Task 1's `translateServoCommand()` and
  `enableClearedPcaOutputs()`.
- Produces: production `setServoAngle(logicalIndex, angle)` behavior and a
  `servoOutputsReady` fail-closed runtime gate.

- [ ] **Step 1: Add the shared include and Arduino OE adapter**

Add after the local upstream-header includes:

```cpp
#include "../common/sesame_servo_map.h"
```

Replace direct GPIO18 startup writes with this adapter near the PCA driver:

```cpp
struct ServoOutputEnable {
  void configureOutput(uint8_t pin) { pinMode(pin, OUTPUT); }
  void disable(uint8_t pin) { digitalWrite(pin, HIGH); }
  void enable(uint8_t pin) { digitalWrite(pin, LOW); }
};

ServoOutputEnable servoOutputEnable;
bool servoOutputsReady = false;
```

Remove duplicate local definitions of `PCA9685_OE_PIN`, `SERVO_COUNT`,
`SERVO_FREQ_HZ`, `SERVOMIN`, and `SERVOMAX`. Update nearby pulse comments to
name `SERVO_MIN_PULSE` and `SERVO_MAX_PULSE`.

- [ ] **Step 2: Remove the stale direct-SPI UWB block**

Delete the production sketch's `UWB_SCK_PIN` through `UWB_EXTON_PIN` constants
and their direct-radio initialization commentary. Replace the block with:

```cpp
// UWB is deliberately absent from this acceptance firmware. The selected
// future architecture is a Makerfabs UART coprocessor; its GPIOs and power
// remain gated by delivered-board verification in the Stage 2 plan.
```

Do not alter the physical optional-header rows in wiring documents.

- [ ] **Step 3: Hold outputs disabled before I2C initialization**

At the start of `setup()`, replace direct `pinMode`/`digitalWrite` calls with:

```cpp
holdServoOutputsDisabled(servoOutputEnable);
```

This call must remain before `Wire.begin(I2C_SDA, I2C_SCL)`.

- [ ] **Step 4: Make PCA startup fail closed**

Replace the current probe-and-always-enable block with:

```cpp
Wire.beginTransmission(PCA9685_I2C_ADDR);
const bool pcaReady = Wire.endTransmission() == 0;
if (!pcaReady) {
  Serial.println(F("PCA9685 not responding at 0x40 - servo outputs remain disabled."));
  Serial.println(F("Check SDA/SCL, VCC on 3V3, and V+ on the 5V servo rail."));
} else {
  pwm.begin();
  pwm.setPWMFreq(SERVO_FREQUENCY_HZ);
  delay(10);
  servoOutputsReady =
      enableClearedPcaOutputs(pwm, servoOutputEnable, pcaReady);
}
```

Do not lower OE anywhere else in the production sketch. Do not command a pose
from `setup()`.

- [ ] **Step 5: Translate production commands at the actuator boundary**

Replace `setServoAngle(uint8_t channel, int angle)` with:

```cpp
void setServoAngle(uint8_t logicalIndex, int angle) {
  if (!servoOutputsReady) return;

  const TranslatedServoCommand command =
      translateServoCommand(logicalIndex, angle, servoSubtrim);
  if (!command.valid) return;

  const uint16_t pulse =
      servoAngleToPulse(command.adjustedAngle);
  pwm.setPWM(command.pcaChannel, 0, pulse);
  delayWithFace(motorCurrentDelay);
}
```

Rename the forward declaration parameter to `logicalIndex` for clarity. Do not
modify callers in `movement-sequences.h`; their logical indices are the input
contract being preserved.

- [ ] **Step 6: Run host tests**

Run both Task 1 host-test commands. Expected: both exit 0.

- [ ] **Step 7: Clean-compile production firmware**

Run:

```bash
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
```

Expected: exit 0 and flash use below 1,310,720 bytes.

- [ ] **Step 8: Verify UWB absence and OE uniqueness**

Run:

```bash
if rg -n 'UWB_|DW3000|DWM3000|DWM1000' \
  firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino; then
  echo "unexpected UWB symbol in production firmware" >&2
  exit 1
fi

test "$(rg -n 'enableClearedPcaOutputs' \
  firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino | wc -l | tr -d ' ')" = "1"
```

Expected: both commands exit 0; the first search prints nothing.

- [ ] **Step 9: Commit production integration**

Run:

```bash
git add firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino
git diff --cached --check
git commit -m "Translate stock Sesame commands to verified PCA channels"
```

---

### Task 3: Correct invariants, netlist identities, and the external audit

**Files:**
- Modify: `scripts/check-wiring-docs.sh`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/wiring/netlist.md`
- Modify: `docs/upstream/divergence.md`
- Modify: `firmware/sesame-s3-pca9685/README.md`
- Modify: `firmware/test/README.md`
- Rewrite: `docs/upstream/external-audit-2026.md`

**Interfaces:**
- Consumes: Task 1 shared map and Task 2 production behavior.
- Produces: a mechanically checked documentary contract separating physical
  channel order from upstream logical identity, plus the requested Grisha
  adoption report.

- [ ] **Step 1: Add a failing exact servo-map documentation check**

Extend `scripts/check-wiring-docs.sh` after the netlist row-count check with a
fixed list of required channel/physical/logical associations:

```bash
required_servo_rows=(
  'ch0|ULF|L1|servoPins[2]'
  'ch1|ULB|L2|servoPins[3]'
  'ch2|LLF|L3|servoPins[6]'
  'ch3|LLB|L4|servoPins[7]'
  'ch4|URF|R1|servoPins[0]'
  'ch5|URB|R2|servoPins[1]'
  'ch6|LRF|R3|servoPins[5]'
  'ch7|LRB|R4|servoPins[4]'
)

mark
for row in "${required_servo_rows[@]}"; do
  IFS='|' read -r channel physical logical upstream <<< "$row"
  line=$(grep -F "PCA9685 \`$channel\` signal" docs/wiring/netlist.md || true)
  [ -n "$line" ] || { err "missing servo row for $channel"; continue; }
  [[ "$line" == *"$physical"* ]] || err "$channel missing physical label $physical"
  [[ "$line" == *"$logical"* ]] || err "$channel missing logical joint $logical"
  [[ "$line" == *"$upstream"* ]] || err "$channel missing $upstream"
done
done_ok "physical servo channels map to upstream logical identities"
```

- [ ] **Step 2: Run the checker and verify RED**

Run:

```bash
bash scripts/check-wiring-docs.sh
```

Expected: failure because the current netlist incorrectly associates ch0 with
`servoPins[0]` and similarly assumes same-number identity for all rows.

- [ ] **Step 3: Correct the architecture invariant**

Replace invariant 5 in `ARCHITECTURE.md` with this meaning:

```text
Upstream logical servo identity is preserved through an explicit translation.
Movement data and APIs use R1,R2,L1,L2,R4,R3,L3,L4 at logical indices 0..7;
the verified PCA9685 channels are 4,5,0,1,7,6,2,3 respectively. Logical index
must never again be assumed to equal physical channel.
```

Update the Stage 1 status to record that all eight physical PCA channels and
OLED labels were verified on 2026-09-14, while complete production animation
and loaded floor operation remain pending.

- [ ] **Step 4: Correct netlist rows 19–26**

Write each physical wiring row with both naming systems:

```text
ch0 → ULF — Upper Left Front; upstream L1 / servoPins[2]
ch1 → ULB — Upper Left Back; upstream L2 / servoPins[3]
ch2 → LLF — Lower Left Front; upstream L3 / servoPins[6]
ch3 → LLB — Lower Left Back; upstream L4 / servoPins[7]
ch4 → URF — Upper Right Front; upstream R1 / servoPins[0]
ch5 → URB — Upper Right Back; upstream R2 / servoPins[1]
ch6 → LRF — Lower Right Front; upstream R3 / servoPins[5]
ch7 → LRB — Lower Right Back; upstream R4 / servoPins[4]
```

Replace the false same-index paragraph with the exact translation table and a
link to `docs/upstream/divergence.md`.

- [ ] **Step 5: Correct divergence and firmware documentation**

In `docs/upstream/divergence.md`:

- replace claims that channel `n` equals logical index `n`;
- document translation `{4,5,0,1,7,6,2,3}` at the hardware boundary;
- state that upstream headers remain unchanged;
- update Stage 1 evidence from three-servo to verified physical all-eight
  mapping while leaving production animation acceptance open;
- remove the firmware UWB-constant change from the firmware-delta table.

In `firmware/sesame-s3-pca9685/README.md`:

- add the logical-to-physical table;
- document that subtrim uses logical identity;
- document all-sixteen full-off before OE enable and fail-closed `0x40` probe;
- replace the UWB-constants section with a statement that UWB runtime is absent
  and Stage 2 owns future UART integration;
- add the staged Rest → Stand → Wave → raised Walk → Stop acceptance sequence.

In `firmware/test/README.md`:

- keep `0 ULF` through `7 LRB` as physical diagnostic labels;
- add the corresponding upstream names;
- explain that the production translation differs from physical test order;
- record the upstream build-guide procedure: fit joints while motors hold
  Stand, then alternate Rest/Stand before fastening and before Wave.

- [ ] **Step 6: Rewrite the Grisha/Henkaku adoption report accurately**

Rewrite `docs/upstream/external-audit-2026.md` as a concise evidence matrix with
these fixed source commits and rulings:

| Feature | Evidence | Ruling |
|---|---|---|
| Serial `face`/`fc` | upstream `c458a9e`, hardware log | already retained |
| Native USB CDC and DTR behavior | committed bridge source + hardware log | firmware ready; bridge deferred |
| Grisha PCA9685 conversion | hardware log only, source absent | do not infer or copy |
| Physical/logical servo map | local eight-channel test + upstream manifest | implement explicit translation |
| Subtrim | committed upstream/local source | retain logical indexing |
| Stand-position horn fitting | upstream build guide + Grisha failure record | adopt procedure |
| Rich PCA register dump | log only | defer |
| SafeAction | sim2real project constraint | later host-side work |
| ESP32Servo version pin | upstream S2/direct-PWM concern | reject as inapplicable |
| S2 GPIO/power choices | S2 build-specific | reject for S3 hardware |

Include source URLs and commit IDs. State explicitly that the report's earlier
same-channel conclusion was invalidated by the user's physical test. Avoid USB
endpoint hexadecimal values so the wiring checker does not mistake them for
I2C addresses.

- [ ] **Step 7: Run document checks and verify GREEN**

Run:

```bash
bash scripts/check-wiring-docs.sh
git diff --check
```

Expected: both exit 0. The wiring checker reports 34 rows and confirms the
physical-to-logical servo associations.

- [ ] **Step 8: Commit documentation atomically**

Run:

```bash
git add \
  scripts/check-wiring-docs.sh \
  ARCHITECTURE.md \
  docs/wiring/netlist.md \
  docs/upstream/divergence.md \
  docs/upstream/external-audit-2026.md \
  firmware/sesame-s3-pca9685/README.md \
  firmware/test/README.md
git diff --cached --check
git commit -m "Document verified physical and logical servo identities"
```

---

### Task 4: Run end-state verification and independent review

**Files:**
- Verify only: all files changed in Tasks 1–3
- Do not modify or stage: `firmware/test/robotics_1stservo_test/`

**Interfaces:**
- Consumes: the complete code and documentation change.
- Produces: review evidence proving readiness for a separately authorized
  hardware upload.

- [ ] **Step 1: Run both host tests from a clean command line**

```bash
c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp \
  -o /tmp/sesame_servo_translation_test && \
  /tmp/sesame_servo_translation_test

c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/test/robotics_esp32s3 \
  tests/robotics_esp32s3_servo_map_test.cpp \
  -o /tmp/robotics_esp32s3_servo_map_test && \
  /tmp/robotics_esp32s3_servo_map_test
```

Expected: both exit 0.

- [ ] **Step 2: Clean-compile both Arduino sketches**

```bash
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/test/robotics_esp32s3

arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
```

Expected: both exit 0 and remain below board flash/RAM limits.

- [ ] **Step 3: Verify upstream headers have not changed**

Run:

```bash
printf '%s  %s\n' \
  722692894402d9eccf5c022ed7b4eb090c2de6b171b7872cedce55609dac1f06 \
  firmware/sesame-s3-pca9685/face-bitmaps.h \
  f77d713703e361dff2458f4fd02356ed397b8f47d83bd7a87587e8f6e899d2f1 \
  firmware/sesame-s3-pca9685/movement-sequences.h \
  f28273df29c4f38cce3005604f883ad161f920ae25168b1a62aa986886a5e8a4 \
  firmware/sesame-s3-pca9685/captive-portal.h \
  | shasum -a 256 -c -
```

Expected: all three print `OK`.

- [ ] **Step 4: Verify documents, UWB absence, and diff hygiene**

```bash
bash scripts/check-wiring-docs.sh
if rg -n 'UWB_|DW3000|DWM3000|DWM1000' \
  firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino; then
  exit 1
fi
git diff --check
git status --short
```

Expected: checks pass; the production search prints nothing. The only allowed
untracked path outside committed work is
`firmware/test/robotics_1stservo_test/`.

- [ ] **Step 5: Request independent code review**

Use the `superpowers:requesting-code-review` skill. Give the reviewer the spec,
plan, base commit, and current commit. Require explicit review of:

1. exact map `{4,5,0,1,7,6,2,3}`;
2. logical subtrim semantics;
3. all-sixteen full-off before OE enable;
4. failure at `0x40` leaving OE HIGH;
5. no automatic movement at boot;
6. no UWB runtime symbols;
7. physical netlist rows matching shared code; and
8. unchanged upstream movement/face/portal headers.

Expected: reviewer verdict `OK` or concrete findings. Resolve all P0/P1 findings
and repeat Steps 1–5 before proceeding.

- [ ] **Step 6: Record final verification state**

Run:

```bash
git log -4 --oneline
git status --short
```

Report exact commit IDs, test/build outcomes, and whether any reviewer finding
remains. Do not claim hardware acceptance from compile or unit-test evidence.

---

### Task 5: Perform the user-controlled first production run

**Files:**
- No repository changes required unless hardware evidence is recorded after the run.

**Interfaces:**
- Consumes: Task 4's clean review and the assembled robot.
- Produces: physical confirmation of boot safety, servo translation, stock pose
  calibration, Wi-Fi control, and Stop behavior.

- [ ] **Step 1: Obtain explicit physical-state confirmation**

Before any upload, confirm all of the following with the user:

```text
ESP32 removed from robot circuit for flashing
battery disconnected during flashing
robot available to be raised for movement test
LM2596 path previously measured at 5.0–5.2 V
physical power switch reachable
spare known-good OLED installed
```

- [ ] **Step 2: Upload production firmware to the isolated ESP32**

With no serial monitor holding the port, run the documented Arduino upload
command against the detected `/dev/cu.usbmodem*` port. Expected: esptool flash
and verification succeed.

- [ ] **Step 3: Reinstall and boot without a motion command**

Reconnect the ESP32, raise the robot, select battery/LM2596 servo power, and
boot. Pass conditions:

```text
no servo moves during boot
OLED displays startup/face output
Sesame-Controller AP becomes visible
serial output does not report PCA9685 failure
```

Power off immediately if any servo moves before a user command.

- [ ] **Step 4: Validate Rest and Stand**

Command Rest once and inspect every joint. Command Stand once and inspect the
mirrored stance. Alternate Rest and Stand while checking for wrong-joint
motion, binding, buzzing, reset, regulator sag, or heat.

Pass condition: all eight joints move to the expected geometry and the robot
returns cleanly between the two poses.

- [ ] **Step 5: Validate Wave, raised Walk, and Stop**

While the robot remains raised:

1. run Wave and confirm the intended front leg moves without clipping;
2. run Walk and immediately exercise Stop;
3. confirm OLED animation and Wi-Fi control remain responsive.

Floor testing is permitted only after all suspended checks pass.

- [ ] **Step 6: Report the acceptance boundary**

Report each result separately:

```text
boot safety
OLED
Wi-Fi AP and portal
Rest
Stand
Wave
raised Walk
Stop
floor movement, if attempted
```

A partial pass must remain partial; do not label Stage 1 complete until every
required production behavior has direct hardware evidence.
