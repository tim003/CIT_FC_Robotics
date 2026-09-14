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

Current phase: the **Stage 1 evidence is recorded** and the production harness
is not accepted. The [colleague-built perfboard
record](hardware/circuit%20layout/README.md) verifies power-up, I2C on
GPIO2/GPIO3, and movement of three servos. The user's 2026-09-14 assembled-robot
run of [`firmware/test/robotics_esp32s3/`](firmware/test/robotics_esp32s3/)
verified all eight physical PCA9685 channel-to-joint identities with the
diagnostic sketch. The production sketch has not been uploaded; boot safety,
complete production animation, and Wi-Fi in the photographed stacked assembly
remain unverified. Generated wiring diagrams were retired because they were
not confirmed build evidence; use the raster evidence record for the tested
assembly and the netlist for new construction.

Two Makerfabs ESP32 UWB DW3000 WROOM evaluation boards were purchased on
2026-09-09 but have not arrived or been integrated. The selected Stage 2 route
uses each Makerfabs onboard ESP32 as a UWB coprocessor over UART. Exact UART
GPIOs, connector pins, and power wiring are not authoritative before
delivered-board verification. Initial integration uses separate USB power and
a common signal ground; sharing the servo rail requires measured-current and
regulator-headroom approval. Follow the [Makerfabs Stage 2 implementation
plan](docs/superpowers/plans/2026-09-09-makerfabs-stage2-integration.md).

The optional raw-radio SPI header remains unpopulated and is not the selected
Stage 2 route. Preserve its open-drain `RSTn` invariant: drive it low or leave
it floating, never drive it high. Run `scripts/check-wiring-docs.sh` after
touching any wiring doc.

The robot controller is the **ESP32-S3 Super Mini**, and I2C is on
**GPIO2/GPIO3**. Both were retargeted from the original spec after bench
verification; treat older references to a Lolin S3 Mini or GPIO35/36 as stale.

## Hard rules

1. **The netlist is the source of truth.** `docs/wiring/netlist.md` is what
   someone solders from. Evidence records describe tested assemblies; if they
   disagree with the production target, the netlist wins.
2. **Never contradict a design invariant** in `ARCHITECTURE.md` silently. They
   encode failure modes that destroy hardware.
3. **Pin assignments are load-bearing.** Changing a GPIO means updating the pin
   map, netlist, firmware, and affected wiring documentation together in one
   commit.
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
- **Build evidence:** use dated raster sources and state their verification
  boundary. Generated wiring diagrams are retired unless a later approved
  design explicitly reintroduces them from confirmed hardware facts.
- **Dates:** ISO `YYYY-MM-DD`.

## Repository layout

```
ARCHITECTURE.md      technical spine — read first
AGENTS.md            this file
docs/wiring/         the main deliverable
docs/upstream/       divergence record vs sesame-robot
docs/superpowers/    specs and implementation plans
firmware/            our modified sketch; upstream headers are not vendored
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
