# Photo-Based Stage 1 Record and Makerfabs Stage 2 Design

**Date:** 2026-09-09
**Status:** Approved design

## Purpose

Replace the unverified generated wiring diagrams with a Stage 1 record based on the colleague-tested wiring table and perfboard layout, then define the full Stage 2 integration path for the two purchased Makerfabs ESP32 UWB DW3000 WROOM boards.

The netlist remains the authority for production construction. Photographs and tables record evidence and intent; they do not prove hidden connections.

## Scope

This design covers:

1. retiring every generated wiring SVG and its generator;
2. documenting the tested Stage 1 build from two raster sources;
3. preserving the distinction between the colleague-tested build and the safer production target;
4. integrating one Makerfabs UWB board as a coprocessor on each robot;
5. a two-board ranging and robot-integration acceptance sequence; and
6. the gate for later four-robot scaling.

It does not assign Stage 2 GPIOs or power pins before the delivered boards are inspected. It does not design the four-robot TDMA schedule.

## Authoritative Stage 1 evidence

### Verified wiring table

Copy the supplied screenshot from the desktop inbox into the repository as:

`hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png`

The table records the colleague-tested Stage 1 connections:

| Function | Connection |
|---|---|
| Battery input | 7.4 V 2S 14500 positive and negative to LM2596S `IN+` and `IN-` |
| Main 5 V supply | LM2596S `OUT+`, adjusted to 5.0 V, to ESP32-S3 `5V` and PCA9685 servo `V+` |
| Main ground | LM2596S `OUT-` to the shared perfboard ground rail and every module ground |
| I2C data | SSD1306 `SDA` and PCA9685 `SDA` to ESP32-S3 GPIO2 |
| I2C clock | SSD1306 `SCL` and PCA9685 `SCL` to ESP32-S3 GPIO3 |
| Logic supply | SSD1306 `VCC` and PCA9685 logic `VCC` to ESP32-S3 `3V3(OUT)` |
| Servo signals | MG90S servos 1–3 signal wires to PCA9685 channels 0, 1, and 2 |
| Servo power | Servos 1–3 red wires to PCA9685 `V+`; brown/black wires to PCA9685 `GND` |

The PNG wiring table specifies a 7.4 V battery input. The separate 6.8 V captured-condition annotation appears on `20260901_CircuitBoardDesign_002_Fixed.jpg`, not on the PNG table; neither image is a battery specification.

### Perfboard layout

`hardware/circuit layout/20260901_CircuitBoardDesign_002_Fixed.jpg` is the physical routing and placement reference for the tested board. It shows the rail routing and intended module locations but cannot prove underside continuity or every installed connection.

### Verification boundary

Verified:

- power-up through the LM2596S;
- shared GPIO2/GPIO3 I2C operation; and
- movement of three servos on PCA9685 channels 0–2.

Not verified:

- all eight servos;
- simultaneous eight-servo current;
- complete animation playback;
- Wi-Fi in the stacked perfboard placement;
- UWB; and
- exact agreement of hidden underside wiring with the production netlist.

### Production-target separation

The tested build uses 5.0 V and a compact stacked arrangement. The production target retains its separate requirements in the wiring documents:

- antenna overhang and keep-out;
- star-branch power distribution;
- PCA9685 output-enable control;
- the 1000 µF servo bulk capacitor;
- explicit separation of PCA9685 logic `VCC` and servo `V+`; and
- a power-budget review before eight servos or UWB share a supply.

The tested images do not override those requirements.

## Diagram retirement

Delete the entire generated-diagram implementation:

- every `.svg` under `docs/wiring/diagrams/`;
- `docs/wiring/diagrams/generate.py`;
- `docs/wiring/diagrams/README.md`; and
- the abandoned `tests/test_wiring_diagrams.py` work.

Update all internal links and prose that refer to these diagrams. Git history is the archive; no obsolete generator remains capable of recreating them.

No new vector or Mermaid diagram replaces them in this phase. Stage 1 uses evidence-backed raster images and text. Stage 2 uses text, wiring tables, interface contracts, and acceptance records until delivered hardware establishes the physical facts.

## Stage 2 hardware architecture

Each robot uses two controllers:

```text
Robot ESP32-S3 Super Mini
  I2C -> PCA9685 and SSD1306
  UART -> Makerfabs ESP32 UWB DW3000 WROOM
             onboard SPI -> DW3000
```

### Robot ESP32-S3 responsibilities

- movement and PCA9685 control;
- OLED output;
- Wi-Fi and higher-level swarm behavior;
- authoritative robot/node identity; and
- consumption, expiry, and publication of range measurements.

### Makerfabs board responsibilities

- DW3000 initialization and radio diagnostics;
- UWB timestamp handling;
- dual-sided two-way ranging;
- peer scheduling within the current two-node phase; and
- delivery of processed range/status events over UART.

The robot ESP32-S3 does not handle raw UWB timing. The Makerfabs ESP32 does not command servos.

## Stage 2 UART boundary

Use 115200 baud, 8 data bits, no parity, and one stop bit. Messages are newline-delimited ASCII during Stage 2 so both endpoints can be diagnosed with an ordinary serial console.

Each line begins with protocol version `V1`.

Host commands:

```text
V1 HELLO
V1 CONFIG node=<node-id> peer=<peer-id>
V1 START
V1 STOP
V1 STATUS
```

Coprocessor events:

```text
V1 READY fw=<version>
V1 ACK command=CONFIG
V1 ACK command=START
V1 ACK command=STOP
V1 RANGE peer=<peer-id> seq=<sequence> mm=<distance> quality=<driver-value> sample_ms=<timestamp>
V1 STATUS state=<state>
V1 ERROR code=<code>
```

Requirements:

- node IDs are runtime configuration, not separate firmware binaries;
- `READY` means the coprocessor is unconfigured, including after a reboot; receiving `HELLO` aborts any transaction, clears configuration, and emits `READY`;
- `CONFIG` is accepted only while stopped, and each accepted `CONFIG`, `START`, or `STOP` produces the matching `V1 ACK command=CONFIG|START|STOP` event;
- robot-host boot and recovery use the same handshake: send `HELLO`, wait for `READY`, send `CONFIG`, wait for its ACK, send `START`, and wait for its ACK;
- a command timeout retries the command currently awaiting acknowledgement; a `READY` received while ranging immediately clears range availability and restarts the handshake;
- host parsing, retry timing, and bounded outbound-line retrieval cannot block robot control or require a blocking serial write;
- malformed lines, unknown commands, unsupported protocol versions, and ACKs for commands not currently awaited return or are treated as errors without changing active configuration;
- every `RANGE` includes the UWB transaction sequence so the two robot hosts can correlate equivalent results;
- a range older than three expected update intervals is stale and cannot be consumed as current position data;
- line parsing is bounded and cannot block robot control; and
- the raw quality field is documented after the selected DW3000 driver establishes its meaning.

A binary UART protocol is deferred unless measurements show that ASCII framing is inadequate.

## Power and physical integration gates

No Makerfabs UART GPIO, connector pin, or robot power feed becomes authoritative before board arrival.

Bench integration order:

1. power the robot controller and Makerfabs board separately over USB;
2. connect a common signal ground before UART TX/RX;
3. verify logic levels and crossed TX/RX using the delivered board revision;
4. measure Makerfabs idle, ranging-average, and peak current;
5. compare the result with the existing eight-servo power budget; and
6. choose either the existing 5 V rail, a dedicated regulator, or continued separate power based on measured headroom.

After the audit selects candidate UART GPIOs and a power route, the robot sketch constants/integration, pin map, netlist, power document, expansion guide, BOM, audit cross-check, and Stage 2 integration table change together when Task 6 promotes those candidates to authoritative assignments.

The ESP32-S3 Wi-Fi antenna and Makerfabs UWB antenna each require clear placement. Final spacing and orientation are established by coexistence tests, not product photographs.

## Stage 2 acceptance sequence

### Gate 1 — arrival audit

For both boards:

- photograph front and back;
- record board revision, module markings, and WROOM identity;
- match the delivered headers to the correct schematic;
- identify UART, ground, reset, and supported power inputs;
- verify logic voltage;
- identify the UWB antenna edge and required keep-out; and
- after reviewing the current pin map, record candidate robot TX/RX GPIOs and the reason they do not conflict with assigned, reserved, or forbidden pins.

The arrival audit records candidates only. It does not edit the authoritative pin map, netlist, or robot sketch, and no GPIO value may be selected before the boards arrive.

### Gate 2 — unmodified standalone baseline

Build and flash the supplied Makerfabs DW3000 examples without modifying radio behavior. At measured 0.5 m, 1 m, 2 m, and 5 m line-of-sight separations, record:

- reported range distribution;
- fixed bias;
- valid update rate;
- dropped/invalid samples; and
- recovery after resetting either board.

This gate proves the purchased hardware and local toolchain before custom firmware is introduced.

### Gate 3 — two-node DS-TWR coprocessor firmware

Implement deterministic two-node dual-sided two-way ranging on the Makerfabs boards. Configure node identities at runtime. Keep all radio timing local to the Makerfabs ESP32 and expose only the approved UART contract.

For each sequence, define the six 40-bit DW3000 timestamps exactly as follows:

- `t1 = poll_tx` at the initiator;
- `t2 = poll_rx` at the responder;
- `t3 = response_tx` at the responder;
- `t4 = response_rx` at the initiator;
- `t5 = final_tx` at the initiator; and
- `t6 = final_rx` at the responder.

Use wrap-safe 40-bit subtraction to map `roundA = t4 - t1`, `replyA = t3 - t2`, `roundB = t6 - t3`, and `replyB = t5 - t4`. Poll and Response establish the sequence and addressed initiator/responder pair. Final carries `t1`, `t4`, and `t5`; the responder combines them with local `t2`, `t3`, and `t6`, calculates the range and quality, emits its local sequence-bearing `V1 RANGE`, then sends a fourth Result frame containing the same range and quality. Result carries the same sequence, initiator address, and responder address. The initiator validates all three fields before emitting an equivalent local `V1 RANGE`; a wrong-address, wrong-sequence, or missing Result cannot publish a range. This is transaction correlation and addressing, not cryptographic authentication.

### Gate 4 — robot-host integration

Implement a bounded UART parser, bounded outbound command queue, explicit link state, retry timer, and range-state record on the ESP32-S3. Verify the HELLO/READY/CONFIG-ACK/START-ACK boot sequence, start, stop, status, malformed input, disconnect/reconnect, stale-range expiry, and Makerfabs reboot while PCA9685 and OLED tasks continue operating. Recovery to equivalent range delivery on both hosts within five seconds must be testable without blocking reads or writes.

After delivered-board inspection selects pins, update the robot sketch's UART constants and integration, `docs/wiring/pin-map.md`, `docs/wiring/netlist.md`, `docs/wiring/power.md`, `docs/wiring/expansion.md`, the BOM, the arrival-audit cross-check, and the integration table in one commit.

### Gate 5 — complete two-robot acceptance

The two complete robot/controller pairs pass when:

- median absolute range error is at most 0.20 m at 0.5 m, 1 m, 2 m, and 5 m line-of-sight;
- each pair produces at least two valid ranges per second;
- invalid or missing samples remain below 10 percent during a two-minute stationary run;
- either Makerfabs board can reboot and resume valid range delivery within five seconds;
- UART disconnect/reconnect does not reset or stall robot control;
- OLED and three-servo operation continue during ranging;
- Wi-Fi remains usable with both radio systems active; and
- measured supply voltage remains within the documented rail limits during representative servo motion.

Acceptance evidence uses CSV columns for `event_type`, `unit`, and `host`, as well as the transaction sequence for range rows. Every target must contain at least 120 range samples delivered to each robot host, and the analyzer must reject any sequence whose two host rows do not carry equivalent range values. It must also reject a data set unless it contains explicit `reboot-unit-1`, `reboot-unit-2`, `uart-tx-disconnect`, `uart-rx-disconnect`, `uwb-loss`, and `coexistence` events. These completeness checks are in addition to, not replacements for, every numeric and boolean threshold above.

The all-eight-servo test remains a separate production-power acceptance gate if the full harness is not yet available.

### Gate 6 — four-robot decision

Purchase or install two more UWB boards only after Gate 5 passes. Four-robot work then receives a separate design for six pairwise ranges, TDMA scheduling, coordinator recovery, and update-rate allocation. Stage 2 does not pre-commit that protocol.

## Failure handling

- A UWB failure cannot stop servo control or OLED updates.
- Missing ranges expire to an explicit stale/unavailable state; old data is never silently reused.
- Unknown peers are reported but not inserted into the active configuration.
- A malformed UART line is discarded at newline and produces an error event.
- Buffer overflow discards the current line, reports an error, and resumes at the next newline.
- Radio initialization or ranging failure leaves the coprocessor responsive to `HELLO`, `STATUS`, and `STOP`.
- Brownout or reset evidence blocks shared-rail approval until the power design changes.

## Verification strategy

Immediate documentation verification:

- no SVG, generator, SVG test, or links to `docs/wiring/diagrams/` remain;
- the Stage 1 README embeds or links both raster sources;
- all internal links pass `scripts/check-wiring-docs.sh`;
- Stage 1 wording never exceeds the verified three-servo boundary; and
- no provisional Stage 2 GPIO appears in the authoritative pin map or netlist.

Future firmware verification:

- parser tests are written before robot-host parser implementation;
- protocol state tests cover stopped/configured/ranging/error transitions, command ACKs, timeout retries, and READY-triggered recovery;
- malformed, overlong, stale, unsupported-version, wrong-sequence, wrong-address, and missing-Result inputs are fail-first tests;
- timestamp tests prove the six-timestamp interval mapping and wrap-safe subtraction;
- transaction tests prove equivalent sequence-bound range values reach both robot hosts;
- acceptance-analyzer tests prove that each required event and either host's samples cannot be omitted;
- Makerfabs radio firmware is tested independently before UART integration; and
- every hardware gate produces a dated acceptance record with commands, firmware revisions, measurements, and pass/fail results.

## Repository status after immediate documentation work

- Stage 1 is documented by the verified wiring-table screenshot, perfboard layout image, photographs, and explicit evidence boundary.
- Generated wiring diagrams are absent.
- Two Makerfabs ESP32 UWB DW3000 WROOM evaluation boards are purchased but not yet integrated.
- Stage 2 has a complete execution sequence, but exact wiring remains intentionally gated on delivered hardware.
