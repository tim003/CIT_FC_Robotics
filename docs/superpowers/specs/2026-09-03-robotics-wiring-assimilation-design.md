# Robotics-wiring assimilation design

**Date:** 2026-09-03

## Purpose

Consolidate useful information from the stray
`/Users/tw/Documents/Obsidian_note/Projects/robotics-wiring` snapshot into the
canonical `Projects/robotics` repository, then remove the stray snapshot.

The canonical repository already contains the current wiring specification.
The snapshot is **not** a second repository: it has no `.git` directory and is
an older, copied documentation tree.

## Audit result

The snapshot cannot be copied wholesale. It targets a Lolin S3 Mini with I2C on
GPIO35/GPIO36, whereas the canonical build target is the bench-verified
ESP32-S3 Super Mini with I2C on GPIO2/GPIO3. Its 37-row netlist, free-pin list,
UWB-header description, battery state and several power claims therefore
conflict with the canonical 34-row netlist.

The snapshot contains:

- duplicate versions of the main wiring documents — rejected as stale;
- `.superpowers/sdd/` worker briefs, review diffs and status reports — rejected
  as obsolete process residue; and
- `docs/wiring/glossary.md` — a useful document type, but its text also embeds
  the stale board and pin-map claims, so it must be rewritten rather than
  copied.

## Canonical authority

`docs/wiring/netlist.md` remains the wiring source of truth. The current
ESP32-S3 Super Mini pin map, GPIO2/GPIO3 I2C assignment, battery decision, UWB
header definition, and power topology are binding. Existing uncommitted
changes to the four generated diagram variants are outside this work and must
remain untouched.

## Assimilation

### New glossary

Add `docs/wiring/glossary.md` as a plain-language companion to the current
wiring guide. It must use current terminology and link to the netlist, pin map,
power design and expansion guide. It must state the current GPIO2/GPIO3 I2C
assignment, the ESP32-S3 Super Mini board, and the 34-row netlist where those
facts are relevant.

It must restate the three hardware-protection constraints in clear language:

1. PCA9685 `VCC` is 3V3 logic and distinct from 5 V `V+`.
2. Servo current does not flow through the ESP32.
3. UWB `RSTn` is open-drain: drive it low or release it to high-Z, never high.

### Candidate improvements

The snapshot may supply ideas, not authority. Before any candidate detail is
merged, validate it against an authoritative existing project document, the
upstream Sesame reference pinned by this repository, or a primary datasheet.

Candidates are:

- exact physical servo identity/order alongside each preserved upstream
  `servoPins[8]` index;
- minimum electrical ratings for the SPDT switch and bulk capacitor;
- clearer staged assembly wording around source selection and first power-on.

Reject a candidate if it requires an unsourced claim about the Super Mini's
physical pinout or USB power path. In particular, do not import claims about
GPIO35/GPIO36 I2C, a Lolin Arduino variant, a fixed free-pin count, a
10-contact UWB header, or USB-VBUS isolation without a source or bench result.

## Safety and cleanup sequence

1. Copy no files wholesale from the snapshot.
2. Implement only validated current-compatible documentation changes in the
   canonical repository.
3. Run the wiring checker and validate changed Mermaid blocks if any.
4. Inspect the staged Git diff to confirm it excludes the pre-existing diagram
   changes.
5. Commit the curated documentation only.
6. Create a final manifest recording which snapshot material was retained
   (glossary and any validated improvements) and rejected (duplicates and SDD
   residue).
7. Move the entire `robotics-wiring` directory to Trash, not permanent deletion,
   and verify it no longer appears under `Projects/`.

## Success criteria

- The canonical repository has a current, source-consistent glossary.
- No stale Lolin/GPIO35/GPIO36 wiring claim is introduced.
- The wiring consistency checker passes.
- Current user diagram edits are neither staged nor modified by this work.
- The snapshot is recoverably removed after the committed documentation is
  verified.
