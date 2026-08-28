# AGENTS.md — CIT_FC Robotics

Instructions for AI agents working in this repository. Loaded automatically by
Pi (and read by Codex/Cursor); Claude Code reads `CLAUDE.md`, so this file is
the model-agnostic home for project instructions.

Vault-level conventions in `/workspace/CLAUDE.md` still apply and are layered
underneath this file — no need to repeat them here.

## Read first

**[`ARCHITECTURE.md`](ARCHITECTURE.md)** — subsystems, design invariants, and
settled constraints. Do not propose changes that violate an invariant without
saying explicitly that you are doing so and why.

The authoritative design reasoning is in
`docs/superpowers/specs/2026-08-28-pca9685-wiring-design.md`.

## What this project is

A swarm-capable adaptation of the open-source Sesame quadruped robot, rewired
around a **PCA9685** PWM driver instead of upstream's Distro Board or hand
wiring, with pins reserved for UWB positioning and extra actuators.

Current phase: **wiring specification**. No firmware work yet.

## Hard rules

1. **The netlist is the source of truth.** `docs/wiring/netlist.md` is what
   someone solders from. Diagrams illustrate it; if they disagree, the netlist
   wins and the diagram is fixed.
2. **Never contradict a design invariant** in `ARCHITECTURE.md` silently. They
   encode failure modes that destroy hardware.
3. **Pin assignments are load-bearing.** Changing a GPIO means updating the pin
   map, the netlist, and any affected diagram together, in one commit.
4. **Do not vendor upstream binaries.** CAD/STL assets stay upstream; reference
   them by URL.
5. **Verify datasheet claims before writing them down.** This is hardware —
   a wrong pin number costs a burnt module, not a failing test. Cite the source.

## Conventions

- **Wire gauges:** 30AWG data, 22AWG power (upstream's guidance; keeps the
  harness manageable).
- **Pin references:** always GPIO numbers, never physical pin positions or
  silkscreen labels alone.
- **I2C addresses:** written in hex with the `0x` prefix.
- **Diagrams:** Mermaid, so they render in Obsidian and on GitHub and diff as
  text. No binary image formats for anything generated.
- **Dates:** ISO `YYYY-MM-DD`.

## Repository layout

```
ARCHITECTURE.md      technical spine — read first
AGENTS.md            this file
docs/wiring/         the main deliverable
docs/upstream/       divergence record vs sesame-robot
docs/superpowers/    specs and implementation plans
firmware/            our modified files only (later phase)
hardware/            BOM delta vs upstream
```

## Git

This is an independent repository (`tim003/CIT_FC_Robotics`), **not** part of
the vault repo — `Projects/` is gitignored at vault level. Use this repo's own
git context. It has a real remote and pushing is expected.

## Upstream reference

[`dorianborian/sesame-robot`](https://github.com/dorianborian/sesame-robot) @
`86d2bf8`. Useful when you need the animation format, CAD, or the original
firmware — but remember our servo control diverges structurally, so upstream
firmware is a reference, not a drop-in.
