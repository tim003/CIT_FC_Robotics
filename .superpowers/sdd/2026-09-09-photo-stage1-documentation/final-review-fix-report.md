# Final Review Fix Wave Report

**Date:** 2026-09-09

**Scope:** Final review corrections for the Stage 1 evidence record and Makerfabs Stage 2 design/implementation plan.

## Result

All six review findings were corrected without changing either authoritative GPIO document or either evidence image. Stage 1 remains limited to the recorded power-up, GPIO2/GPIO3 I2C operation, and movement of three servos. Makerfabs GPIO assignments and power integration remain gated on delivered-board audit.

## RED/GREEN: invocation-path regression

### RED

Before changing `scripts/check-stage1-evidence.sh`, the checker was invoked from `/tmp` by absolute path:

```bash
cd /tmp && /Users/tw/Documents/Obsidian_note/Projects/robotics/.worktrees/stage1-asbuilt-makerfabs/scripts/check-stage1-evidence.sh
```

It exited 1 because all repository-relative paths were resolved under `/tmp`. Representative output:

```text
FAIL: missing verified wiring-table image: hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png
rg: docs/wiring/README.md: IO error for operation on docs/wiring/README.md: No such file or directory
FAIL: Stage 1 README missing: 2026-09-07-stage1-verified-wiring-table.png
...
FAIL: expansion guide does not gate exact UART GPIOs
```

### GREEN

Added `SCRIPT_DIR`/`ROOT` resolution and `cd "$ROOT"` immediately after strict-mode setup, then reran the identical command:

```text
Stage 1 evidence checks passed
```

The immediate implementation plan's embedded checker now contains the same root setup.

## Requirement-to-change mapping

### 1. DS-TWR calculation and delivery to both robot hosts

Updated the approved spec and Stage 2 plan to define:

- `t1 = poll_tx` at initiator;
- `t2 = poll_rx` at responder;
- `t3 = response_tx` at responder;
- `t4 = response_rx` at initiator;
- `t5 = final_tx` at initiator; and
- `t6 = final_rx` at responder.

The documents now map the intervals with wrap-safe 40-bit subtraction:

- `roundA = t4 - t1`;
- `replyA = t3 - t2`;
- `roundB = t6 - t3`; and
- `replyB = t5 - t4`.

Final carries `t1`, `t4`, and `t5`. The responder combines them with local `t2`, `t3`, and `t6`, calculates range/quality, emits its local sequence-bearing `V1 RANGE`, and sends a fourth Result frame. Result is bound to the sequence, initiator address, and responder address. The initiator validates all three fields before emitting an equivalent local `V1 RANGE`.

The planned state machine now includes `ResultTx` and `WaitResult`. Fail-first tests are required for timestamp mapping, 40-bit wrap, wrong sequence, both wrong-address cases, missing Result, and equal sequence/distance/quality values at both UART endpoints. The documents explicitly characterize these checks as transaction correlation, not cryptographic authentication.

### 2. Robot-host commands, acknowledgements, and recovery

The V1 protocol now includes:

```text
V1 ACK command=CONFIG
V1 ACK command=START
V1 ACK command=STOP
```

`UwbMessageType` adds `Ack`, RANGE adds a transaction sequence, and protocol tests cover all three ACKs plus rejection of unsupported ACK command values.

The planned `UwbHost` now has:

- an explicit `UwbLinkState`;
- bounded `nextTxLine` retrieval;
- `requestStart` and `requestStop` controls;
- a fixed-capacity outbound queue; and
- bounded timeout/retry behavior with no serial writes inside the host library.

Boot and reboot recovery are explicit: queue HELLO, receive READY as an unconfigured state, queue CONFIG and await ACK, queue START and await ACK, then enter ranging. READY during ranging clears range availability and restarts the handshake. Host tests must simulate retries, STOP/START, READY during ranging, bounded retrieval, and recovery to equivalent range availability within 5000 ms.

### 3. GPIO audit and atomic promotion ordering

Task 1's audit schema now records `robot_tx_gpio_candidate`, `robot_rx_gpio_candidate`, and `selection_reason`. The audit validator must cross-check candidates against the current pin map, and the plan explicitly states they are non-authoritative audit inputs.

Task 5 now commits only the pin-independent host library, shared protocol changes, tests, and test runner. It no longer edits or compiles `.ino` GPIO integration.

Task 6 now promotes audited candidates atomically with:

- robot `.ino` UART constants and nonblocking integration;
- pin map;
- netlist;
- power document;
- expansion guide;
- BOM;
- Makerfabs integration table; and
- audit cross-check.

The plan forbids inventing GPIOs before board arrival and requires rechecking candidates against the then-current pin map before promotion.

### 4. Acceptance completeness and both-host evidence

The acceptance CSV now requires `event_type`, `unit`, `host`, and `sequence` in addition to the existing measurement and status fields.

The analyzer plan now requires:

- at least 120 range rows per host at every 500/1000/2000/5000 mm target;
- exactly paired host rows for every `(run, target_mm, sequence)` transaction;
- equivalent valid/range values across both hosts;
- per-host error, update-rate, and two-minute validity checks; and
- explicit `reboot-unit-1`, `reboot-unit-2`, `uart-tx-disconnect`, `uart-rx-disconnect`, `uwb-loss`, and `coexistence` events.

Fail-first analyzer tests remove each host/case from otherwise-passing fixtures and test mismatched paired values and reboot recovery over 5000 ms. Existing thresholds remain: 200 mm median absolute error, two valid ranges/second, 90 percent valid stationary samples, 5000 ms reboot recovery, required true integration flags, and documented supply limits.

### 5. Voltage attribution

The Stage 1 evidence README and approved spec now state that the PNG wiring table specifies 7.4 V battery input. They attribute the separate 6.8 V captured-condition annotation only to `20260901_CircuitBoardDesign_002_Fixed.jpg`. The immediate plan was aligned with the same wording. Neither image was modified.

### 6. Invocation-path safety

`scripts/check-stage1-evidence.sh` now resolves its own directory, derives the repository root, and changes to that root before accessing repository-relative paths. The same code appears in the immediate implementation plan.

## Changed files

- `docs/superpowers/specs/2026-09-09-stage1-as-built-makerfabs-design.md`
- `docs/superpowers/plans/2026-09-09-makerfabs-stage2-integration.md`
- `docs/superpowers/plans/2026-09-09-photo-stage1-documentation.md`
- `hardware/circuit layout/README.md`
- `scripts/check-stage1-evidence.sh`
- `.superpowers/sdd/2026-09-09-photo-stage1-documentation/final-review-fix-report.md`

## Verification

All required focused checks passed:

```text
/tmp absolute-path invocation: Stage 1 evidence checks passed
bash scripts/check-stage1-evidence.sh: Stage 1 evidence checks passed
bash scripts/check-wiring-docs.sh: all consistency checks passed
retired asset check: No SVG files, diagram directory, or SVG test found
git diff --check: passed
protected wiring files: unchanged
```

Protected file hashes remained:

```text
10d1665e542051501e4dfb01daf7bbda57c1b891  docs/wiring/netlist.md
519caf3a775f184b33907a3785e404efc500ab06  docs/wiring/pin-map.md
```

## Concerns

None for this documentation-only fix wave. Future Stage 2 execution remains blocked on physical board arrival and audit; no actual Makerfabs GPIO or power assignment was introduced.
