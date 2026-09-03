# Robotics-wiring Assimilation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve only validated, current-compatible knowledge from the stray
`robotics-wiring` snapshot in the canonical `robotics` repository, then
recoverably remove the stray folder.

**Architecture:** The canonical netlist and ESP32-S3 Super Mini pin map remain
authoritative. A new glossary is rewritten from those current documents rather
than copied from the stale snapshot. Candidate improvements are admitted only
when an existing authoritative project document, pinned upstream source, or
primary datasheet supports them; a dated manifest records every decision before
the source folder is moved to Trash.

**Tech Stack:** Markdown, Bash, Git, Python standard library XML parser,
Mermaid CLI (`mmdc`), macOS Finder Trash.

**Spec:** `docs/superpowers/specs/2026-09-03-robotics-wiring-assimilation-design.md`

## Global Constraints

- `docs/wiring/netlist.md` is the source of truth.
- Board target is ESP32-S3 Super Mini; I2C is GPIO2 SDA / GPIO3 SCL.
- Do not introduce Lolin S3 Mini, GPIO35/GPIO36 I2C, a free-pin count, a
  10-contact UWB claim, or a USB power-path claim without a primary source or
  bench result.
- Preserve all existing uncommitted changes under `docs/wiring/diagrams/`.
- Do not copy duplicate documents or `.superpowers/sdd/` process residue.
- Commit only files created or changed by this plan; do not stage diagram work.
- Move the stray directory to Trash only after the documentation commit and all
  verification steps succeed.

---

## File structure

| Path | Responsibility |
|---|---|
| `docs/wiring/glossary.md` | Plain-language definitions grounded in the current wiring design. |
| `docs/wiring/README.md` | Adds a link to the glossary. |
| `docs/wiring/netlist.md` | May gain upstream-validated servo physical identities only if verified. |
| `hardware/bom.md` | May gain source-backed component ratings only if verified. |
| `docs/superpowers/specs/2026-09-03-robotics-wiring-assimilation-report.md` | Durable manifest of retained, rejected and unverified snapshot material. |

### Task 1: Baseline and glossary

**Files:**
- Create: `docs/wiring/glossary.md`
- Modify: `docs/wiring/README.md`
- Test: `scripts/check-wiring-docs.sh`

**Consumes:** Current `netlist.md`, `pin-map.md`, `power.md` and `expansion.md`.

**Produces:** A current-design glossary linked from the wiring guide.

- [ ] **Step 1: Record the safety baseline before writing**

  Run:

  ```bash
  cd /Users/tw/Documents/Obsidian_note/Projects/robotics
  bash scripts/check-wiring-docs.sh
  git status --short
  ```

  Expected: checker exits 0; the status output contains only the pre-existing
  diagram changes and no staged files.

- [ ] **Step 2: Write the glossary from current sources, not the snapshot**

  Create `docs/wiring/glossary.md` with concise sections for:

  - GPIO, I2C, SPI, PWM, active-low, pull-up/pull-down, high-Z and open-drain;
  - `VCC` versus `V+`, `5V_RAIL`, `3V3`, `GND_STAR`, buck converter, inrush,
    brownout, star topology and backfeed;
  - net/netlist, AWG, UWB, RSSI and Wi-Fi FTM.

  State the current Super Mini GPIO2/GPIO3 I2C assignment where I2C is
  defined. State the three safety invariants verbatim in substance: PCA9685
  `VCC` is 3V3 and not `V+`; servo current does not traverse the ESP32; `RSTn`
  is open-drain and never driven high. Link relevant terms to the current
  netlist, pin map, power and expansion documents.

- [ ] **Step 3: Link the glossary from the wiring guide**

  Add this row to the document table in `docs/wiring/README.md`:

  ```markdown
  | [glossary.md](glossary.md) | A plain-language explanation of the wiring terms |
  ```

- [ ] **Step 4: Run negative-content and link checks**

  Run:

  ```bash
  grep -niE 'Lolin|GPIO ?3[56]|10-contact|14 free GPIO' docs/wiring/glossary.md && exit 1 || true
  bash scripts/check-wiring-docs.sh
  ```

  Expected: the first command produces no matches; checker exits 0.

- [ ] **Step 5: Commit only the glossary and wiring-guide link**

  ```bash
  git add docs/wiring/glossary.md docs/wiring/README.md
  git diff --cached --check
  git diff --cached --name-only
  git commit -m "Add current wiring glossary"
  ```

  Expected staged paths are exactly the two paths above.

### Task 2: Validate and selectively retain candidate improvements

**Files:**
- Modify: `docs/wiring/netlist.md` only if upstream validates physical servo
  identity details
- Modify: `hardware/bom.md` only if a primary specification validates electrical
  ratings
- Modify: `docs/wiring/README.md` only if a staged-power instruction follows
  from the current netlist without an unsourced USB-path claim
- Test: `scripts/check-wiring-docs.sh`, `mmdc` if Mermaid changes

**Consumes:** The snapshot’s candidate ideas, the current netlist, current power
document and upstream Sesame commit `86d2bf8`.

**Produces:** Only verified safety/assembly improvements; rejected candidates
are recorded in Task 3.

- [ ] **Step 1: Verify servo identity candidates against pinned upstream**

  Fetch the upstream source without modifying the canonical repository:

  ```bash
  rm -rf /tmp/sesame-robot-upstream
  git clone -q https://github.com/dorianborian/sesame-robot.git /tmp/sesame-robot-upstream
  git -C /tmp/sesame-robot-upstream checkout -q 86d2bf8
  rg -n 'servoPins|ServoName|R1|R2|R3|R4|L1|L2|L3|L4' /tmp/sesame-robot-upstream
  ```

  Expected: a source location that directly proves each mapping before it is
  added to the netlist. If no single source proves a mapping, do not add any
  physical-name detail.

- [ ] **Step 2: Apply only upstream-proven servo detail**

  If Step 1 proves the complete index-to-physical-servo mapping, add it to the
  existing servo rows in `docs/wiring/netlist.md` without changing channel
  order, GPIOs, row count, or the existing `servoPins[8]` indices. Otherwise
  leave the netlist unchanged and record the candidate as rejected in Task 3.

- [ ] **Step 3: Evaluate electrical-rating and USB-path candidates**

  Do not add `>=5A DC` for the switch, `>=16V` for the capacitor, or a USB-C
  flashing/source-selection rule unless a primary specification or an existing
  bench record supports the claim. The old snapshot's own text admits the Super
  Mini USB power topology was unverified; that is insufficient evidence.

  If a rating is added, state its source in the same document. If no source is
  available, make no change and list the candidate as unverified in Task 3.

- [ ] **Step 4: Verify any changes**

  Run:

  ```bash
  bash scripts/check-wiring-docs.sh
  git diff -- docs/wiring/netlist.md hardware/bom.md docs/wiring/README.md
  ```

  If a Mermaid block changed, render it:

  ```bash
  mmdc -i /tmp/changed-diagram.mmd -o /tmp/changed-diagram.svg
  ```

  Expected: checker exits 0; no diagram file under `docs/wiring/diagrams/` is
  changed or staged by this task.

- [ ] **Step 5: Commit only validated changes, when present**

  ```bash
  git add docs/wiring/netlist.md hardware/bom.md docs/wiring/README.md
  git diff --cached --check
  git diff --cached --name-only
  git commit -m "Clarify validated wiring assembly details"
  ```

  If no candidate validated, do not create an empty commit.

### Task 3: Record provenance and verify the final canonical documentation

**Files:**
- Create: `docs/superpowers/specs/2026-09-03-robotics-wiring-assimilation-report.md`
- Test: `scripts/check-wiring-docs.sh`, Python XML parser, Git staged-diff audit

**Consumes:** Tasks 1–2 and the complete snapshot manifest.

**Produces:** A durable explanation of what was retained or rejected, including
why the raw snapshot was not imported.

- [ ] **Step 1: Write the assimilation report**

  Create the report with these exact sections:

  ```markdown
  # Robotics-wiring assimilation report

  ## Retained
  ## Rejected as stale
  ## Rejected as unverified
  ## Cleanup manifest
  ```

  `Retained` names the rewritten glossary and each Task 2 change that actually
  validated. `Rejected as stale` names the duplicate documents, the Lolin/GPIO35
  /GPIO36 pin map, 37-row netlist, free-pin count, 10-contact header claim, and
  `.superpowers/sdd/`. `Rejected as unverified` names every candidate that Task
  2 could not support. `Cleanup manifest` lists the source directory and states
  it will be moved to Trash only after this report and the verifier pass.

- [ ] **Step 2: Verify all current documentation**

  Run:

  ```bash
  bash scripts/check-wiring-docs.sh
  python3 - <<'PY'
  from pathlib import Path
  from xml.dom.minidom import parse
  for path in Path('docs/wiring/diagrams').glob('*.svg'):
      parse(str(path))
      print(f'ok: {path}')
  PY
  git status --short
  ```

  Expected: checker exits 0; every present SVG parses; status may show the
  pre-existing diagram changes but must show no unexpected docs outside this
  plan.

- [ ] **Step 3: Commit the report only**

  ```bash
  git add docs/superpowers/specs/2026-09-03-robotics-wiring-assimilation-report.md
  git diff --cached --check
  git diff --cached --name-only
  git commit -m "Record robotics-wiring assimilation"
  ```

  Expected staged path is exactly the report.

### Task 4: Recoverably remove the redundant snapshot

**Files:**
- Delete externally: `/Users/tw/Documents/Obsidian_note/Projects/robotics-wiring`
- Verify: `/Users/tw/.Trash/robotics-wiring`

**Consumes:** The committed report and passing verification from Task 3.

**Produces:** One canonical robotics location; the snapshot remains recoverable
in macOS Trash.

- [ ] **Step 1: Confirm snapshot manifest before removal**

  ```bash
  find /Users/tw/Documents/Obsidian_note/Projects/robotics-wiring \
    -path '*/.git' -prune -o -type f -print | sort
  git -C /Users/tw/Documents/Obsidian_note/Projects/robotics log --oneline -3
  ```

  Expected: files match the report's rejected/retained manifest and the report
  commit is present.

- [ ] **Step 2: Move the snapshot to Trash**

  ```bash
  osascript -e 'tell application "Finder" to delete POSIX file "/Users/tw/Documents/Obsidian_note/Projects/robotics-wiring"'
  ```

- [ ] **Step 3: Verify cleanup and canonical repository state**

  ```bash
  test ! -e /Users/tw/Documents/Obsidian_note/Projects/robotics-wiring
  test -d /Users/tw/.Trash/robotics-wiring
  git -C /Users/tw/Documents/Obsidian_note/Projects/robotics status --short
  ```

  Expected: source is absent from `Projects/`; recoverable Trash directory is
  present; only the pre-existing diagram work remains uncommitted.
