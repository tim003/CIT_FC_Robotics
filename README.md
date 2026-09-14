# CIT_FC Robotics

A swarm-capable, AI-driven adaptation of the open-source
[Sesame robot](https://github.com/dorianborian/sesame-robot) — an ESP32
quadruped with eight servos and an expressive OLED face.

**Status:** wiring specification complete. No hardware built yet.

The [netlist](docs/wiring/netlist.md) is the source of truth; start from the
[wiring guide](docs/wiring/README.md) to build the harness.

## What's different from upstream

| | Upstream Sesame | This project |
|---|---|---|
| Servo control | 8 GPIOs driven directly | **PCA9685** over I2C |
| Wiring options | Distro Board V1/V3, or hand wiring | PCA9685-based (we have no Distro Board) |
| Microcontroller | Lolin S2 Mini / ESP32-DevKitC | **ESP32-S3 Super Mini** |
| Power | USB-C *or* battery+buck | Dual-source 5V rail, switch-selected |
| Expansion | — | 8 spare PWM channels + reserved UWB header |
| Goal | Expressive desktop robot | **Multi-robot swarm behaviour** |

Two reasons for the change. First, the Distro Boards aren't available to us, and
upstream's hand-wiring route produces a dense harness it describes as having
"a lot of stray wires." Second, the PCA9685 frees eight GPIOs and leaves eight
spare PWM channels — which is what makes room for the AI/swarm work.

## The swarm goal

Each robot should sense where its peers are, enabling group behaviour. Two
complementary layers:

- **Wi-Fi FTM** — time-of-flight ranging on the existing radio. ~1–2m, no extra
  hardware, works because every robot is an ESP32-S3.
- **UWB (DWM1000/DWM3000)** — ~10cm precision, via a reserved 8-pin SPI header.
  Unpopulated today; the pins are held for it.

Plus at least one reserved output (PCA9685 ch8) for a future actuator.

## Documentation

| Document | Purpose |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | **Start here.** Subsystems, invariants, roadmap |
| [`AGENTS.md`](AGENTS.md) | Instructions for AI agents working in this repo |
| [`docs/superpowers/specs/`](docs/superpowers/specs/) | Design specs and reasoning |
| [`docs/wiring/`](docs/wiring/README.md) | The wiring guide, netlist, pin map, power design |
| [`docs/upstream/`](docs/upstream/divergence.md) | What we changed vs upstream, and why |
| [`hardware/bom.md`](hardware/bom.md) | BOM delta vs upstream |

Run `scripts/check-wiring-docs.sh` after editing any wiring document — it
enforces cross-document consistency mechanically.

## Hardware

| Part | Role |
|---|---|
| ESP32-S3 Super Mini | Controller. I2C on GPIO2 / GPIO3 |
| PCA9685 | 16-channel 12-bit PWM/servo driver, I2C `0x40` |
| 8× MG90S servo | Legs (2 per leg) |
| [MN096-12864-4 SSD1315 128×64 OLED](docs/wiring/display.md) | Face, I2C `0x3C`; driven through the compatible Adafruit SSD1306 library |
| LM2596S | Buck converter for battery operation |

Frame, CAD, and STLs come from upstream — they are not duplicated here.

## Safety

Three mistakes that destroy hardware, spelled out because they are easy to make:

1. **Adjust the LM2596S to ~5.2V before connecting any load.** These modules
   ship at arbitrary output voltages.
2. **PCA9685 `VCC` (3.3V logic) and `V+` (5V servo power) are different nets.**
   Do not connect them.
3. **UWB `RSTn` is open-drain** — drive it low or leave it floating, never high.

Full list in [`ARCHITECTURE.md`](ARCHITECTURE.md#design-invariants).

## Credits

Built on [dorianborian/sesame-robot](https://github.com/dorianborian/sesame-robot)
(Apache-2.0). Upstream remains the authority for CAD, printing, and the
animation format.
