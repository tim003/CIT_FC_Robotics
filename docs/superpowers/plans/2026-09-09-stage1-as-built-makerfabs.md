# Stage 1 As-Built Record and Makerfabs Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record the partially verified Stage 1 perfboard accurately and replace the obsolete bare-DWM3000 Stage 2 diagrams with a provisional Makerfabs UART architecture.

**Architecture:** The production netlist remains the source of truth while a separate as-built record preserves the colleague's tested physical assembly and its limited verification boundary. Four generated SVGs cover production Stage 1, as-built Stage 1, one-robot provisional Makerfabs integration, and the two-robot acceptance test; exact Stage 2 pins remain unassigned until delivered hardware is inspected.

**Tech Stack:** Markdown, Python 3 standard library, `unittest`, generated SVG/XML, Bash verification scripts.

**Spec:** [`docs/superpowers/specs/2026-09-09-stage1-as-built-makerfabs-design.md`](../specs/2026-09-09-stage1-as-built-makerfabs-design.md)

## Global Constraints

- `docs/wiring/netlist.md` remains the soldering source of truth.
- Do not change `docs/wiring/netlist.md` or `docs/wiring/pin-map.md` in this pass.
- Stage 1 as-built evidence proves power, GPIO2/GPIO3 I2C, and three-servo movement only.
- Do not claim eight-servo, Wi-Fi-in-assembly, or UWB verification.
- Stage 2 uses a complete Makerfabs ESP32 UWB DW3000 WROOM board as a coprocessor, not a bare DWM3000 direct-SPI module.
- Stage 2 UART GPIOs, connector pins, and power feed remain pending delivered-board verification.
- Preserve the user's current diagram filenames: `1a-no-uwb-Paul.svg`, `1b-no-uwb-Claude.svg`, `2a-uwb-based-on-1a.svg`, and `2b-uwb-based-on-1b.svg`.
- Edit `docs/wiring/diagrams/generate.py`, never generated SVGs by hand.
- The ESP32 antenna end must overhang the carrier in the production target; the as-built stacked placement is radio-unverified.
- Do not stage `hardware/circuit layout/.DS_Store` or temporary render output.

---

## File structure

| Path | Responsibility |
|---|---|
| `hardware/circuit layout/README.md` | Provenance, photographed placement, and exact Stage 1 verification boundary |
| `tests/test_wiring_diagrams.py` | Generator filename, role, obsolete-content, and XML validity tests |
| `docs/wiring/diagrams/generate.py` | Single source for all four pictorial diagrams |
| `docs/wiring/diagrams/*.svg` | Generated outputs using the existing user filenames |
| `docs/wiring/diagrams/README.md` | Diagram index and interpretation guide |
| `docs/wiring/README.md` | Stage status and links from the main assembly entry point |
| `docs/wiring/expansion.md` | Selected Makerfabs route and arrival-gated integration sequence |
| `hardware/bom.md` | Two purchased evaluation boards and per-robot future quantity |
| `ARCHITECTURE.md` | Superseded UWB architecture decision and roadmap status |
| `AGENTS.md` | Current phase summary for future agents |

### Task 1: Record Stage 1 as-built provenance

**Files:**
- Create: `hardware/circuit layout/README.md`
- Modify: `docs/wiring/README.md`
- Test: `scripts/check-wiring-docs.sh`

**Interfaces:**
- Consumes: the six image files in `hardware/circuit layout/`, `docs/wiring/netlist.md`, and `docs/wiring/antenna.md`.
- Produces: a durable distinction between as-built bench evidence and the production target.

- [ ] **Step 1: Record the working-tree baseline**

Run:

```bash
git status --short --untracked-files=all
bash scripts/check-wiring-docs.sh
```

Expected: the checker passes; status includes the user's diagram renames and the untracked `hardware/circuit layout/` files. Save the status output for comparison before staging.

- [ ] **Step 2: Write the as-built README**

Create `hardware/circuit layout/README.md` with these sections and facts:

```markdown
# Stage 1 as-built perfboard

## Status

This is the colleague-built Stage 1 bench assembly, without UWB. It verified
power-up, I2C on GPIO2/GPIO3, and movement of three servos.

It does not verify all eight servos, simultaneous servo load, Wi-Fi in the
photographed stacked placement, UWB, or complete agreement of hidden underside
connections with the production netlist.

## Files

- `20260901_CircuitBoardDesign_002_Fixed.jpg` — as-built placement/wire reference.
- `photos/` — top, oblique, underside, and module-placement photographs.

## Visible placement

The ESP32-S3 Super Mini is at the lower-left, the LM2596S is rotated at the
right, and the PCA9685 is stacked across the upper part of the carrier.

## Antenna warning

The photographed ESP32 antenna end does not overhang the carrier and sits near
the stacked PCA9685. This placement is radio-unverified and does not satisfy
the production keep-out in `../../docs/wiring/antenna.md`.

## Authority

These images are bench evidence, not a soldering netlist. New construction uses
`../../docs/wiring/netlist.md`; where a photo or pictorial guide disagrees with
the netlist, the netlist wins.
```

Use Markdown links for the two referenced documents so the repository checker validates them.

- [ ] **Step 3: Add a stage-status section to the wiring guide**

In `docs/wiring/README.md`, add a short section before the block diagram with a two-row table:

| Record | Status |
|---|---|
| Stage 1 as-built perfboard | Power, GPIO2/GPIO3 I2C, and three servos verified; Wi-Fi placement and eight-servo load not verified |
| Production target | Netlist complete; full harness and eight-servo acceptance still pending |

Link “as-built perfboard” to `../../hardware/circuit layout/README.md` and link “Production target” to `netlist.md`.

- [ ] **Step 4: Verify wording and links**

Run:

```bash
rg -n "three servos|Wi-Fi|netlist" 'hardware/circuit layout/README.md' docs/wiring/README.md
bash scripts/check-wiring-docs.sh
```

Expected: both files state the limited verification boundary and the checker passes.

- [ ] **Step 5: Commit the provenance record**

```bash
git add 'hardware/circuit layout/README.md' \
  'hardware/circuit layout/20260901_CircuitBoardDesign_002_Fixed.jpg' \
  'hardware/circuit layout/photos/' \
  docs/wiring/README.md
git restore --staged 'hardware/circuit layout/.DS_Store' 2>/dev/null || true
git diff --cached --check
git commit -m "Document Stage 1 as-built perfboard"
```

Expected: the commit contains the README and image evidence, never `.DS_Store`.

### Task 2: Test-drive and regenerate the four diagram roles

**Files:**
- Create: `tests/test_wiring_diagrams.py`
- Modify: `docs/wiring/diagrams/generate.py`
- Modify/generated: `docs/wiring/diagrams/1a-no-uwb-Paul.svg`
- Modify/generated: `docs/wiring/diagrams/1b-no-uwb-Claude.svg`
- Modify/generated: `docs/wiring/diagrams/2a-uwb-based-on-1a.svg`
- Modify/generated: `docs/wiring/diagrams/2b-uwb-based-on-1b.svg`
- Modify: `docs/wiring/diagrams/README.md`

**Interfaces:**
- Consumes: the approved four diagram roles and the Stage 1 photo provenance from Task 1.
- Produces: `generate.build(variant) -> str`, `generate.NAMES: dict[str, str]`, and four valid generated SVGs.

- [ ] **Step 1: Write the failing generator tests**

Create `tests/test_wiring_diagrams.py`:

```python
import importlib.util
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEN_PATH = ROOT / "docs/wiring/diagrams/generate.py"
SPEC = importlib.util.spec_from_file_location("wiring_diagrams", GEN_PATH)
generate = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(generate)

EXPECTED_NAMES = {
    "1a": "1a-no-uwb-Paul.svg",
    "1b": "1b-no-uwb-Claude.svg",
    "2a": "2a-uwb-based-on-1a.svg",
    "2b": "2b-uwb-based-on-1b.svg",
}


class WiringDiagramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rendered = {v.vid: generate.build(v) for v in generate.VARIANTS}

    def test_preserves_current_output_names(self):
        self.assertEqual(generate.NAMES, EXPECTED_NAMES)

    def test_all_outputs_are_valid_svg_xml(self):
        for vid, svg in self.rendered.items():
            with self.subTest(variant=vid):
                root = ET.fromstring(svg)
                self.assertTrue(root.tag.endswith("svg"))

    def test_stage1_production_shows_antenna_keepout(self):
        svg = self.rendered["1a"]
        self.assertIn("STAGE 1 PRODUCTION TARGET", svg)
        self.assertIn("ANTENNA KEEP-OUT", svg)
        self.assertIn("overhang", svg.lower())

    def test_stage1_as_built_states_verification_boundary(self):
        svg = self.rendered["1b"]
        self.assertIn("STAGE 1 AS-BUILT", svg)
        self.assertIn("POWER + I2C + 3 SERVOS VERIFIED", svg)
        self.assertIn("WI-FI NOT VERIFIED IN THIS PLACEMENT", svg)
        self.assertNotIn("WITH UWB", svg)

    def test_stage2_is_makerfabs_uart_not_bare_radio_spi(self):
        svg = self.rendered["2a"]
        self.assertIn("PROVISIONAL STAGE 2", svg)
        self.assertIn("Makerfabs ESP32 UWB DW3000", svg)
        self.assertIn("UART", svg)
        self.assertIn("exact pins pending board verification", svg.lower())
        self.assertNotIn("UWB 8-pin SPI header &#8212; POPULATED", svg)

    def test_stage2_two_board_acceptance_topology(self):
        svg = self.rendered["2b"]
        self.assertIn("TWO-ROBOT ACCEPTANCE TEST", svg)
        self.assertEqual(svg.count("Makerfabs ESP32 UWB DW3000"), 2)
        self.assertIn("RANGE LINK", svg)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests and confirm the old generator fails**

Run:

```bash
python3 -m unittest tests/test_wiring_diagrams.py -v
```

Expected: failures for old output names/roles and missing Makerfabs UART content. XML validity may already pass.

- [ ] **Step 3: Refactor the generator around four explicit roles**

Keep the public objects used by the tests:

```python
VARIANTS = [
    Variant("1a", "stage1-production"),
    Variant("1b", "stage1-as-built"),
    Variant("2a", "stage2-one-robot"),
    Variant("2b", "stage2-two-robot-test"),
]

NAMES = {
    "1a": "1a-no-uwb-Paul.svg",
    "1b": "1b-no-uwb-Claude.svg",
    "2a": "2a-uwb-based-on-1a.svg",
    "2b": "2b-uwb-based-on-1b.svg",
}
```

Implement one renderer per role and dispatch from `build(v)`:

- `build_stage1_production()` retains the production electrical topology and safety warnings, adds a visible ESP32 antenna zone extending beyond the carrier outline, and labels it `ANTENNA KEEP-OUT`.
- `build_stage1_as_built()` draws the perfboard with PCA9685 across the upper area, ESP32-S3 at lower-left, LM2596S rotated at right, and a note linking the visual arrangement to `hardware/circuit layout/`. Include the exact verified/unverified text from the tests. Do not imply that the photographs prove the production netlist.
- `build_stage2_one_robot()` draws the production robot-controller block, a bidirectional provisional UART connection, and one Makerfabs ESP32 UWB DW3000 block. Mark exact pins and power pending delivered-board verification; show independent antenna keep-outs for both radios.
- `build_stage2_two_robot_test()` draws two copies of the robot-controller + Makerfabs pairing, a UWB `RANGE LINK` between Makerfabs boards, and acceptance gates: supplied examples first, current measurement, UART message proof, then GPIO/netlist selection.

Retain the common SVG style/header helpers and keep all text as SVG text elements. Do not embed raster photos or base64 content.

- [ ] **Step 4: Run tests until all semantic checks pass**

Run:

```bash
python3 -m unittest tests/test_wiring_diagrams.py -v
```

Expected: 6 tests pass.

- [ ] **Step 5: Regenerate the SVG files**

Run:

```bash
python3 docs/wiring/diagrams/generate.py
```

Expected: exactly the four filenames in `EXPECTED_NAMES` are written. The generator must not recreate the removed `*-citfc.svg` or `*-loftwork.svg` names.

- [ ] **Step 6: Rewrite the diagram index**

Update `docs/wiring/diagrams/README.md` so its table gives the four roles from the spec. Replace the old claim that both schemes were fully bench-verified with the exact Stage 1 boundary. Replace the direct-SPI Stage 2 pin section with a Makerfabs section that states:

- two WROOM boards are purchased;
- one complete Makerfabs board is intended per robot;
- UART is architectural, while exact pins/power are pending delivered-board verification;
- the production netlist's raw-radio SPI header remains unpopulated and is not what variants 2A/2B depict; and
- both the ESP32-S3 Wi-Fi antenna and Makerfabs UWB antenna require clear placement.

Keep the generator rationale and photo-free/diffable SVG rationale.

- [ ] **Step 7: Verify tests and documentation**

```bash
python3 -m unittest tests/test_wiring_diagrams.py -v
bash scripts/check-wiring-docs.sh
```

Expected: both commands pass.

- [ ] **Step 8: Commit generator, tests, index, and generated outputs**

```bash
git add tests/test_wiring_diagrams.py docs/wiring/diagrams/generate.py \
  docs/wiring/diagrams/README.md \
  docs/wiring/diagrams/1a-no-uwb-Paul.svg \
  docs/wiring/diagrams/1b-no-uwb-Claude.svg \
  docs/wiring/diagrams/2a-uwb-based-on-1a.svg \
  docs/wiring/diagrams/2b-uwb-based-on-1b.svg
git add -u docs/wiring/diagrams
git diff --cached --check
git commit -m "Align wiring diagrams with tested build and Makerfabs path"
```

Expected: old generated filenames are removed, current filenames are tracked, and all four outputs are reproducible from `generate.py`.

### Task 3: Update architecture, expansion, BOM, and phase status

**Files:**
- Modify: `docs/wiring/expansion.md`
- Modify: `hardware/bom.md`
- Modify: `ARCHITECTURE.md`
- Modify: `AGENTS.md`
- Test: `scripts/check-wiring-docs.sh`

**Interfaces:**
- Consumes: the Stage 1 boundary and provisional Stage 2 architecture established by Tasks 1–2.
- Produces: a consistent project-wide roadmap without changing load-bearing GPIO/netlist assignments.

- [ ] **Step 1: Update expansion documentation**

Add a “Selected evaluation route” section to `docs/wiring/expansion.md` stating that two Makerfabs ESP32 UWB DW3000 WROOM boards were purchased on 2026-09-09. Explain that the board's onboard ESP32 will run ranging and communicate with the robot ESP32-S3 over a provisional UART boundary.

State the arrival gates in order: board revision/schematic match, exposed-pin verification, standalone supplied-example test, current measurement, UART protocol proof, then coordinated `pin-map.md`/`netlist.md`/diagram update. Preserve the raw DWM1000/DWM3000 SPI-header section as an unpopulated alternative, not the selected Stage 2 diagram.

- [ ] **Step 2: Update the BOM**

Replace “UWB module deliberately not purchased” in `hardware/bom.md` with:

- target quantity: one Makerfabs ESP32 UWB DW3000 WROOM board per robot;
- purchased quantity: two evaluation boards on 2026-09-09;
- not yet installed;
- final harness connector and power entry awaiting delivered-board verification; and
- power-budget recheck still required before sharing the servo rail.

- [ ] **Step 3: Update architecture explicitly**

In `ARCHITECTURE.md`:

- change the sensing subsystem from a future bare SPI module to the selected Makerfabs coprocessor path, marked provisional until arrival verification;
- keep the raw-radio SPI header as an unpopulated optional interface;
- explicitly supersede the settled “part-agnostic header, no committed part” decision because hardware is now purchased;
- update Stage 1 to record power/I2C/three-servo proof while retaining the all-eight-servo and final-assembly Wi-Fi acceptance gaps; and
- update positioning to record two boards purchased and the two-board acceptance sequence.

Do not remove the raw-header `RSTn` open-drain invariant; scope it to the optional direct-radio header.

- [ ] **Step 4: Update agent phase context**

In `AGENTS.md`, replace the stale “harness has not been built” statement with the exact partial-verification boundary. Add that two Makerfabs WROOM UWB boards are inbound and no UART pins or power wiring become authoritative until hardware verification.

- [ ] **Step 5: Check that load-bearing files did not change**

Run:

```bash
git diff --exit-code HEAD -- docs/wiring/netlist.md docs/wiring/pin-map.md
```

Expected: no output and exit 0.

- [ ] **Step 6: Verify project documentation**

```bash
bash scripts/check-wiring-docs.sh
rg -n "Makerfabs|three servos|pending.*verification" \
  ARCHITECTURE.md AGENTS.md docs/wiring/expansion.md hardware/bom.md
```

Expected: checker passes and all four files carry consistent stage language.

- [ ] **Step 7: Commit roadmap documentation**

```bash
git add ARCHITECTURE.md AGENTS.md docs/wiring/expansion.md hardware/bom.md
git diff --cached --check
git commit -m "Record Makerfabs UWB transition plan"
```

### Task 4: Determinism, rendering, and final verification

**Files:**
- Verify only: all files from Tasks 1–3

**Interfaces:**
- Consumes: complete implementation.
- Produces: evidence that generated outputs, links, invariants, and working-tree scope are correct.

- [ ] **Step 1: Prove deterministic generation**

Run:

```bash
python3 docs/wiring/diagrams/generate.py
shasum docs/wiring/diagrams/*.svg > /tmp/wiring-svg-before.sha
python3 docs/wiring/diagrams/generate.py
shasum docs/wiring/diagrams/*.svg > /tmp/wiring-svg-after.sha
diff -u /tmp/wiring-svg-before.sha /tmp/wiring-svg-after.sha
```

Expected: `diff` produces no output.

- [ ] **Step 2: Parse every SVG independently**

```bash
python3 - <<'PY'
from pathlib import Path
from xml.etree.ElementTree import parse
for path in sorted(Path('docs/wiring/diagrams').glob('*.svg')):
    parse(path)
    print(f'ok: {path}')
PY
```

Expected: four `ok:` lines and no exception.

- [ ] **Step 3: Run the full automated checks**

```bash
python3 -m unittest tests/test_wiring_diagrams.py -v
bash scripts/check-wiring-docs.sh
git diff --check
```

Expected: 6 tests pass, wiring checks pass, and `git diff --check` is silent.

- [ ] **Step 4: Render and visually inspect all four outputs**

Open each generated SVG in an SVG-capable viewer or use Pi's image reader. Confirm:

- 1A visibly shows the production antenna overhang/keep-out;
- 1B matches the photographed relative placement and limits its verification claim;
- 2A shows UART to a complete Makerfabs board and no populated raw-radio SPI block;
- 2B shows exactly two Makerfabs boards with a UWB range link;
- no text is clipped and no wire crosses a label ambiguously.

- [ ] **Step 5: Audit repository scope**

```bash
git status --short --untracked-files=all
git log --oneline -4
```

Expected: `.DS_Store` is ignored, no temporary render is present, and only intentional files from this plan changed.

- [ ] **Step 6: Run the final wiring check after all commits**

```bash
bash scripts/check-wiring-docs.sh
```

Expected: `all consistency checks passed`.

Do not push unless the user requests it.

## Self-review

**Spec coverage:** Task 1 records photo provenance and the Stage 1 verification boundary. Task 2 implements all four approved diagram roles, preserves current filenames, removes the misleading direct-SPI Stage 2 depiction, and adds antenna warnings. Task 3 updates stage, purchase, BOM, and architecture status while leaving load-bearing pins unchanged. Task 4 covers deterministic generation, XML validity, visual inspection, repository scope, and the project checker.

**Placeholder scan:** The plan uses “pending delivered-board verification” as a deliberate state, not an unspecified implementation step. Every gate names the evidence needed to advance it. No generic error-handling or test placeholders remain.

**Interface consistency:** `generate.VARIANTS`, `Variant.vid`, `generate.NAMES`, and `generate.build(variant) -> str` are defined in Task 2 and used consistently by its tests and generation command. The four filenames match the approved design and current working tree.
