# Makerfabs Stage 2 Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate two Makerfabs ESP32 UWB DW3000 WROOM boards as UART-connected ranging coprocessors for two Sesame robots and prove the complete system against explicit accuracy, recovery, coexistence, and power criteria.

**Architecture:** Each robot ESP32-S3 retains movement, OLED, Wi-Fi, and swarm responsibilities. A Makerfabs ESP32 owns DW3000 timing and DS-TWR, then publishes bounded versioned ASCII events over UART; hardware-specific pins and power routing enter the netlist only after delivered-board inspection.

**Tech Stack:** ESP32 Arduino, Makerfabs/NConcepts DW3000 library, C++17 host tests, Python 3 acceptance analysis, Markdown/CSV hardware records.

**Spec:** [`docs/superpowers/specs/2026-09-09-stage1-as-built-makerfabs-design.md`](../specs/2026-09-09-stage1-as-built-makerfabs-design.md)

## Global Constraints

- Hardware: exactly two purchased Makerfabs ESP32 UWB DW3000 WROOM boards for Stage 2.
- Pin, connector, logic-level, and supply claims come from the delivered revision and matching schematic, not product-page assumptions.
- Initial robot-to-Makerfabs integration uses separate USB power and a common signal ground.
- Do not approve the existing servo rail for UWB until idle, ranging-average, and peak current are measured and regulator headroom is calculated.
- Robot ESP32-S3 owns movement/PCA9685, OLED, Wi-Fi, robot identity, and range expiry.
- Makerfabs ESP32 owns DW3000 timestamps, DS-TWR state, peer scheduling, and UWB diagnostics.
- UART is 115200 baud, 8N1, newline-delimited ASCII, protocol version `V1`.
- Node IDs are runtime configuration; do not create separate firmware binaries per robot.
- A range older than three expected update intervals is stale and cannot be consumed as current position data.
- Pin-map, netlist, power document, BOM, and integration table change together after pins and power are verified.
- Preserve the optional raw-radio header and its open-drain `RSTn` invariant; it is not the selected Stage 2 route.
- Do not vendor upstream binaries. Reference Makerfabs repository commit `9d449b8bdb07f464791cf09ec3b36aeb3c4f6595`; keep only this project's modified sources.
- Complete Gate 1 before Tasks 2–7. Complete each later task in order.

---

### Task 1: Audit both delivered boards

**Files:**
- Create: `hardware/uwb/makerfabs/README.md`
- Create: `hardware/uwb/makerfabs/board-audit.json`
- Create: `hardware/uwb/makerfabs/photos/` evidence files
- Create: `scripts/check-makerfabs-audit.py`

**Interfaces:**
- Consumes: both delivered Makerfabs boards, a multimeter, USB power meter or current-capable bench supply, and the matching schematic.
- Produces: machine-checked `board-audit.json`; later tasks consume its `uart`, `power`, `logic_voltage_v`, `antenna_edge`, and per-board identity fields.

- [ ] **Step 1: Write the failing audit validator**

Create `scripts/check-makerfabs-audit.py` using only Python's standard library. It must load `hardware/uwb/makerfabs/board-audit.json` and fail unless:

```python
required_top = {
    "audit_date", "product", "upstream_commit", "schematic",
    "logic_voltage_v", "uart", "power", "antenna_edge", "boards"
}
required_uart = {"makerfabs_rx_label", "makerfabs_tx_label", "ground_label"}
required_power = {
    "bench_input", "idle_ma", "ranging_average_ma", "ranging_peak_ma",
    "shared_rail_decision", "decision_reason"
}
required_board = {"unit", "module", "board_revision", "front_photo", "back_photo"}
```

Additional assertions:

- `product == "Makerfabs ESP32 UWB DW3000 WROOM"`;
- `upstream_commit == "9d449b8bdb07f464791cf09ec3b36aeb3c4f6595"`;
- `logic_voltage_v` is numeric and between 3.0 and 3.6;
- current values are positive numbers;
- exactly two board objects exist with distinct `unit` values;
- every referenced photo exists; and
- no string value is empty or one of `unknown`, `pending`, `unset`, or `not-measured` case-insensitively.

Run:

```bash
python3 scripts/check-makerfabs-audit.py
```

Expected: FAIL because the audit file does not exist.

- [ ] **Step 2: Photograph and identify both units**

Save front and back images as:

```text
hardware/uwb/makerfabs/photos/unit-1-front.jpg
hardware/uwb/makerfabs/photos/unit-1-back.jpg
hardware/uwb/makerfabs/photos/unit-2-front.jpg
hardware/uwb/makerfabs/photos/unit-2-back.jpg
```

Record all visible PCB revision and module markings exactly. Confirm both are WROOM, not WROVER.

- [ ] **Step 3: Match the delivered revision to its schematic**

Compare physical headers and continuity to the Makerfabs schematic. Identify labels for:

- Makerfabs UART RX;
- Makerfabs UART TX;
- signal ground;
- reset/enable;
- every supported external supply input; and
- UWB antenna edge.

Do not select robot GPIOs yet.

- [ ] **Step 4: Measure electrical characteristics**

With the boards USB-powered and running first idle and then the supplied ranging example, record:

- logic-high UART voltage;
- idle current;
- ranging-average current over 60 seconds; and
- highest observed ranging current.

Set `shared_rail_decision` to exactly `approved`, `dedicated-regulator`, or `separate-power`. The reason must compare measured peak current plus the documented servo requirement against regulator capacity.

- [ ] **Step 5: Write and validate the audit record**

Create `board-audit.json` with the validated fields and a `README.md` that explains test instruments, measurement method, schematic source, antenna observations, and the power decision.

Run:

```bash
python3 scripts/check-makerfabs-audit.py
bash scripts/check-wiring-docs.sh
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add hardware/uwb/makerfabs scripts/check-makerfabs-audit.py
git diff --cached --check
git commit -m "Record Makerfabs board arrival audit"
```

### Task 2: Establish the unmodified Makerfabs ranging baseline

**Files:**
- Create: `hardware/uwb/makerfabs/baseline.csv`
- Create: `hardware/uwb/makerfabs/baseline.md`
- Create: `scripts/analyze-makerfabs-baseline.py`

**Interfaces:**
- Consumes: Task 1 board identities and Makerfabs upstream commit `9d449b8b...`.
- Produces: measured stock-example performance and a proven board/toolchain baseline before custom DS-TWR work.

- [ ] **Step 1: Write the failing baseline analyzer**

Create `scripts/analyze-makerfabs-baseline.py`. It must parse CSV columns:

```text
unit_pair,target_mm,reported_mm,valid,sample_ms,reset_event,recovered_ms
```

Require target distances `500`, `1000`, `2000`, and `5000`; at least 120 samples per target; numeric monotonic `sample_ms`; and at least one reset test for each unit. Print per-distance median absolute error, valid percentage, and valid updates/second. Exit nonzero when required data is absent.

Run:

```bash
python3 scripts/analyze-makerfabs-baseline.py hardware/uwb/makerfabs/baseline.csv
```

Expected: FAIL because no baseline data exists.

- [ ] **Step 2: Fetch the exact upstream source outside this repository**

```bash
rm -rf /tmp/Makerfabs-ESP32-UWB-DW3000
git clone https://github.com/Makerfabs/Makerfabs-ESP32-UWB-DW3000.git \
  /tmp/Makerfabs-ESP32-UWB-DW3000
git -C /tmp/Makerfabs-ESP32-UWB-DW3000 checkout \
  9d449b8bdb07f464791cf09ec3b36aeb3c4f6595
```

Install the `Dw3000/` library in the local Arduino environment without copying it into this project.

- [ ] **Step 3: Prove basic device access**

Compile and flash `Dw3000/examples/ex_00a_reading_dev_id/` to each board as `ESP32 Dev Module`. Record the device ID and serial port in `baseline.md`. A zero or repeated all-`FF` ID fails the gate.

- [ ] **Step 4: Run the supplied ranging pair unchanged**

Flash:

- unit 1: `Dw3000/examples/ex_06a_ss_twr_initiator/`;
- unit 2: `Dw3000/examples/ex_06b_ss_twr_responder/`.

At 0.5 m, 1 m, 2 m, and 5 m measured antenna-to-antenna line-of-sight distances, capture at least 120 reports per distance into `baseline.csv`. Reset unit 1 once and unit 2 once during separate runs and record recovery time.

- [ ] **Step 5: Analyze and document the baseline**

```bash
python3 scripts/analyze-makerfabs-baseline.py hardware/uwb/makerfabs/baseline.csv
```

`baseline.md` must record Arduino core/library versions, exact upstream commit, antenna orientation, environment, commands, analyzer output, observed bias, dropout pattern, and whether custom work may proceed. This task characterizes stock SS-TWR; it does not claim DS-TWR acceptance.

- [ ] **Step 6: Commit**

```bash
git add hardware/uwb/makerfabs/baseline.csv \
  hardware/uwb/makerfabs/baseline.md scripts/analyze-makerfabs-baseline.py
git diff --cached --check
git commit -m "Measure Makerfabs stock ranging baseline"
```

### Task 3: Implement the shared versioned UART protocol

**Files:**
- Create: `firmware/shared/uwb-protocol.h`
- Create: `firmware/shared/uwb-protocol.cpp`
- Create: `tests/uwb-protocol-test.cpp`
- Create: `scripts/test-uwb-protocol.sh`

**Interfaces:**
- Produces:

```cpp
enum class UwbMessageType {
  Hello, Configure, Start, Stop, StatusRequest,
  Ready, Range, Status, Error, Invalid
};

struct UwbMessage {
  UwbMessageType type;
  uint8_t node;
  uint8_t peer;
  uint32_t distanceMm;
  int32_t quality;
  uint32_t sampleMs;
  char text[48];
};

bool parseUwbLine(const char* line, UwbMessage* out);
bool formatUwbMessage(const UwbMessage& message, char* out, size_t capacity);
```

- Consumed by both Makerfabs and robot-host firmware.

- [ ] **Step 1: Write fail-first protocol tests**

In `tests/uwb-protocol-test.cpp`, assert parsing and formatting for these exact lines:

```text
V1 HELLO
V1 CONFIG node=1 peer=2
V1 START
V1 STOP
V1 STATUS
V1 READY fw=0.1.0 node=1
V1 RANGE peer=2 mm=1234 quality=-87 sample_ms=42000
V1 STATUS state=ranging
V1 ERROR code=bad-command
```

Also assert rejection of:

```text
V2 HELLO
V1 CONFIG node=1
V1 RANGE peer=2 mm=-1 quality=0 sample_ms=4
V1 START extra=yes
<161 printable characters followed by newline>
```

Use an output buffer of 161 bytes and require every successfully formatted line to fit within 160 bytes excluding the null terminator.

Create `scripts/test-uwb-protocol.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
CXX=${CXX:-clang++}
"$CXX" -std=c++17 -Wall -Wextra -Werror \
  firmware/shared/uwb-protocol.cpp tests/uwb-protocol-test.cpp \
  -o /tmp/uwb-protocol-test
/tmp/uwb-protocol-test
```

Run it and expect compilation failure because the protocol files do not exist.

- [ ] **Step 2: Implement the bounded parser and formatter**

Implement the declared API without heap allocation, Arduino `String`, exceptions, or unbounded copies. Parsing must reject unsupported versions, missing keys, duplicate keys, unknown extra keys, negative unsigned values, and overlong lines. On failure set `out->type` to `Invalid` and leave no partial active configuration for callers to apply.

- [ ] **Step 3: Run tests to GREEN**

```bash
chmod +x scripts/test-uwb-protocol.sh
bash scripts/test-uwb-protocol.sh
```

Expected: `uwb protocol tests passed` and no compiler warnings.

- [ ] **Step 4: Commit**

```bash
git add firmware/shared tests/uwb-protocol-test.cpp scripts/test-uwb-protocol.sh
git diff --cached --check
git commit -m "Add versioned UWB UART protocol"
```

### Task 4: Implement two-node DS-TWR on the Makerfabs ESP32

**Files:**
- Create: `firmware/makerfabs-uwb/makerfabs-uwb.ino`
- Create: `firmware/makerfabs-uwb/ds-twr-math.h`
- Create: `firmware/makerfabs-uwb/ds-twr-math.cpp`
- Create: `firmware/makerfabs-uwb/README.md`
- Create: `tests/ds-twr-math-test.cpp`
- Modify: `scripts/test-uwb-protocol.sh`

**Interfaces:**
- Consumes: Task 3 protocol and Makerfabs DW3000 API pinned in Task 2.
- Produces: one runtime-configurable firmware binary for node IDs 1 or 2; lower node ID initiates DS-TWR, higher node ID responds.

- [ ] **Step 1: Write fail-first timestamp/range tests**

Define:

```cpp
struct DsTwrIntervals {
  uint64_t roundA;
  uint64_t roundB;
  uint64_t replyA;
  uint64_t replyB;
};

double dsTwrTimeOfFlightDtu(const DsTwrIntervals& intervals);
uint64_t subtractTimestamp40(uint64_t later, uint64_t earlier);
```

Test ordinary and 40-bit-wrap subtraction. Test the DS-TWR equation:

```text
ToF = (roundA * roundB - replyA * replyB) /
      (roundA + roundB + replyA + replyB)
```

Reject a zero denominator and any interval set where the numerator is non-positive.

Run the host test and expect failure because implementation is absent.

- [ ] **Step 2: Implement and test DS-TWR math**

Use `long double` for intermediate products. Keep conversion from DW3000 device-time units to metres outside this pure function so calibration constants remain board-specific.

Extend `scripts/test-uwb-protocol.sh` to compile/run both test binaries. Expected: both suites pass without warnings.

- [ ] **Step 3: Implement the radio state machine**

Create one sketch with states:

```cpp
enum class RadioState { Stopped, Ready, PollTx, WaitResponse, FinalTx, WaitFinal, Fault };
```

Rules:

- boot in `Stopped` and respond to `HELLO`/`STATUS`;
- accept `CONFIG` only in `Stopped`;
- require distinct node and peer IDs in range 1–254;
- on `START`, lower ID initiates and higher ID responds;
- exchange Poll, Response, and Final messages carrying node IDs, sequence number, and required timestamps;
- ignore frames whose node IDs or sequence do not match the active transaction;
- timeout returns to the appropriate idle role and increments a diagnostic counter;
- successful initiator calculation emits `V1 RANGE`;
- `STOP` aborts the transaction and returns to `Stopped`; and
- radio failure enters `Fault` while UART `HELLO`, `STATUS`, and `STOP` remain responsive.

Adapt the minimum necessary API calls from Makerfabs examples; do not copy the upstream library into this repository.

- [ ] **Step 4: Compile both runtime configurations from one source**

Compile once for `ESP32 Dev Module`. Flash the same binary to both boards, then configure IDs over UART. Record build command, ESP32 core version, library path/commit, and serial commands in `firmware/makerfabs-uwb/README.md`.

- [ ] **Step 5: Bench-test DS-TWR before robot integration**

Repeat 0.5 m, 1 m, 2 m, and 5 m tests. Confirm ranges are emitted at least twice per second and that `STOP`, reconfiguration while stopped, invalid reconfiguration while running, timeout, and peer reset behave as specified.

- [ ] **Step 6: Commit**

```bash
git add firmware/makerfabs-uwb tests/ds-twr-math-test.cpp \
  scripts/test-uwb-protocol.sh
git diff --cached --check
git commit -m "Implement two-node Makerfabs DS-TWR firmware"
```

### Task 5: Integrate the UWB host without blocking robot control

**Files:**
- Create: `firmware/sesame-s3-pca9685/uwb-host.h`
- Create: `firmware/sesame-s3-pca9685/uwb-host.cpp`
- Create: `tests/uwb-host-test.cpp`
- Modify: `firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino`
- Modify: `scripts/test-uwb-protocol.sh`

**Interfaces:**
- Consumes: `parseUwbLine`, delivered-board UART mapping from Task 1, and `millis()` supplied to host polling.
- Produces:

```cpp
struct RangeState {
  bool available;
  bool stale;
  uint8_t peer;
  uint32_t distanceMm;
  int32_t quality;
  uint32_t sampleMs;
  uint32_t receivedMs;
};

class UwbHost {
 public:
  void begin(uint8_t node, uint8_t peer, uint32_t expectedIntervalMs);
  void ingest(char byte, uint32_t nowMs);
  void tick(uint32_t nowMs);
  const RangeState& range() const;
};
```

- [ ] **Step 1: Write fail-first host tests**

Test byte-at-a-time input split at every possible boundary for a valid RANGE line. Test malformed input, 161-byte overflow, unsupported version, unknown peer, makerfabs reboot (`READY`), disconnect with no bytes, reconnect, and `uint32_t` millisecond wrap. Assert:

- valid range becomes available;
- stale becomes true after more than `3 * expectedIntervalMs`;
- malformed/overlong input does not replace the last valid range;
- `READY` clears availability until a new valid range arrives; and
- no input operation loops or waits for another byte.

Run the test and expect compilation failure before creating `uwb-host.cpp`.

- [ ] **Step 2: Implement the bounded line receiver**

Use a fixed 161-byte buffer. Overflow discards through the next newline and increments an error counter. Call the shared parser only on complete lines. Store `receivedMs` separately from radio `sampleMs` for local stale detection.

- [ ] **Step 3: Run host/protocol/math tests**

Extend `scripts/test-uwb-protocol.sh` to compile the host test with shared sources. Run it and require all three test binaries to pass without warnings.

- [ ] **Step 4: Integrate with the robot sketch**

Use the exact UART pins verified in Task 1. Initialize a dedicated `HardwareSerial` at 115200 8N1. In every `loop()` pass:

- consume only currently available bytes;
- call `tick(millis())`;
- never wait for a line, response, or range;
- leave PCA9685/OLED/Wi-Fi scheduling unchanged; and
- expose current/stale/unavailable range state in diagnostics without treating stale data as position.

- [ ] **Step 5: Compile and commit**

```bash
arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
bash scripts/test-uwb-protocol.sh
git add firmware/sesame-s3-pca9685 firmware/shared \
  tests/uwb-host-test.cpp scripts/test-uwb-protocol.sh
git diff --cached --check
git commit -m "Integrate nonblocking UWB host"
```

### Task 6: Make verified Stage 2 wiring authoritative

**Files:**
- Modify: `docs/wiring/pin-map.md`
- Modify: `docs/wiring/netlist.md`
- Modify: `docs/wiring/power.md`
- Modify: `docs/wiring/expansion.md`
- Modify: `hardware/bom.md`
- Modify: `hardware/uwb/makerfabs/README.md`
- Test: `scripts/check-wiring-docs.sh`

**Interfaces:**
- Consumes: exact delivered-board labels and power decision from `board-audit.json`, plus the robot GPIOs used by Task 5.
- Produces: one authoritative Stage 2 wiring table consistent with compiled firmware.

- [ ] **Step 1: Add a failing cross-document consistency check**

Extend `scripts/check-makerfabs-audit.py` to read the chosen robot TX/RX GPIO numbers from `board-audit.json` and fail unless both numbers appear in the pin map, netlist, Makerfabs README, and robot firmware constants. Also require the audited `shared_rail_decision` to match the power and BOM wording.

Run it and expect FAIL because authoritative documents have not yet been updated.

- [ ] **Step 2: Update pins and nets together**

Use the exact audited mapping:

- robot TX → Makerfabs RX;
- robot RX ← Makerfabs TX;
- robot ground ↔ Makerfabs ground; and
- the approved audited power route.

Do not reuse a reserved or forbidden GPIO. If the selected GPIO conflicts with another function, stop and revise the pin choice rather than documenting a multiplexed connection.

- [ ] **Step 3: Update power and BOM**

Document measured current and the actual decision: shared rail only if approved by audit, otherwise the dedicated regulator or separate-power route. Include conductor gauge, connector identity, and ground relationship based on the built harness.

- [ ] **Step 4: Run checks and commit**

```bash
python3 scripts/check-makerfabs-audit.py
bash scripts/check-wiring-docs.sh
arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
git add docs/wiring hardware/bom.md hardware/uwb/makerfabs/README.md \
  scripts/check-makerfabs-audit.py firmware/sesame-s3-pca9685
git diff --cached --check
git commit -m "Document verified Makerfabs Stage 2 wiring"
```

### Task 7: Run complete two-robot acceptance

**Files:**
- Create: `hardware/uwb/makerfabs/stage2-acceptance.csv`
- Create: `hardware/uwb/makerfabs/stage2-acceptance.md`
- Create: `scripts/analyze-stage2-acceptance.py`
- Modify: `ARCHITECTURE.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: two complete robot/controller pairs from Tasks 1–6.
- Produces: machine-checked pass/fail evidence and the decision whether four-robot design may begin.

- [ ] **Step 1: Write the failing acceptance analyzer**

Require CSV columns:

```text
run,target_mm,reported_mm,valid,sample_ms,recovery_ms,uart_reconnected,
servo_active,oled_ok,wifi_ok,supply_min_v,supply_max_v
```

The analyzer must enforce:

- targets 500, 1000, 2000, and 5000 mm;
- at least 120 samples per target;
- median absolute error at most 200 mm at every target;
- at least two valid ranges per second;
- at least 90 percent valid samples over a two-minute stationary run;
- all recorded reboot recovery values at most 5000 ms;
- all UART reconnect, servo, OLED, and Wi-Fi flags true; and
- supply values within the limits documented in `docs/wiring/power.md`.

Run it and expect FAIL because acceptance data does not exist.

- [ ] **Step 2: Execute stationary accuracy and dropout runs**

Collect antenna-to-antenna measurements at all four target distances, at least 120 samples each, followed by a continuous two-minute run. Do not delete invalid samples from the CSV.

- [ ] **Step 3: Execute recovery tests**

Record separate tests for:

- reboot of Makerfabs unit 1;
- reboot of Makerfabs unit 2;
- UART TX disconnect/reconnect;
- UART RX disconnect/reconnect; and
- temporary UWB obstruction/loss.

Robot movement/OLED tasks must continue; stale data must become unavailable rather than remaining current.

- [ ] **Step 4: Execute coexistence and power tests**

With UWB ranging and Wi-Fi active, operate OLED and the verified three servos. Record rail minimum/maximum and radio behavior. If the eight-servo harness has since passed its separate power gate, repeat with representative eight-servo motion; otherwise state that it remains a separate production acceptance item.

- [ ] **Step 5: Analyze and record the result**

```bash
python3 scripts/analyze-stage2-acceptance.py \
  hardware/uwb/makerfabs/stage2-acceptance.csv
```

Create `stage2-acceptance.md` with date, firmware commits, physical arrangement, commands, analyzer output, failures/retests, and a final `PASS` or `FAIL`. Only `PASS` authorizes four-robot design.

- [ ] **Step 6: Update phase status and commit**

Update `ARCHITECTURE.md` and `AGENTS.md` with the measured result. Do not claim four-robot capability.

```bash
git add hardware/uwb/makerfabs/stage2-acceptance.* \
  scripts/analyze-stage2-acceptance.py ARCHITECTURE.md AGENTS.md
git diff --cached --check
git commit -m "Record two-robot UWB acceptance"
```

### Task 8: Close Stage 2 and decide whether to design four-robot ranging

**Files:**
- Modify only if Gate 5 passed: `docs/wiring/expansion.md`
- Create only if Gate 5 passed: a separate four-robot design spec through the brainstorming workflow

**Interfaces:**
- Consumes: `stage2-acceptance.md` final result.
- Produces: either a documented blocker/remediation decision or authorization to begin a separate six-pair TDMA design.

- [ ] **Step 1: Verify the acceptance result**

```bash
rg -n '^Final result: (PASS|FAIL)$' \
  hardware/uwb/makerfabs/stage2-acceptance.md
```

If `FAIL`, stop Stage 2 expansion, record which acceptance criterion failed, and create a focused remediation plan. Do not buy or install two additional boards as part of this plan.

- [ ] **Step 2: If PASS, update the roadmap**

Record that two-node integration is accepted and that four-node work still requires a new design for six pairwise ranges, TDMA scheduling, coordinator recovery, and update-rate allocation.

- [ ] **Step 3: Run final verification**

```bash
bash scripts/test-uwb-protocol.sh
python3 scripts/check-makerfabs-audit.py
python3 scripts/analyze-makerfabs-baseline.py hardware/uwb/makerfabs/baseline.csv
python3 scripts/analyze-stage2-acceptance.py \
  hardware/uwb/makerfabs/stage2-acceptance.csv
bash scripts/check-wiring-docs.sh
git diff --check
git status --short
```

Expected: all applicable checks pass and the working tree is clean.

## Self-review

- Tasks follow all six hardware/firmware gates from the approved design.
- Delivered-board facts are captured before pins or power enter authoritative documents.
- The UART protocol has exact syntax, bounded APIs, fail-first tests, and explicit failure behavior.
- DS-TWR math and robot-host parsing are independently host-testable.
- Acceptance thresholds exactly match the design: 0.20 m median absolute error, two valid ranges per second, under 10 percent invalid samples, and five-second reboot recovery.
- Four-robot TDMA is explicitly outside Stage 2 and starts only after a measured PASS.
