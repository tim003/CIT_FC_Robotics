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
- Robot sketch UART constants/integration, pin map, netlist, power document, expansion guide, BOM, audit cross-check, and integration table change together after pins and power are verified.
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
- Produces: machine-checked `board-audit.json`; later tasks consume its candidate robot UART GPIOs and selection reason, Makerfabs UART labels, `power`, `logic_voltage_v`, `antenna_edge`, and per-board identity fields. Candidate GPIOs recorded here are audit inputs, not authoritative assignments.

- [ ] **Step 1: Write the failing audit validator**

Create `scripts/check-makerfabs-audit.py` using only Python's standard library. It must load `hardware/uwb/makerfabs/board-audit.json` and fail unless:

```python
required_top = {
    "audit_date", "product", "upstream_commit", "schematic",
    "logic_voltage_v", "uart", "power", "antenna_edge", "boards"
}
required_uart = {
    "makerfabs_rx_label", "makerfabs_tx_label", "ground_label",
    "robot_tx_gpio_candidate", "robot_rx_gpio_candidate", "selection_reason"
}
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
- candidate robot TX/RX GPIOs are distinct integers that the validator cross-checks against the current pin map as available, non-reserved candidates;
- the candidate selection reason names the pin-map review and why neither candidate conflicts with an existing function;
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

Then inspect the current `docs/wiring/pin-map.md` and record distinct candidate robot TX and RX GPIO numbers plus a selection reason showing that existing assignments, reserved pins, and forbidden pins were checked. These candidates do not become authoritative in this task: do not edit the pin map, netlist, or robot sketch, and do not wire them into the robot until Task 6 commits the complete integration atomically.

- [ ] **Step 4: Measure electrical characteristics**

With the boards USB-powered and running first idle and then the supplied ranging example, record:

- logic-high UART voltage;
- idle current;
- ranging-average current over 60 seconds; and
- highest observed ranging current.

Set `shared_rail_decision` to exactly `approved`, `dedicated-regulator`, or `separate-power`. The reason must compare measured peak current plus the documented servo requirement against regulator capacity.

- [ ] **Step 5: Write and validate the audit record**

Create `board-audit.json` with the validated fields and a `README.md` that explains test instruments, measurement method, schematic source, antenna observations, candidate robot UART GPIO selection, its non-authoritative status, and the power decision.

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
  Ready, Ack, Range, Status, Error, Invalid
};

struct UwbMessage {
  UwbMessageType type;
  uint8_t node;
  uint8_t peer;
  uint32_t sequence;
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
V1 READY fw=0.1.0
V1 ACK command=CONFIG
V1 ACK command=START
V1 ACK command=STOP
V1 RANGE peer=2 seq=17 mm=1234 quality=-87 sample_ms=42000
V1 STATUS state=ranging
V1 ERROR code=bad-command
```

For `V1 STATUS state=ranging`, additionally assert that parsing produces `UwbMessageType::Status` and preserves `ranging` in the bounded status text field. Also assert rejection of:

```text
V2 HELLO
V1 CONFIG node=1
V1 RANGE peer=2 seq=17 mm=-1 quality=0 sample_ms=4
V1 ACK command=STATUS
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

Implement the declared API without heap allocation, Arduino `String`, exceptions, or unbounded copies. Parsing must reject unsupported versions, missing keys, duplicate keys, unknown extra keys, negative unsigned values, ACK commands other than `CONFIG`, `START`, or `STOP`, and overlong lines. On failure set `out->type` to `Invalid` and leave no partial active configuration for callers to apply.

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
- Create: `firmware/makerfabs-uwb/ds-twr-transaction.h`
- Create: `firmware/makerfabs-uwb/ds-twr-transaction.cpp`
- Create: `firmware/makerfabs-uwb/README.md`
- Create: `tests/ds-twr-math-test.cpp`
- Create: `tests/ds-twr-transaction-test.cpp`
- Modify: `scripts/test-uwb-protocol.sh`

**Interfaces:**
- Consumes: Task 3 protocol and Makerfabs DW3000 API pinned in Task 2.
- Produces: one runtime-configurable firmware binary for node IDs 1 or 2; lower node ID initiates DS-TWR, higher node ID responds.
- Production seam: `ds-twr-transaction.h/.cpp` is plain C++ with no Arduino or radio-library dependency. It owns the configured initiator/responder addresses, sequence allocation/correlation, six timestamp slots, transaction state, wrap-safe timeout bookkeeping, responder calculation and Result construction, and initiator Result validation:

```cpp
enum class DsTwrTransactionState {
  Idle, PollTx, WaitResponse, WaitResult,
  WaitFinal, Complete, TimedOut
};

struct DsTwrFrameIdentity {
  uint8_t initiatorAddress;
  uint8_t responderAddress;
  uint32_t sequence;
};

struct DsTwrResult {
  DsTwrFrameIdentity identity;
  uint32_t distanceMm;
  int32_t quality;
};

struct DsTwrTransaction {
  DsTwrTransactionState state;
  uint8_t initiatorAddress;
  uint8_t responderAddress;
  uint32_t sequence;
  uint32_t nextSequence;
  DsTwrTimestamps timestamps;
  uint32_t timeoutMs;
  uint32_t lastActivityMs;
};

void initDsTwrTransaction(
    DsTwrTransaction* context, uint8_t configuredInitiatorAddress,
    uint8_t configuredResponderAddress, uint32_t firstSequence,
    uint32_t timeoutMs);
void resetDsTwrTransaction(DsTwrTransaction* context);
bool beginDsTwrInitiator(
    DsTwrTransaction* context, uint8_t initiatorAddress,
    uint8_t responderAddress, uint32_t nowMs);
DsTwrFrameIdentity currentDsTwrIdentity(
    const DsTwrTransaction& context);
bool recordDsTwrPollTx(
    DsTwrTransaction* context, uint64_t t1PollTx, uint32_t nowMs);
bool acceptDsTwrPoll(
    DsTwrTransaction* context, const DsTwrFrameIdentity& identity,
    uint64_t t2PollRx, uint32_t nowMs);
bool recordDsTwrResponseTx(
    DsTwrTransaction* transaction, uint64_t t3ResponseTx, uint32_t nowMs);
bool acceptDsTwrResponse(
    DsTwrTransaction* transaction, const DsTwrFrameIdentity& identity,
    uint64_t t4ResponseRx, uint32_t nowMs);
bool recordDsTwrFinalTx(
    DsTwrTransaction* transaction, uint64_t t5FinalTx, uint32_t nowMs);
bool completeDsTwrResponder(
    DsTwrTransaction* transaction, const DsTwrFrameIdentity& identity,
    uint64_t carriedT1, uint64_t carriedT4, uint64_t carriedT5,
    uint64_t localT6, long double millimetersPerDtu, int32_t quality,
    uint32_t nowMs, DsTwrResult* result);
bool acceptDsTwrResult(
    DsTwrTransaction* transaction, const DsTwrResult& received,
    uint32_t nowMs, DsTwrResult* accepted);
bool tickDsTwrTransaction(DsTwrTransaction* transaction, uint32_t nowMs);
```

`initDsTwrTransaction` stores the configured address pair, initial sequence, and fixed timeout. `beginDsTwrInitiator(context, initiatorAddress, responderAddress, nowMs)` validates and adopts that address pair, assigns and advances `nextSequence`, clears prior timestamps, starts the timeout clock, and enters `PollTx` without accepting or fabricating `t1`. `currentDsTwrIdentity()` is valid in `PollTx`, allowing the Poll frame to be constructed with the allocated addresses and sequence. Only after radio transmission succeeds and the hardware TX timestamp is readable may `recordDsTwrPollTx(context, t1PollTx, nowMs)` store the actual 40-bit `t1`, refresh the timeout clock, and advance to `WaitResponse`. A PollTx timeout covers failure to obtain the hardware TX timestamp; the WaitResponse timeout starts from successful `recordDsTwrPollTx`. Out-of-order or duplicate `recordDsTwrPollTx` calls return false without changing state or timestamps.

`acceptDsTwrPoll` takes the sequence and correctly configured address pair from a received Poll. Either initiator begin or responder Poll acceptance may start from `Idle`, `Complete`, or `TimedOut`, clearing prior timestamps while retaining configured addresses and the next initiator sequence. `resetDsTwrTransaction` aborts any active transaction to `Idle` without changing configured addresses or `nextSequence`. Every later accept function compares the complete identity before changing state. `completeDsTwrResponder` copies carried `t1/t4/t5` and local `t2/t3/t6` into `DsTwrTimestamps`, invokes the production math API, converts with the supplied board-calibrated `millimetersPerDtu`, and constructs `DsTwrResult`. `acceptDsTwrResult` is the only initiator path to `Complete`. `tickDsTwrTransaction` uses wrap-safe `uint32_t` elapsed-time arithmetic and changes `PollTx` or any active wait to `TimedOut` when its bounded timeout expires. Invalid transitions or identities return false without changing the active transaction.

- [ ] **Step 1: Write fail-first timestamp/range tests**

Define:

```cpp
struct DsTwrTimestamps {
  uint64_t t1PollTx;
  uint64_t t2PollRx;
  uint64_t t3ResponseTx;
  uint64_t t4ResponseRx;
  uint64_t t5FinalTx;
  uint64_t t6FinalRx;
};

struct DsTwrIntervals {
  uint64_t roundA;
  uint64_t roundB;
  uint64_t replyA;
  uint64_t replyB;
};

bool dsTwrIntervalsFromTimestamps(
    const DsTwrTimestamps& timestamps, DsTwrIntervals* out);
double dsTwrTimeOfFlightDtu(const DsTwrIntervals& intervals);
uint64_t subtractTimestamp40(uint64_t later, uint64_t earlier);
```

Use these exact timestamp meanings: `t1 = poll_tx` at the initiator, `t2 = poll_rx` at the responder, `t3 = response_tx` at the responder, `t4 = response_rx` at the initiator, `t5 = final_tx` at the initiator, and `t6 = final_rx` at the responder. Write fail-first tests proving the mapping uses 40-bit subtraction for `roundA = t4 - t1`, `replyA = t3 - t2`, `roundB = t6 - t3`, and `replyB = t5 - t4`, including ordinary and 40-bit-wrap cases. Test the DS-TWR equation:

```text
ToF = (roundA * roundB - replyA * replyB) /
      (roundA + roundB + replyA + replyB)
```

Reject a zero denominator and any interval set where the numerator is non-positive.

In `tests/ds-twr-transaction-test.cpp`, exercise the production API above, not a transaction model declared in the test. Write fail-first tests proving identity and allocated sequence are available from `currentDsTwrIdentity()` before Poll construction; `t1` remains unset until the actual hardware timestamp is passed to `recordDsTwrPollTx`; successful capture advances `PollTx` to `WaitResponse`; out-of-order and duplicate capture are rejected without mutation; PollTx times out if TX/timestamp acquisition does not complete; and WaitResponse timeout timing begins at successful `t1` capture. Also test the exact `t1` through `t6` mapping, 40-bit wrap, rejection of a Result with the wrong sequence, separate wrong-initiator and wrong-responder address cases, timeout when Result is missing, and equal sequence, peer-relative distance, and quality values in the responder Result and the initiator-accepted Result. These tests cover transaction correlation only; do not invent cryptographic authentication.

Run the transaction test compile and expect failure because `ds-twr-transaction.cpp` is absent.

- [ ] **Step 2: Implement and test DS-TWR math and transaction core**

Use `long double` for intermediate products. Keep the DW3000 device-time-unit calibration value outside the pure math function and pass the board-specific millimetres-per-DTU conversion into the transaction core.

Extend `scripts/test-uwb-protocol.sh` with these exact production-source compile/link and execution commands (in addition to the protocol and standalone math commands):

```bash
"$CXX" -std=c++17 -Wall -Wextra -Werror \
  firmware/makerfabs-uwb/ds-twr-math.cpp \
  firmware/makerfabs-uwb/ds-twr-transaction.cpp \
  tests/ds-twr-transaction-test.cpp \
  -o /tmp/ds-twr-transaction-test
/tmp/ds-twr-transaction-test
```

The transaction test must compile and link `firmware/makerfabs-uwb/ds-twr-transaction.cpp`; no duplicate test-only state machine or calculation model is permitted. Expected: all suites pass without warnings.

- [ ] **Step 3: Implement the radio state machine**

Create one sketch with states:

```cpp
enum class RadioState {
  Stopped, Ready, PollTx, WaitResponse, FinalTx, WaitFinal,
  ResultTx, WaitResult, Fault
};
```

Rules:

- boot unconfigured in `Stopped`; `HELLO` aborts any transaction, clears configuration, and returns `V1 READY`, which always means unconfigured/rebooted, while `STATUS` remains available;
- accept `CONFIG` only while stopped (`Stopped` or configured/stopped `Ready`); an accepted `CONFIG`, `START`, or `STOP` emits the corresponding `V1 ACK`;
- require distinct node and peer IDs in range 1–254;
- on `START`, lower ID initiates and higher ID responds;
- every radio frame carries frame type, sequence number, initiator ID, and responder ID; the `.ino` obtains outgoing identities from `currentDsTwrIdentity` and delegates every incoming sequence/address check to the production transaction core, so a frame with any mismatched transaction field is ignored;
- initiator order is exact: the `.ino` calls `beginDsTwrInitiator(context, initiator, responder, nowMs)`, obtains the allocated addresses/sequence from `currentDsTwrIdentity()`, constructs and transmits Poll, reads the actual hardware TX timestamp, and only then calls `recordDsTwrPollTx(context, t1PollTx, nowMs)`; it must not require a delayed-TX timestamp before Poll construction or invent a predicted `t1`;
- all radio-library calls remain in the `.ino`: it passes actual hardware TX/RX timestamps to `recordDsTwrPollTx`, `acceptDsTwrPoll`, `recordDsTwrResponseTx`, `acceptDsTwrResponse`, `recordDsTwrFinalTx`, and `completeDsTwrResponder`, and uses `resetDsTwrTransaction` for aborts; Poll establishes `t1`/`t2`, Response establishes `t3`/`t4`, and Final carries the initiator's 40-bit `t1`, `t4`, and `t5` timestamps so the core can combine them with local `t2`, `t3`, and `t6`;
- the responder maps the six timestamps to the four intervals exactly as tested, calculates distance and quality, emits its local sequence-bearing `V1 RANGE`, enters `ResultTx`, and transmits a fourth Result frame containing sequence, initiator ID, responder ID, distance, and quality;
- after Final transmission the initiator enters `WaitResult`; the `.ino` passes the decoded Result to `acceptDsTwrResult`, and only a Result that the shared core accepts for sequence and both addresses can emit the equivalent local `V1 RANGE`;
- all sequence allocation, address correlation, six-timestamp storage/mapping, timeout transitions, responder Result construction, and initiator Result validation come from `ds-twr-transaction.cpp`; the `.ino` does not duplicate them;
- a missing Result times out through `tickDsTwrTransaction` without publishing an initiator range, returns to the appropriate idle role, and increments a diagnostic counter;
- timeouts in all other transaction states likewise return to the appropriate idle role and increment a diagnostic counter;
- `STOP` aborts the transaction, preserves configuration in `Ready`, and emits its ACK; and
- radio failure enters `Fault` while UART `HELLO`, `STATUS`, and `STOP` remain responsive.

The sequence and address checks prevent accidental transaction mix-ups; they are not cryptographic authentication.

Adapt the minimum necessary API calls from Makerfabs examples; do not copy the upstream library into this repository.

- [ ] **Step 4: Compile both runtime configurations from one source**

Compile once for `ESP32 Dev Module`. Flash the same binary to both boards, then configure IDs over UART. Record build command, ESP32 core version, library path/commit, and serial commands in `firmware/makerfabs-uwb/README.md`.

- [ ] **Step 5: Bench-test DS-TWR before robot integration**

Repeat 0.5 m, 1 m, 2 m, and 5 m tests. Using two serial captures as robot-host stand-ins, confirm equivalent sequence-bound ranges are emitted at both UART endpoints at least twice per second and that `STOP`, reconfiguration while stopped, invalid reconfiguration while running, wrong-sequence/address frames, missing Result timeout, and peer reset behave as specified.

- [ ] **Step 6: Commit**

```bash
git add firmware/makerfabs-uwb tests/ds-twr-math-test.cpp \
  tests/ds-twr-transaction-test.cpp scripts/test-uwb-protocol.sh
git diff --cached --check
git commit -m "Implement two-node Makerfabs DS-TWR firmware"
```

### Task 5: Integrate the UWB host without blocking robot control

**Files:**
- Create: `firmware/sesame-s3-pca9685/uwb-host.h`
- Create: `firmware/sesame-s3-pca9685/uwb-host.cpp`
- Create: `tests/uwb-host-test.cpp`
- Modify: `scripts/test-uwb-protocol.sh`

**Interfaces:**
- Consumes: `parseUwbLine` and wrap-safe millisecond values supplied to host polling. This task is pin-independent and does not modify the robot sketch.
- Produces:

```cpp
struct RangeState {
  bool available;
  bool stale;
  uint8_t peer;
  uint32_t sequence;
  uint32_t distanceMm;
  int32_t quality;
  uint32_t sampleMs;
  uint32_t receivedMs;
};

enum class UwbLinkState {
  Uninitialized, AwaitReady, AwaitConfigAck, Stopped,
  AwaitStartAck, Ranging, AwaitStopAck
};

class UwbHost {
 public:
  void begin(uint8_t node, uint8_t peer, uint32_t expectedIntervalMs);
  void ingest(char byte, uint32_t nowMs);
  void tick(uint32_t nowMs);
  bool nextTxLine(char* out, size_t capacity);
  void requestStart();
  void requestStop();
  void requestStatus();
  UwbLinkState linkState() const;
  const RangeState& range() const;
};
```

`nextTxLine` retrieves at most one complete line from a fixed-capacity outbound queue and returns immediately; serial ownership and nonblocking writes remain with the caller. A newly constructed host is `Uninitialized`. `requestStatus()` is valid after `begin()` in every link state, queues exactly one bounded `V1 STATUS` request without waiting, and neither changes the primary link state nor clears or replaces an active range. At most one STATUS transaction may be outstanding: if the outbound queue is full, one pending STATUS intent is retained and queued when capacity next becomes available; a fixed-interval retry queues at most one replacement after the prior line has been retrieved, and parsing `V1 STATUS state=...` completes that status transaction. Calling `requestStatus()` while uninitialized is a no-op, and repeated calls while one is pending or outstanding do not consume more queue entries.

- [ ] **Step 1: Write fail-first host tests**

Test byte-at-a-time input split at every possible boundary for a valid sequence-bearing RANGE line. Test malformed input, 161-byte overflow, unsupported version, unknown peer, disconnect with no bytes, reconnect, and `uint32_t` millisecond wrap. Assert:

- `begin` sets running as the boot intent, queues `HELLO`, and enters `AwaitReady`;
- `READY` means unconfigured and causes `CONFIG` to be queued, CONFIG ACK automatically causes `START` to be queued for the boot intent, and START ACK enters `Ranging`;
- `requestStop` queues `STOP`, STOP ACK enters configured `Stopped`, and `requestStart` can start again without blocking;
- `requestStatus` queues `V1 STATUS` from every initialized link state, a parsed `V1 STATUS state=ranging` completes the outstanding STATUS transaction without changing that state or the active range, and the uninitialized call is a no-op;
- a command timeout retries only the currently awaited `HELLO`, `CONFIG`, `START`, or `STOP` line, using a fixed retry interval and bounded queue;
- STATUS has an independent single-outstanding retry timer: test its first queueing, retry after retrieval, coalescing of repeated requests, full-queue pending behavior, and eventual queueing after capacity opens, with no queue overflow;
- a `READY` received while ranging clears availability and restarts CONFIG/START handshake;
- simulated READY-triggered recovery with ACKs restores ranging and equivalent range availability within 5000 ms;
- `nextTxLine` returns immediately for both empty and non-empty queues and reports insufficient caller capacity without a partial line;
- valid range becomes available;
- stale becomes true after more than `3 * expectedIntervalMs`;
- malformed/overlong input does not replace the last valid range; and
- no input, tick, control, or transmit-retrieval operation loops or waits for another byte.

Run the test and expect compilation failure before creating `uwb-host.cpp`.

- [ ] **Step 2: Implement bounded receive, transmit, and recovery state**

Use a fixed 161-byte receive buffer and a fixed-capacity outbound-line queue. Overflow discards through the next newline and increments an error counter. Call the shared parser only on complete lines. Store `receivedMs` separately from radio `sampleMs` for local stale detection.

Use a fixed retry interval no greater than 500 ms. `begin` sets running as the requested boot intent and queues `HELLO`; `READY` queues `CONFIG`; matching ACKs automatically advance to START and ranging. Retry only the line for the current await state. Track STATUS request/pending/retry state separately from `UwbLinkState`; status traffic must obey the same fixed queue bound, and handshake/control commands take priority over pending or retry STATUS entries. A `READY` in any later state clears range availability and restarts CONFIG, while preserving the host's requested running/stopped intent. No method writes a serial port or waits for queue space.

- [ ] **Step 3: Run host/protocol/math/transaction tests**

Extend `scripts/test-uwb-protocol.sh` to compile the host test with shared sources. Run it and require all four test binaries to pass without warnings.

- [ ] **Step 4: Commit the pin-independent host library**

```bash
bash scripts/test-uwb-protocol.sh
git add firmware/sesame-s3-pca9685/uwb-host.h \
  firmware/sesame-s3-pca9685/uwb-host.cpp firmware/shared \
  tests/uwb-host-test.cpp scripts/test-uwb-protocol.sh
git diff --cached --check
git commit -m "Add nonblocking UWB host library"
```

Do not add `.ino` UART constants or integration in this task; those must land atomically with authoritative GPIO documentation in Task 6.

### Task 6: Make verified Stage 2 wiring authoritative

**Files:**
- Modify: `firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino`
- Modify: `docs/wiring/pin-map.md`
- Modify: `docs/wiring/netlist.md`
- Modify: `docs/wiring/power.md`
- Modify: `docs/wiring/expansion.md`
- Modify: `hardware/bom.md`
- Modify: `hardware/uwb/makerfabs/README.md`
- Modify: `hardware/uwb/makerfabs/board-audit.json`
- Modify: `scripts/check-makerfabs-audit.py`
- Test: `scripts/check-wiring-docs.sh`

**Interfaces:**
- Consumes: exact delivered-board labels, candidate robot TX/RX GPIOs with selection reason, and power decision from `board-audit.json`, plus Task 5's pin-independent host library.
- Produces: one authoritative Stage 2 wiring table consistent with compiled firmware. This is the only task that promotes candidate GPIOs to assignments.

- [ ] **Step 1: Add a failing cross-document consistency check**

Extend `scripts/check-makerfabs-audit.py` to read `robot_tx_gpio_candidate` and `robot_rx_gpio_candidate` from `board-audit.json` and fail unless both numbers appear as assignments in the pin map, netlist, Makerfabs README integration table, and robot sketch UART constants. Also require the audited `shared_rail_decision` to match the power, expansion, integration-table, and BOM wording.

Run it and expect FAIL because authoritative documents and `.ino` integration have not yet been updated.

- [ ] **Step 2: Reconfirm and promote pins and nets together**

Recheck the audited candidates against the then-current pin map before promotion. Use the exact audited mapping:

- robot TX → Makerfabs RX;
- robot RX ← Makerfabs TX;
- robot ground ↔ Makerfabs ground; and
- the approved audited power route.

Add the exact robot TX/RX constants, dedicated `HardwareSerial` initialization at 115200 8N1, nonblocking receive drain, `tick(millis())`, and bounded `nextTxLine` serial writes to `sesame-s3-pca9685.ino`. Never wait for a line, ACK, transmit capacity, or range; leave PCA9685/OLED/Wi-Fi scheduling unchanged and expose current/stale/unavailable range state without using stale data as position.

Update the `.ino`, pin map, netlist, power document, expansion guide, BOM, audit JSON, audit cross-check, and Makerfabs README integration table as one change. Do not reuse a reserved or forbidden GPIO. If either candidate conflicts with another function, stop and revise the candidate GPIOs in `board-audit.json` and their selection reason before changing any authoritative file. The updated audit JSON and selection reason must be committed in the same commit as the `.ino`, pin map, netlist, power document, expansion guide, BOM, integration table, and audit checker; never document a multiplexed connection.

- [ ] **Step 3: Update power, expansion, BOM, and integration table**

Document measured current and the actual decision everywhere: shared rail only if approved by audit, otherwise the dedicated regulator or separate-power route. Include conductor gauge, connector identity, and ground relationship based on the built harness. Cross-check every promoted GPIO and the power decision against `board-audit.json`.

- [ ] **Step 4: Run checks and commit atomically**

```bash
python3 scripts/check-makerfabs-audit.py
bash scripts/check-wiring-docs.sh
arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
bash scripts/test-uwb-protocol.sh
git add firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino \
  docs/wiring/pin-map.md docs/wiring/netlist.md docs/wiring/power.md \
  docs/wiring/expansion.md hardware/bom.md \
  hardware/uwb/makerfabs/README.md hardware/uwb/makerfabs/board-audit.json \
  scripts/check-makerfabs-audit.py
git diff --cached --check
git commit -m "Integrate verified Makerfabs Stage 2 wiring"
```

Do not split this commit: firmware GPIO constants and every authoritative wiring/power record must agree at its boundary.

### Task 7: Run complete two-robot acceptance

**Files:**
- Create: `hardware/uwb/makerfabs/stage2-acceptance.csv`
- Create: `hardware/uwb/makerfabs/stage2-acceptance.md`
- Create: `scripts/analyze-stage2-acceptance.py`
- Create: `tests/analyze-stage2-acceptance-test.py`
- Modify: `ARCHITECTURE.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: two complete robot/controller pairs from Tasks 1–6.
- Produces: machine-checked pass/fail evidence and the decision whether four-robot design may begin.

- [ ] **Step 1: Write the failing acceptance analyzer**

Require CSV columns:

```text
event_type,run,unit,host,sequence,target_mm,reported_mm,valid,sample_ms,
recovery_ms,uart_reconnected,servo_active,oled_ok,wifi_ok,supply_min_v,
supply_max_v
```

The only allowed concrete identities are `makerfabs-1`, `makerfabs-2`, `robot-1`, and `robot-2`. The value `both` is additionally allowed only in both identity columns for the whole-system `uwb-loss` and `coexistence` events; it is invalid for every other event. The `unit` column accepts Makerfabs identities (or the constrained `both`) and the `host` column accepts robot identities (or the constrained `both`). Range rows use `event_type=range`; two-minute dropout rows use `event_type=stationary`. Recovery and integration rows use the exact required event names below. `sequence` is the UWB transaction sequence, not a CSV row number.

The analyzer must enforce:

- `range` targets 500, 1000, 2000, and 5000 mm for both `robot-1` and `robot-2`;
- at least 120 `range` samples per host at every target;
- every `(run, target_mm, sequence)` range transaction contains exactly two rows: one with (`unit`, `host`) = (`makerfabs-1`, `robot-1`) and one with (`makerfabs-2`, `robot-2`), with no duplicate or additional pair, and both rows have equivalent `valid` and `reported_mm` values;
- median absolute error at most 200 mm at every target for each host;
- at least two valid ranges per second for each host;
- at least 90 percent valid samples for each host over a two-minute stationary run;
- explicit rows for every required event type: `reboot-unit-1`, `reboot-unit-2`, `uart-tx-disconnect`, `uart-rx-disconnect`, `uwb-loss`, and `coexistence`;
- `reboot-unit-1` occurs with (`makerfabs-1`, `robot-1`) and `reboot-unit-2` with (`makerfabs-2`, `robot-2`), and both have recovery values at most 5000 ms;
- each of `uart-tx-disconnect` and `uart-rx-disconnect` has at least one row for (`makerfabs-1`, `robot-1`) and at least one for (`makerfabs-2`, `robot-2`);
- `uwb-loss` and `coexistence` each use exactly (`both`, `both`);
- all applicable UART reconnect, servo, OLED, and Wi-Fi flags are true; and
- supply values are within the limits documented in `docs/wiring/power.md`.

In `tests/analyze-stage2-acceptance-test.py`, build every fixture from an otherwise-passing complete dataset. Keep the existing positive complete-dataset case and negative fixtures for an invalid identity, crossed range pair, duplicated range pair, omitted range pair, each wholly omitted required event, mismatched paired `valid` and `reported_mm` values, removal of one host's target samples, and reboot recovery over 5000 ms.

Add these explicit event-identity mapping fixtures; each negative mutation must make the analyzer fail for the intended event-specific reason:

- map `reboot-unit-1` incorrectly to (`makerfabs-2`, `robot-2`);
- map `reboot-unit-2` incorrectly to (`makerfabs-1`, `robot-1`);
- omit (`makerfabs-1`, `robot-1`) from `uart-tx-disconnect` while retaining its (`makerfabs-2`, `robot-2`) row;
- omit (`makerfabs-2`, `robot-2`) from `uart-tx-disconnect` while retaining its (`makerfabs-1`, `robot-1`) row;
- omit (`makerfabs-1`, `robot-1`) from `uart-rx-disconnect` while retaining its (`makerfabs-2`, `robot-2`) row;
- omit (`makerfabs-2`, `robot-2`) from `uart-rx-disconnect` while retaining its (`makerfabs-1`, `robot-1`) row;
- substitute (`both`, `both`) on a `range` row;
- change a `stationary` row's (`unit`, `host`) to (`both`, `both`);
- substitute (`both`, `both`) on `reboot-unit-1`;
- substitute (`both`, `both`) on `reboot-unit-2` in a separate fixture;
- substitute (`both`, `both`) on `uart-tx-disconnect`;
- substitute (`both`, `both`) on `uart-rx-disconnect` in a separate fixture;
- map `uwb-loss` to non-`both` (`makerfabs-1`, `robot-1`); and
- map `coexistence` to non-`both` (`makerfabs-2`, `robot-2`).

The otherwise-passing positive fixture must contain and preserve both whole-system rows—`uwb-loss` with (`both`, `both`) and `coexistence` with (`both`, `both`)—and prove the analyzer accepts those two mappings. Only this positive case passes; every negative fixture above starts from the same complete dataset and must fail.

Run the analyzer against the absent acceptance CSV and the test suite; expect failure before implementation/data exists.

- [ ] **Step 2: Execute stationary accuracy and dropout runs**

Collect antenna-to-antenna measurements at all four target distances, at least 120 paired sequence-bound rows for each host at each target, followed by a continuous two-minute run recorded for both hosts. Do not delete invalid samples from the CSV. Preserve both hosts' equivalent local `V1 RANGE` lines for each transaction sequence.

- [ ] **Step 3: Execute recovery tests**

Record separate rows with these exact `event_type` values:

- `reboot-unit-1`;
- `reboot-unit-2`;
- `uart-tx-disconnect`;
- `uart-rx-disconnect`; and
- `uwb-loss`.

Map `reboot-unit-1` to (`makerfabs-1`, `robot-1`) and `reboot-unit-2` to (`makerfabs-2`, `robot-2`). Record separate `uart-tx-disconnect` and `uart-rx-disconnect` rows for each of (`makerfabs-1`, `robot-1`) and (`makerfabs-2`, `robot-2`). Record `uwb-loss` as (`both`, `both`). Robot movement/OLED tasks must continue; stale data must become unavailable rather than remaining current. For both reboot events, measure from READY/reboot detection through the repeated CONFIG/START handshake to equivalent range delivery on both hosts; recovery over five seconds fails.

- [ ] **Step 4: Execute coexistence and power tests**

With UWB ranging and Wi-Fi active, operate OLED and the verified three servos. Record this as an explicit `coexistence` event with (`unit`, `host`) = (`both`, `both`), rail minimum/maximum, and radio behavior. If the eight-servo harness has since passed its separate power gate, repeat with representative eight-servo motion; otherwise state that it remains a separate production acceptance item.

- [ ] **Step 5: Analyze and record the result**

```bash
python3 tests/analyze-stage2-acceptance-test.py
python3 scripts/analyze-stage2-acceptance.py \
  hardware/uwb/makerfabs/stage2-acceptance.csv
```

Create `stage2-acceptance.md` with date, firmware commits, physical arrangement, commands, analyzer output, failures/retests, and a final `PASS` or `FAIL`. Only `PASS` authorizes four-robot design.

- [ ] **Step 6: Update phase status and commit**

Update `ARCHITECTURE.md` and `AGENTS.md` with the measured result. Do not claim four-robot capability.

```bash
git add hardware/uwb/makerfabs/stage2-acceptance.* \
  scripts/analyze-stage2-acceptance.py tests/analyze-stage2-acceptance-test.py \
  ARCHITECTURE.md AGENTS.md
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
python3 tests/analyze-stage2-acceptance-test.py
python3 scripts/analyze-stage2-acceptance.py \
  hardware/uwb/makerfabs/stage2-acceptance.csv
bash scripts/check-wiring-docs.sh
git diff --check
git status --short
```

Expected: all applicable checks pass and the working tree is clean.

## Self-review

- Tasks follow all six hardware/firmware gates from the approved design.
- Delivered-board facts and candidate GPIOs are captured before pins or power enter authoritative documents; `.ino` integration and all affected records commit together.
- The UART protocol has exact syntax, ACKs, bounded receive/transmit APIs, retry/recovery state, fail-first tests, and explicit failure behavior.
- DS-TWR timestamp mapping, Result correlation, math, and robot-host parsing are independently host-testable; transaction tests link the same production core consumed by the `.ino`.
- Acceptance requires the exact two Makerfabs/robot identity pairs per range transaction, mapped recovery/integration events, paired equal host values, and all named event cases while retaining the design thresholds: 0.20 m median absolute error, two valid ranges per second, under 10 percent invalid samples, and five-second reboot recovery.
- Four-robot TDMA is explicitly outside Stage 2 and starts only after a measured PASS.
