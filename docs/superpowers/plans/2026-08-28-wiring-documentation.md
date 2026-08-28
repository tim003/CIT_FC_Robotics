# PCA9685 Wiring Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a complete, buildable wiring specification for the PCA9685-based Sesame robot, such that someone can solder the harness from the netlist without reading anything else.

**Architecture:** Seven Markdown documents under `docs/wiring/`, `docs/upstream/`, and `hardware/`, plus a shell script that mechanically verifies cross-document consistency. The netlist is the source of truth; every other document must agree with it, and the checker enforces that rather than trusting review.

**Tech Stack:** Markdown, Mermaid diagrams, POSIX shell + `grep`/`awk` for the consistency checker. No build system, no compilation.

**Spec:** [`docs/superpowers/specs/2026-08-28-pca9685-wiring-design.md`](../specs/2026-08-28-pca9685-wiring-design.md)

## Global Constraints

Copied verbatim from the spec. Every task's requirements implicitly include these.

- **MCU:** Lolin S3 Mini (ESP32-S3), ESP32-S3FH4R2, 4MB flash + 2MB **quad** PSRAM.
- **I2C:** `SDA GPIO35`, `SCL GPIO36`. OLED `0x3C`, PCA9685 `0x40`.
- **SPI (UWB header):** `SCK 12`, `MOSI 11`, `MISO 13`, `CSn 10`, `IRQ 14`, `RSTn 21`, `WAKEUP 16`, `EXTON 17`.
- **PCA9685 `OE`:** `GPIO18`, active-low.
- **Free GPIOs:** 1–9, 33, 34, 37–40.
- **Reserved, never use:** GPIO `0` (boot), `3`/`45`/`46` (strapping), `19`/`20` (USB), `43`/`44` (UART0), `47`/`48` (RGB LED).
- **Servo channels:** ch0–ch7 legs, ch8 reserved output, ch9–ch15 spare.
- **Servo ordering:** PCA9685 channel index must equal upstream `servoPins[8]` index. Upstream array is `{1, 2, 4, 6, 8, 10, 13, 14}`.
- **Power rail:** 5.2V, dual-source (LM2596S *or* USB-C), SPDT-selected, star topology, 1000µF bulk at PCA9685 `V+`.
- **Wire gauge:** 30AWG data, 22AWG power/ground.
- **Upstream base:** `dorianborian/sesame-robot` @ `86d2bf8`.
- **Dates:** ISO `YYYY-MM-DD`.
- **Invariants that must never be contradicted:** servo current never flows through the ESP32; PCA9685 `VCC` (3.3V) ≠ `V+` (5V); UWB `RSTn` open-drain, never driven high; LM2596S set to 5.2V before load.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/check-wiring-docs.sh` | Mechanical consistency checks across all wiring docs |
| `docs/wiring/pin-map.md` | Every GPIO: assigned, free, or forbidden. Foundation for all else |
| `docs/wiring/power.md` | Rail topology, LM2596S procedure, power safety |
| `docs/wiring/netlist.md` | **Source of truth.** Every connection as `from → to` |
| `docs/wiring/expansion.md` | Spare PWM channels + UWB header |
| `docs/wiring/README.md` | Assembly guide: order of work, diagrams, pre-power checks |
| `docs/upstream/divergence.md` | Branch point, firmware changes required, what stays portable |
| `hardware/bom.md` | BOM delta vs upstream |

Ordering is deliberate: the checker exists first so every later task can be verified; `pin-map` and `power` precede `netlist` because the netlist references both; `README` comes late because it summarises the others.

---

### Task 1: Consistency checker

**Files:**
- Create: `scripts/check-wiring-docs.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/check-wiring-docs.sh`, runnable as `bash scripts/check-wiring-docs.sh` from the repo root. Exits `0` on success, `1` with a descriptive message on failure. Every later task runs it.

- [ ] **Step 1: Write the checker**

```bash
#!/usr/bin/env bash
# Mechanical consistency checks for the wiring documentation.
# The netlist is the source of truth; these checks stop the other
# documents from drifting away from it.
set -uo pipefail

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }
ok()  { echo "  ok: $*"; }

DOCS=$(find docs hardware -name '*.md' 2>/dev/null)
[ -n "$DOCS" ] || { echo "no docs found"; exit 1; }

# 1. No placeholders anywhere.
if grep -rniE '\b(TBD|TODO|FIXME|XXX)\b' $DOCS >/dev/null 2>&1; then
  err "placeholder markers found:"
  grep -rniE '\b(TBD|TODO|FIXME|XXX)\b' $DOCS >&2
else
  ok "no placeholders"
fi

# 2. Forbidden GPIOs must never be assigned a function.
#    We only flag them in assignment tables (lines containing '|').
for pin in 0 3 19 20 43 44 45 46 47 48; do
  if grep -rnE "^\|.*GPIO ?${pin}\b" $DOCS 2>/dev/null \
     | grep -viE 'reserved|do not use|forbidden|never|strapping|boot|USB|UART|RGB' >/dev/null; then
    err "forbidden GPIO${pin} appears as an assignment"
  fi
done
ok "no forbidden GPIO assignments"

# 3. I2C addresses must be exactly these two.
addrs=$(grep -rhoE '0x[0-9A-Fa-f]{2}' $DOCS | sort -u | tr '\n' ' ')
if [ "$(echo $addrs)" != "0x3C 0x40" ]; then
  err "unexpected I2C addresses: $addrs (expected '0x3C 0x40')"
else
  ok "I2C addresses correct"
fi

# 4. The dual-supply invariant must be stated wherever PCA9685 power appears.
if grep -rl 'PCA9685' docs/wiring >/dev/null 2>&1; then
  grep -rlE 'V\+' docs/wiring | while read -r f; do
    grep -qiE 'VCC.*3\.?3|3\.?3.*VCC' "$f" \
      || echo "WARN: $f mentions V+ without restating the VCC/V+ distinction" >&2
  done
fi
ok "dual-supply invariant checked"

# 5. RSTn must always carry the open-drain warning.
for f in $(grep -rl 'RSTn' $DOCS 2>/dev/null); do
  grep -qiE 'open.?drain' "$f" || err "$f mentions RSTn without the open-drain warning"
done
ok "RSTn warning present wherever RSTn appears"

# 6. Internal links must resolve.
for f in $DOCS; do
  d=$(dirname "$f")
  grep -oE '\]\(([^)#h][^)#]*)' "$f" 2>/dev/null | sed -E 's/^\]\(//' | while read -r l; do
    [ -z "$l" ] && continue
    [ -e "$d/$l" ] || [ -e "$l" ] || err "$f: dead link -> $l"
  done
done
ok "internal links resolve"

if [ "$fail" -ne 0 ]; then
  echo "consistency checks FAILED" >&2
  exit 1
fi
echo "all consistency checks passed"
```

- [ ] **Step 2: Make it executable and run it**

Run:
```bash
chmod +x scripts/check-wiring-docs.sh
bash scripts/check-wiring-docs.sh
```
Expected: passes (only the spec exists so far, and it satisfies every rule). If it reports the spec's `0x3C`/`0x40` as wrong, the check itself is broken — fix the checker, not the spec.

- [ ] **Step 3: Verify it actually catches a problem**

Run:
```bash
echo "| Test | GPIO45 | bogus |" >> docs/wiring/scratch.md 2>/dev/null || \
  { mkdir -p docs/wiring; echo "| Test | GPIO45 | bogus |" > docs/wiring/scratch.md; }
bash scripts/check-wiring-docs.sh
```
Expected: **FAIL**, naming GPIO45. A checker that never fails is worthless — confirm it fails before trusting it.

- [ ] **Step 4: Remove the scratch file and re-run**

```bash
rm docs/wiring/scratch.md
bash scripts/check-wiring-docs.sh
```
Expected: passes again.

- [ ] **Step 5: Commit**

```bash
git add scripts/check-wiring-docs.sh
git commit -m "Add wiring documentation consistency checker

Mechanically enforces what review would otherwise have to catch:
no placeholders, no forbidden GPIO assignments, exactly two I2C
addresses, the RSTn open-drain warning wherever RSTn appears, and
working internal links. Verified to fail on a planted GPIO45
assignment before being trusted."
```

---

### Task 2: Pin map

**Files:**
- Create: `docs/wiring/pin-map.md`

**Interfaces:**
- Consumes: `scripts/check-wiring-docs.sh` from Task 1.
- Produces: the canonical GPIO assignment table. Tasks 3–6 cite these numbers and must not restate them differently.

- [ ] **Step 1: Write `docs/wiring/pin-map.md`**

Required content, exactly these assignments:

| Function | GPIO | Direction | Notes |
|---|---|---|---|
| I2C SDA | 35 | bidirectional | OLED `0x3C` + PCA9685 `0x40` |
| I2C SCL | 36 | output | |
| PCA9685 `OE` | 18 | output | Active-low; HIGH disables all 16 channels |
| UWB SCK | 12 | output | |
| UWB MOSI | 11 | output | |
| UWB MISO | 13 | input | |
| UWB CSn | 10 | output | |
| UWB IRQ | 14 | input | Interrupt-capable |
| UWB RSTn | 21 | open-drain | **Never drive high** |
| UWB WAKEUP | 16 | output | DWM3000 only; leave NC for DWM1000 |
| UWB EXTON | 17 | input | DWM3000 only; leave NC for DWM1000 |

Free: 1–9, 33, 34, 37–40 (9 ADC-capable).
Forbidden: 0, 3, 19, 20, 43, 44, 45, 46, 47, 48 — each with its reason.

The document must also carry the **octal-PSRAM caveat**: on S3 boards with octal PSRAM, GPIO35/36/37 are consumed by the PSRAM bus; the Lolin S3 Mini's quad PSRAM leaves them free, and porting to an 8MB-PSRAM board requires moving I2C.

Cite the source for the defaults: `espressif/arduino-esp32` `variants/lolin_s3_mini/pins_arduino.h`.

- [ ] **Step 2: Run the checker**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: passes. If it flags a forbidden GPIO, the table has an assignment in the wrong column — the forbidden list must read as reasons, not assignments.

- [ ] **Step 3: Verify pin uniqueness by hand**

```bash
grep -oE '^\| [A-Za-z0-9 `]+ \| [0-9]+ ' docs/wiring/pin-map.md | awk '{print $(NF)}' | sort -n | uniq -d
```
Expected: **no output**. Any duplicate means two functions share a pin.

- [ ] **Step 4: Commit**

```bash
git add docs/wiring/pin-map.md
git commit -m "Add GPIO pin map

Canonical assignment table for the Lolin S3 Mini, with defaults taken
from the Arduino variant's pins_arduino.h. Records the octal-PSRAM
caveat: GPIO35/36/37 are free here only because this board uses quad
PSRAM, so an 8MB-PSRAM board would force I2C elsewhere."
```

---

### Task 3: Power design

**Files:**
- Create: `docs/wiring/power.md`

**Interfaces:**
- Consumes: Task 1 checker.
- Produces: rail node names used by the netlist in Task 4 — `5V_RAIL`, `GND_STAR`, `3V3`. Task 4 must use these exact identifiers.

- [ ] **Step 1: Write `docs/wiring/power.md`**

Must contain:

1. **Topology diagram** (Mermaid) showing: battery → LM2596S → SPDT pole A; USB-C 5V → SPDT pole B; SPDT common → `5V_RAIL`; `5V_RAIL` branching separately to PCA9685 `V+` and ESP32 `5V`; all grounds to `GND_STAR`.
2. **The four rules**, each with its reason:
   - SPDT switch not diode-OR (no backfeed; avoids ~0.3V Schottky drop under sag)
   - Star topology (servo inrush cannot brown out the MCU)
   - 1000µF bulk at PCA9685 `V+` (absorbs 8-servo inrush)
   - LM2596S set to 5.2V **with no load** before connecting anything
3. **LM2596S adjustment procedure**, numbered, ending with a measured-voltage confirmation.
4. **Power budget:** 8× MG90 ≈ 2.5–3A peak; LM2596S ≈ 2A continuous (3A peak rating). State plainly that populating ch8 *and* UWB (~150mA peak TX) requires re-checking the budget.
5. **Safety block:** never solder with power connected; verify polarity before first power-on.

- [ ] **Step 2: Run the checker**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: passes.

- [ ] **Step 3: Verify the Mermaid diagram parses**

Open the file in Obsidian preview, or confirm the block is fenced as ```` ```mermaid ```` and every node id is referenced by at least one edge. A diagram that renders as an error block is worse than no diagram.

- [ ] **Step 4: Commit**

```bash
git add docs/wiring/power.md
git commit -m "Add power rail design

Dual-source 5V rail with physical SPDT selection and star-topology
branching, so servo inrush cannot drag the MCU rail into brownout.
Records the LM2596S no-load adjustment procedure - these modules ship
at arbitrary output voltages and will destroy an ESP32 otherwise - and
the power budget limit that constrains populating ch8 alongside UWB."
```

---

### Task 4: Netlist

**Files:**
- Create: `docs/wiring/netlist.md`

**Interfaces:**
- Consumes: `5V_RAIL`, `GND_STAR`, `3V3` from Task 3; GPIO numbers from Task 2.
- Produces: **the source of truth.** Tasks 5–6 must agree with it; where they disagree, they are wrong.

- [ ] **Step 1: Write `docs/wiring/netlist.md`**

Every connection, numbered, with gauge. Power section:

| # | From | To | Gauge | Notes |
|---|---|---|---|---|
| 1 | Battery + | LM2596S `IN+` | 22AWG red | Via XT30/JST connector, never soldered direct |
| 2 | Battery − | `GND_STAR` | 22AWG black | |
| 3 | LM2596S `OUT+` | SPDT pole A | 22AWG red | **Set 5.2V no-load first** |
| 4 | LM2596S `OUT−` | `GND_STAR` | 22AWG black | |
| 5 | USB-C 5V | SPDT pole B | 22AWG red | |
| 6 | USB-C GND | `GND_STAR` | 22AWG black | |
| 7 | SPDT common | `5V_RAIL` | 22AWG red | Rail node |
| 8 | `5V_RAIL` | PCA9685 `V+` | 22AWG red | Branch 1 |
| 9 | `5V_RAIL` | S3 Mini `5V` | 22AWG red | Branch 2 — **not** daisy-chained from 8 |
| 10 | 1000µF + | PCA9685 `V+` | — | Observe polarity |
| 11 | 1000µF − | `GND_STAR` | — | |

Logic section:

| # | From | To | Gauge | Notes |
|---|---|---|---|---|
| 12 | S3 `3V3` | PCA9685 `VCC` | 30AWG | **Logic only — not `V+`** |
| 13 | S3 `3V3` | OLED `VCC` | 30AWG | |
| 14 | S3 `3V3` | UWB header `3V3` | 30AWG | |
| 15 | S3 `GND` | `GND_STAR` | 22AWG black | |
| 16 | S3 `GPIO35` | PCA9685 `SDA` + OLED `SDA` | 30AWG | Shared bus |
| 17 | S3 `GPIO36` | PCA9685 `SCL` + OLED `SCL` | 30AWG | Shared bus |
| 18 | S3 `GPIO18` | PCA9685 `OE` | 30AWG | Active-low |

Servo section — one row per channel, ch0 through ch7, each `PCA9685 chN signal → Servo N+1 signal`, 30AWG, with a note that servo V+/GND come from the PCA9685's own 3-pin headers, **not** from separate runs.

UWB header section — rows 27–34 mapping GPIO 12/11/13/10/14/21/16/17 to `SCK`/`MOSI`/`MISO`/`CSn`/`IRQ`/`RSTn`/`WAKEUP`/`EXTON`, marked **unpopulated**, with the `RSTn` open-drain warning inline.

Close with a **connection count total** and a note that the netlist is the source of truth.

- [ ] **Step 2: Run the checker**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: passes, including the RSTn open-drain rule.

- [ ] **Step 3: Verify no duplicate row numbers and no orphan nets**

```bash
grep -oE '^\| [0-9]+ ' docs/wiring/netlist.md | tr -d '| ' | sort -n | uniq -d
```
Expected: **no output**.

```bash
grep -c '^| [0-9]' docs/wiring/netlist.md
```
Expected: matches the stated connection count total.

- [ ] **Step 4: Cross-check every GPIO against the pin map**

```bash
comm -23 \
  <(grep -oE 'GPIO ?[0-9]+' docs/wiring/netlist.md | tr -d ' ' | sort -u) \
  <(grep -oE 'GPIO ?[0-9]+' docs/wiring/pin-map.md | tr -d ' ' | sort -u)
```
Expected: **no output** — every GPIO in the netlist must appear in the pin map.

- [ ] **Step 5: Commit**

```bash
git add docs/wiring/netlist.md
git commit -m "Add netlist - the wiring source of truth

Every connection as from -> to with wire gauge, split into power,
logic, servo, and (unpopulated) UWB sections. Cross-checked so that
every GPIO referenced here appears in the pin map.

Encodes the two failure modes that destroy hardware: the ESP32 5V
branch is drawn from the rail node rather than chained off the
PCA9685 V+ terminal, and PCA9685 VCC is explicitly the 3.3V logic
net rather than V+."
```

---

### Task 5: Expansion

**Files:**
- Create: `docs/wiring/expansion.md`

**Interfaces:**
- Consumes: netlist UWB rows from Task 4; pin map from Task 2.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write `docs/wiring/expansion.md`**

Two sections.

**Reserved output:** PCA9685 ch8 designated; ch9–15 spare. Note 12-bit PWM suits LEDs/ESCs as well as servos. State the power-budget constraint from Task 3 rather than repeating the arithmetic.

**UWB header:** the 8-pin part-agnostic header. Include the DWM1000-vs-DWM3000 comparison table (extra control pins; ~20MHz vs ~36MHz SPI; different driver libraries; both 3.3V, both needing no level shifting). State plainly that the two extra pins exist so either part drops in without harness changes.

Include the **`RSTn` open-drain warning** — required by the checker and by physics.

**Wi-Fi positioning:** RSSI (any ESP32, ±3–5m, poor indoors due to multipath) vs 802.11 FTM (ESP32-S3, ~1–2m, needs FTM at both ends — satisfied because the swarm is all S3 Minis). Frame as tiers: FTM baseline at no BOM cost, UWB precision layer at ~10cm.

- [ ] **Step 2: Run the checker**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: passes.

- [ ] **Step 3: Commit**

```bash
git add docs/wiring/expansion.md
git commit -m "Add expansion documentation

Covers the reserved PCA9685 output (ch8, with seven more spare) and
the part-agnostic 8-pin UWB header. The two extra pins are what let
DWM1000 and DWM3000 swap without touching the harness, since both are
3.3V SPI parts differing only in optional control lines and driver.

Tiers the positioning roadmap: Wi-Fi FTM as the zero-BOM baseline,
UWB as the precision layer."
```

---

### Task 6: Assembly guide

**Files:**
- Create: `docs/wiring/README.md`

**Interfaces:**
- Consumes: all preceding wiring documents.
- Produces: the entry point for someone building the robot.

- [ ] **Step 1: Write `docs/wiring/README.md`**

Structure:

1. **Why PCA9685** — one short paragraph; upstream's three routes and why none fits.
2. **Block diagram** (Mermaid) — MCU, I2C bus with two devices, PCA9685 fanning to 8 servos, power rail, UWB header shown dashed as unpopulated.
3. **Document index** — table linking `pin-map.md`, `power.md`, `netlist.md`, `expansion.md`, each with one line on when to read it.
4. **Assembly order**, numbered, each step naming the netlist rows it satisfies:
   1. Set LM2596S to 5.2V, no load (rows 3–4)
   2. Build the 5V rail and ground star (rows 1–11)
   3. Verify rail voltage before connecting any module
   4. Wire logic and I2C (rows 12–18)
   5. Confirm `0x3C` and `0x40` both enumerate before attaching servos
   6. Attach servos one channel at a time (servo rows)
   7. Leave the UWB header unpopulated
5. **Pre-power checklist** — the five verification items from the spec, as checkboxes.
6. **Safety** — the three hardware-destroying mistakes, stated once, prominently.

- [ ] **Step 2: Run the checker**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: passes, including link resolution to the four sibling documents.

- [ ] **Step 3: Verify every sibling document is linked**

```bash
for f in pin-map power netlist expansion; do
  grep -q "$f.md" docs/wiring/README.md && echo "ok: $f" || echo "MISSING: $f"
done
```
Expected: four `ok:` lines.

- [ ] **Step 4: Commit**

```bash
git add docs/wiring/README.md
git commit -m "Add wiring assembly guide

Entry point tying the wiring documents together: block diagram,
document index, and an assembly order where each step names the
netlist rows it satisfies, so progress is checkable against the
source of truth rather than by eye.

Front-loads the two checks that catch mistakes while they are still
cheap: measure the rail before attaching modules, and confirm both
I2C addresses enumerate before attaching servos."
```

---

### Task 7: Upstream divergence and BOM

**Files:**
- Create: `docs/upstream/divergence.md`
- Create: `hardware/bom.md`

**Interfaces:**
- Consumes: pin map and netlist.
- Produces: the record a future firmware task reads before touching `setServoAngle()`.

- [ ] **Step 1: Write `docs/upstream/divergence.md`**

Record: branch point `86d2bf8` on `main`; that we do not merge from upstream and why (servo control diverges structurally).

Firmware changes required, each naming the upstream symbol:
- `setServoAngle()` — rewritten to drive PCA9685 channels over I2C instead of `ESP32Servo`
- the eight `servos[i].attach(servoPins[i], 732, 2929)` calls — removed, replaced by one PCA9685 init
- `I2C_SDA`/`I2C_SCL` — repointed to GPIO35/36
- `ESP32PWM::allocateTimer()` × 4 — removed; PWM generation leaves the MCU

Explicitly portable and unchanged: `face-bitmaps.h`, `movement-sequences.h`, the face/animation engine, the JSON API, Sesame Studio compatibility — **because channel ordering is preserved**.

- [ ] **Step 2: Write `hardware/bom.md`**

Delta only, not a full BOM. Added: PCA9685 breakout, LM2596S, SPDT switch, 1000µF electrolytic, 8-pin header, Lolin S3 Mini (replacing S2 Mini/DevKitC). Removed: Sesame Distro Board V1/V3. Unchanged: 8× MG90, SSD1306 OLED, frame hardware. Note UWB module is deliberately **not** yet purchased, and link upstream's BOM rather than duplicating it.

- [ ] **Step 3: Run the checker**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: passes.

- [ ] **Step 4: Commit**

```bash
git add docs/upstream/divergence.md hardware/bom.md
git commit -m "Record upstream divergence and BOM delta

Names the exact upstream symbols that change - setServoAngle(), the
eight servo attach() calls, the I2C pin defines, and the four
ESP32PWM timer allocations - so a future firmware task knows its
blast radius without rediscovering it.

Records what stays portable and why: animations and Sesame Studio
work untouched because PCA9685 channel ordering preserves upstream's
servoPins[8] indexing."
```

---

### Task 8: Final review and push

**Files:**
- Modify: `ARCHITECTURE.md` (status line only)

**Interfaces:**
- Consumes: everything.
- Produces: a pushed, complete wiring specification.

- [ ] **Step 1: Run the full checker one final time**

```bash
bash scripts/check-wiring-docs.sh
```
Expected: `all consistency checks passed`.

- [ ] **Step 2: Verify every spec deliverable exists**

```bash
for f in docs/wiring/README.md docs/wiring/netlist.md docs/wiring/pin-map.md \
         docs/wiring/power.md docs/wiring/expansion.md \
         docs/upstream/divergence.md hardware/bom.md; do
  [ -f "$f" ] && echo "ok: $f" || echo "MISSING: $f"
done
```
Expected: seven `ok:` lines.

- [ ] **Step 3: Update the roadmap status in `ARCHITECTURE.md`**

Change the "Now — wiring" roadmap entry to record that the wiring specification is complete, and that the next phase is firmware adaptation. Do not restate the wiring detail; link to `docs/wiring/README.md`.

- [ ] **Step 4: Commit and push**

```bash
git add ARCHITECTURE.md
git commit -m "Mark wiring specification complete

All seven wiring documents exist and pass the consistency checker.
Next phase is firmware adaptation - replacing direct GPIO servo
control with PCA9685 driving."
git push origin main
```

- [ ] **Step 5: Confirm the push landed**

```bash
git fetch -q origin && git status -sb | head -1
```
Expected: `## main...origin/main` with no ahead/behind marker.

---

## Self-Review

**Spec coverage:** every deliverable in the spec's Deliverables table maps to a task — `wiring/README.md` (T6), `netlist.md` (T4), `pin-map.md` (T2), `power.md` (T3), `expansion.md` (T5), `upstream/divergence.md` (T7), `hardware/bom.md` (T7). The spec's Verification section maps to T6 Step 1's pre-power checklist. Goals #2 and #3 (reserved output, reserved sensor input) map to T5.

**Placeholder scan:** no TBD/TODO markers; every step names its file, its command, and its expected output.

**Type consistency:** net names `5V_RAIL`, `GND_STAR`, `3V3` are introduced in T3 and used unchanged in T4. GPIO numbers appear once canonically in T2 and are cross-checked mechanically in T4 Step 4. `check-wiring-docs.sh` keeps the same path and invocation throughout.

**Known gap, accepted:** the checker validates structure, not electrical correctness. A netlist can be internally consistent and still wrong. T6's pre-power checklist and the physical measurement steps are what catch that, and no amount of scripting substitutes for measuring the rail before connecting a module.
