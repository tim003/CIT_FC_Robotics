# Expansion — spare outputs and the UWB header

What this build leaves room for, and why the room is shaped the way it is.

## Reserved PWM output

The PCA9685 drives eight legs on `ch0`–`ch7`, leaving eight channels unused:

| Channel | Status |
|---|---|
| ch0 – ch7 | Legs. Assigned in the [netlist](netlist.md), rows 19–26 |
| ch8 | **Reserved output** — designated, not yet populated |
| ch9 – ch15 | Spare |

`ch8` is deliberately designated rather than left generically spare, so a
second thing wanting a PWM output has an obvious home that does not disturb
leg channel ordering.

The PCA9685's channels are 12-bit PWM, not servo-specific. Anything that takes
a PWM input works: LEDs, an ESC, a small pump. The channel does not care.

**Populating `ch8` requires re-checking the power budget** in
[power.md](power.md) rather than assuming headroom exists. The eight legs
already peak above the converter's continuous rating.

## Selected Stage 2 UWB route

Two Makerfabs ESP32 UWB DW3000 WROOM evaluation boards were purchased on
2026-09-09 but have not arrived or been integrated. After acceptance, the
intended deployment is one board per robot. The selected architecture uses the
Makerfabs onboard ESP32 as the UWB coprocessor and exchanges processed range
and status data with the robot ESP32-S3 over UART; raw DW3000 timing remains on
the Makerfabs board.

The exact UART GPIOs, connector pins, logic levels, and power feed require
delivered-board verification and are not yet authoritative. Initial integration
uses separate USB power for the robot controller and Makerfabs board plus a
common signal ground before UART TX/RX are connected. Sharing the servo rail is
allowed only after Makerfabs idle, ranging-average, and peak current are
measured and regulator headroom is approved against the servo requirement.
Follow the [Makerfabs Stage 2 implementation
plan](../superpowers/plans/2026-09-09-makerfabs-stage2-integration.md) for the
audit and acceptance gates.

## Optional raw-radio UWB header

The existing 8-pin, part-agnostic bare-radio SPI header remains an unpopulated
alternative; it is not the selected Stage 2 route. It is not wired for a
specific module — the pin set is chosen so that either supported part drops in
without touching the harness. Netlist rows 27–34.

`SCK · MOSI · MISO · CSn · IRQ · RSTn · WAKEUP · EXTON`

The first six are what any DW-series part needs. `WAKEUP` and `EXTON` are the
two extra control lines the DWM3000 has and the DWM1000 does not. Landing all
eight now is the entire reason a swap later is a firmware change rather than a
rewiring job.

**`RSTn` is open-drain.** Pull it low to reset and release it to high-Z.
Never drive it high — that fights the module's internal pull-up.

### DWM1000 vs DWM3000

| | DWM1000 | DWM3000 |
|---|---|---|
| Silicon | DW1000 | DW3000 |
| Logic level | 3.3 V | 3.3 V |
| Level shifting | none needed | none needed |
| Max SPI clock | 20 MHz | 36 – 38 MHz |
| SPI before PLL lock | **3 MHz** | — |
| Extra control pins | — | `WAKEUP`, `EXTON` |
| Driver | DW1000 library | DW3000 / Qorvo API — not compatible |

Both are 3.3 V parts, which is why the header hangs off the `3V3` net with no
translation. Neither is 5 V tolerant.

Two practical notes:

- The DW1000's 20 MHz maximum is **conditional on the clock PLL being
  locked**. Until it locks, the part accepts only 3 MHz. Firmware must open
  the SPI bus slow and raise the clock after lock, or initialisation fails in
  a way that looks like a wiring fault.
- The driver libraries are not interchangeable. Swapping the module is a
  firmware change; the point of the header is that it is *only* a firmware
  change.

## Positioning roadmap

Two tiers, and the cheaper one is worth doing first.

**Tier 1 — Wi-Fi, no BOM cost.**

| Method | Accuracy | Constraint |
|---|---|---|
| RSSI trilateration | ±3 – 5 m | Degrades badly indoors; multipath dominates |
| 802.11 FTM (round-trip time) | ≈ 1 – 2 m | Needs FTM support at **both** ends |

FTM's both-ends requirement is already satisfied: the swarm is entirely
ESP32-S3 boards, which support it. This tier costs nothing in hardware and is
the sensible baseline.

**Tier 2 — UWB, ≈ 10 cm.**

An order of magnitude better, at the cost of a module per robot, the power
budget re-check above, and a driver integration. The header exists so that
this tier is available without redesigning the harness — not because it is
needed on day one.
