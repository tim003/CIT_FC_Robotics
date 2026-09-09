# Photo-Based Stage 1 Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every generated wiring SVG with the two evidence-backed Stage 1 raster sources and make all active project documentation describe the tested build accurately.

**Architecture:** The verified wiring-table screenshot and perfboard layout image become the Stage 1 visual record, while the Markdown netlist remains the production construction authority. A repository check prevents the removed SVG generator, outputs, and links from returning.

**Tech Stack:** Markdown, Bash, PNG/JPEG evidence, existing wiring consistency checker.

**Spec:** [`docs/superpowers/specs/2026-09-09-stage1-as-built-makerfabs-design.md`](../specs/2026-09-09-stage1-as-built-makerfabs-design.md)

## Global Constraints

- `docs/wiring/netlist.md` remains the soldering source of truth.
- Stage 1 evidence proves power, GPIO2/GPIO3 I2C, and movement of three servos on PCA9685 channels 0–2 only.
- Do not claim all-eight-servo, complete-animation, Wi-Fi-in-assembly, or UWB verification.
- Copy `/Users/tw/Desktop/pi-inbox/Screenshot 2026-09-07 at 3.00.25 PM.png` into the repository as `hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png`.
- Retain `hardware/circuit layout/20260901_CircuitBoardDesign_002_Fixed.jpg` as the perfboard routing/layout reference.
- Delete every SVG, the generator, and the diagram index; do not replace them with another generated diagram.
- Keep the colleague-tested 5.0 V arrangement separate from the enhanced production target.
- Do not modify the authoritative GPIO assignments in `docs/wiring/netlist.md` or `docs/wiring/pin-map.md`.
- Do not stage `.DS_Store` or temporary image conversions.

---

### Task 1: Establish the raster evidence package and retire generated diagrams

**Files:**
- Create: `scripts/check-stage1-evidence.sh`
- Create: `hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png`
- Modify: `hardware/circuit layout/README.md`
- Modify: `docs/wiring/README.md`
- Delete: `docs/wiring/diagrams/`
- Delete if present: `tests/test_wiring_diagrams.py`

**Interfaces:**
- Consumes: the supplied desktop screenshot, existing perfboard JPEG, and Task 1 as-built README.
- Produces: a durable two-image Stage 1 evidence package and `scripts/check-stage1-evidence.sh` for later documentation tasks.

- [ ] **Step 1: Discard only the stopped SVG-redraw worker's uncommitted implementation**

The stopped worker reported uncommitted changes to `docs/wiring/diagrams/` and `tests/test_wiring_diagrams.py`. Do not reset any committed Task 1 work. Restore the tracked diagram directory to `HEAD` only so deletion begins from a known state, and remove only the abandoned untracked SVG test:

```bash
git restore --source=HEAD --staged --worktree docs/wiring/diagrams
rm -f tests/test_wiring_diagrams.py
git status --short --untracked-files=all
```

Expected: the committed Stage 1 README and photographs remain; only the earlier user-renamed SVG inputs may remain untracked before the directory is retired.

- [ ] **Step 2: Write the failing evidence check**

Create executable `scripts/check-stage1-evidence.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

fail=0
IMAGE='hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png'
README='hardware/circuit layout/README.md'

if [ ! -f "$IMAGE" ]; then
  echo "FAIL: missing verified wiring-table image: $IMAGE"
  fail=1
elif ! file "$IMAGE" | grep -q 'PNG image data'; then
  echo "FAIL: verified wiring-table file is not PNG image data"
  fail=1
fi

if [ -e docs/wiring/diagrams ]; then
  echo 'FAIL: retired docs/wiring/diagrams directory still exists'
  fail=1
fi

if [ -e tests/test_wiring_diagrams.py ]; then
  echo 'FAIL: retired SVG generator test still exists'
  fail=1
fi

if rg -q '^```mermaid' docs/wiring/README.md; then
  echo 'FAIL: unverified wiring Mermaid still exists'
  fail=1
fi

for text in \
  '2026-09-07-stage1-verified-wiring-table.png' \
  '20260901_CircuitBoardDesign_002_Fixed.jpg' \
  'power-up, I2C on GPIO2/GPIO3, and movement of three servos' \
  'does not verify all eight servos' \
  'Wi-Fi in the photographed stacked placement'; do
  if ! grep -Fq "$text" "$README"; then
    echo "FAIL: Stage 1 README missing: $text"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo 'Stage 1 evidence checks passed'
```

Run:

```bash
chmod +x scripts/check-stage1-evidence.sh
bash scripts/check-stage1-evidence.sh
```

Expected: FAIL because the repository image has not been copied and `docs/wiring/diagrams/` still exists.

- [ ] **Step 3: Copy the verified source image without transforming it**

```bash
cp '/Users/tw/Desktop/pi-inbox/Screenshot 2026-09-07 at 3.00.25 PM.png' \
  'hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png'
shasum '/Users/tw/Desktop/pi-inbox/Screenshot 2026-09-07 at 3.00.25 PM.png' \
  'hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png'
file 'hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png'
```

Expected: both SHA-1 values are identical and `file` reports PNG image data.

- [ ] **Step 4: Rewrite the Stage 1 evidence README**

Update `hardware/circuit layout/README.md` to:

- embed the wiring screenshot with `![Verified Stage 1 wiring table](2026-09-07-stage1-verified-wiring-table.png)`;
- embed the layout with `![Stage 1 perfboard routing layout](20260901_CircuitBoardDesign_002_Fixed.jpg)`;
- transcribe the exact wiring table from the design spec;
- state that the PNG wiring table specifies a 7.4 V battery input, while the 6.8 V captured-condition annotation appears only on `20260901_CircuitBoardDesign_002_Fixed.jpg`;
- state that the colleague-tested LM2596S output is 5.0 V;
- preserve the exact verified and unverified boundaries required by the check; and
- link production construction to `../../docs/wiring/netlist.md`, power safety to `../../docs/wiring/power.md`, and antenna placement to `../../docs/wiring/antenna.md`.

Do not describe the layout image as proof of hidden underside nets.

- [ ] **Step 5: Replace the active diagram link and delete the generated-diagram system**

In `docs/wiring/README.md`, delete the `## Block diagram` Mermaid section because it still depicts the obsolete bare-radio path. Replace the `diagrams/` document-map row with a row linking to the Stage 1 evidence record at `../../hardware/circuit%20layout/README.md`. Keep its existing tested-build versus production-target table unchanged until Task 2 expands project status.

Then remove the complete generated system:

```bash
rm -rf docs/wiring/diagrams
rm -f tests/test_wiring_diagrams.py
```

This removes all tracked and untracked SVG variants, `generate.py`, and the diagram index. It does not touch raster evidence.

- [ ] **Step 6: Run the focused check to GREEN**

```bash
bash scripts/check-stage1-evidence.sh
bash scripts/check-wiring-docs.sh
```

Expected: both pass with pristine output.

- [ ] **Step 7: Verify protected files and commit**

```bash
git diff --exit-code HEAD -- docs/wiring/netlist.md docs/wiring/pin-map.md
git diff --check
git status --short --untracked-files=all
git add scripts/check-stage1-evidence.sh docs/wiring/README.md \
  'hardware/circuit layout/README.md' \
  'hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png'
git add -u docs/wiring/diagrams
git diff --cached --check
git commit -m "Replace generated diagrams with Stage 1 evidence"
```

Expected: no `.DS_Store`, temporary preview, or authoritative netlist/pin-map change is committed.

### Task 2: Remove active diagram references and align project status

**Files:**
- Modify: `scripts/check-stage1-evidence.sh`
- Modify: `docs/wiring/README.md`
- Modify: `docs/wiring/expansion.md`
- Modify: `docs/upstream/divergence.md`
- Modify: `hardware/bom.md`
- Modify: `ARCHITECTURE.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Task 1's evidence paths and retired-diagram state.
- Produces: project-wide Stage 1 status and a link to the separate Makerfabs Stage 2 implementation plan.

- [ ] **Step 1: Extend the check with failing active-reference assertions**

Append to `scripts/check-stage1-evidence.sh` before its final success message:

```bash
ACTIVE_DOCS=(ARCHITECTURE.md AGENTS.md docs/wiring docs/upstream hardware)

if rg -n 'docs/wiring/diagrams|diagrams/README|[12][ab]-(no-uwb|uwb)-' \
  "${ACTIVE_DOCS[@]}" --glob '*.md'; then
  echo 'FAIL: active documentation still references retired wiring diagrams'
  fail=1
fi

for file in ARCHITECTURE.md AGENTS.md docs/wiring/expansion.md hardware/bom.md; do
  if ! grep -Fq 'Makerfabs ESP32 UWB DW3000 WROOM' "$file"; then
    echo "FAIL: $file does not name the selected Makerfabs WROOM board"
    fail=1
  fi
  if ! grep -Fq 'delivered-board verification' "$file"; then
    echo "FAIL: $file does not preserve the delivered-board verification gate"
    fail=1
  fi
done

if ! grep -Fq 'two evaluation boards' hardware/bom.md; then
  echo 'FAIL: BOM does not record the two evaluation boards'
  fail=1
fi

if ! grep -Fq 'exact UART GPIOs' docs/wiring/expansion.md; then
  echo 'FAIL: expansion guide does not gate exact UART GPIOs'
  fail=1
fi
```

Move the existing `if [ "$fail" -ne 0 ]` block below these assertions so every check runs before exit.

Run:

```bash
bash scripts/check-stage1-evidence.sh
```

Expected: FAIL and print the active files that still reference deleted diagrams or stale UWB status.

- [ ] **Step 2: Update the wiring entry point**

In `docs/wiring/README.md`:

- replace diagram links with the two-image evidence record at `../../hardware/circuit%20layout/README.md`;
- make “tested Stage 1” and “production target” separate rows;
- retain the exact three-servo verification boundary; and
- link the Stage 2 roadmap to `../superpowers/plans/2026-09-09-makerfabs-stage2-integration.md`.

- [ ] **Step 3: Update UWB expansion and BOM status**

In `docs/wiring/expansion.md` and `hardware/bom.md` state:

- exact product: Makerfabs ESP32 UWB DW3000 WROOM;
- purchased quantity: two evaluation boards on 2026-09-09;
- intended quantity after acceptance: one per robot;
- selected architecture: Makerfabs onboard ESP32 as UWB coprocessor over UART;
- exact UART GPIOs, connector pins, and power feed require delivered-board verification;
- initial integration uses separate USB power plus common ground; and
- sharing the servo rail requires measured-current and regulator-headroom approval.

Keep the existing bare-radio SPI header documented as an unpopulated alternative; it is not the selected Stage 2 route.

- [ ] **Step 4: Align architecture, upstream divergence, and agent context**

Update `ARCHITECTURE.md`, `docs/upstream/divergence.md`, and `AGENTS.md` so all three state:

- Stage 1 power, GPIO2/GPIO3 I2C, and three-servo motion are verified;
- all-eight-servo operation, complete animation, and Wi-Fi in the stacked assembly remain unverified;
- generated diagrams were retired because they were not confirmed build evidence;
- the two purchased Makerfabs WROOM boards define the Stage 2 route;
- exact UART GPIOs and power wiring are not authoritative before arrival audit; and
- the raw-radio header and its open-drain `RSTn` protection remain an optional unpopulated interface.

Link the Stage 1 evidence README and the Makerfabs Stage 2 implementation plan where each document's relative path permits.

- [ ] **Step 5: Run checks to GREEN**

```bash
bash scripts/check-stage1-evidence.sh
bash scripts/check-wiring-docs.sh
git diff --exit-code HEAD -- docs/wiring/netlist.md docs/wiring/pin-map.md
```

Expected: both checkers pass; protected files have no diff.

- [ ] **Step 6: Audit and commit**

```bash
rg -n 'three servos|all eight|Makerfabs|exact UART GPIOs|delivered-board' \
  ARCHITECTURE.md AGENTS.md docs/wiring/README.md docs/wiring/expansion.md \
  docs/upstream/divergence.md hardware/bom.md
git diff --check
git add scripts/check-stage1-evidence.sh docs/wiring/README.md \
  docs/wiring/expansion.md docs/upstream/divergence.md hardware/bom.md \
  ARCHITECTURE.md AGENTS.md
git diff --cached --check
git commit -m "Align project status with photo-based Stage 1"
```

### Task 3: Final repository verification

**Files:**
- Verify only: outputs from Tasks 1–2

**Interfaces:**
- Consumes: completed photo-based documentation.
- Produces: evidence that the obsolete diagram system is gone and active documentation is internally consistent.

- [ ] **Step 1: Run all documentation checks**

```bash
bash scripts/check-stage1-evidence.sh
bash scripts/check-wiring-docs.sh
git diff --check
```

Expected: all commands pass with no warnings.

- [ ] **Step 2: Confirm retired assets cannot be found**

```bash
test ! -e docs/wiring/diagrams
test ! -e tests/test_wiring_diagrams.py
find docs hardware -type f -name '*.svg' -print
```

Expected: `find` prints no SVG files.

- [ ] **Step 3: Inspect the two Stage 1 raster sources**

Open:

- `hardware/circuit layout/2026-09-07-stage1-verified-wiring-table.png`
- `hardware/circuit layout/20260901_CircuitBoardDesign_002_Fixed.jpg`

Confirm the first remains byte-identical to the supplied screenshot and the second remains unchanged from its committed evidence copy.

- [ ] **Step 4: Verify final scope**

```bash
git status --short --untracked-files=all
git log --oneline -6
```

Expected: no temporary files or unstaged implementation changes remain. Do not push unless the user requests it.

## Self-review

- Task 1 implements the complete SVG retirement and Stage 1 evidence package.
- Task 2 removes active references and aligns the project-wide stage/UWB status.
- Task 3 proves no generated diagram survives and the two evidence images are usable.
- The plan never assigns provisional Stage 2 GPIO or power pins.
- The separate Stage 2 plan owns firmware, hardware audit, and acceptance work.
