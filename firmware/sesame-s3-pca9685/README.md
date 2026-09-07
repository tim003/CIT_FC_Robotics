# sesame-s3-pca9685

Our fork of upstream's `sesame-firmware-main.ino`, retargeted to the
**ESP32-S3 Super Mini + PCA9685**.

Wiring is specified in [`docs/wiring/netlist.md`](../../docs/wiring/netlist.md),
which is the source of truth. This sketch implements that netlist and nothing
else — if the two disagree, the netlist wins.

## What changed vs upstream

Branch point: [`dorianborian/sesame-robot`](https://github.com/dorianborian/sesame-robot)
@ `86d2bf8`. The diff is deliberately tiny — **166 changed lines, four
substantive edits**, exactly the blast radius predicted in
[`docs/upstream/divergence.md`](../../docs/upstream/divergence.md):

| Upstream | Change |
|---|---|
| `#include <ESP32Servo.h>` | → `Adafruit_PWMServoDriver.h` |
| `I2C_SDA 33` / `I2C_SCL 35` | → GPIO2 / GPIO3 |
| `Servo servos[8]` + `servoPins[8]` + 8×`attach()` | Removed. One PCA9685 object |
| `ESP32PWM::allocateTimer()` ×4 | Removed. The MCU no longer generates servo PWM |
| `setServoAngle()` | Rewritten onto `pwm.setPWM(channel, 0, pulse)` |
| — | **Added:** PCA9685 `OE` on GPIO18, held disabled through boot |
| — | **Added:** UWB pin reservations (defines only, nothing driven) |

Everything else — the face engine, `movement-sequences.h`, the JSON API, the
captive portal, Sesame Studio compatibility — is byte-identical to upstream.
That portability is the whole point of keeping PCA9685 channel `n` bound to
upstream's `servoPins[n]`.

## Pulse geometry — read before changing `SERVOMAX`

Upstream calls `attach(servoPins[i], 732, 2929)`. Those are **microseconds**,
and ESP32Servo **silently clamps** the top end:

```c
// ESP32Servo.h
#define MIN_PULSE_WIDTH   500
#define MAX_PULSE_WIDTH  2500
// ESP32Servo.cpp — attach()
if (max > MAX_PULSE_WIDTH) max = MAX_PULSE_WIDTH;
```

So upstream's real sweep is **732 – 2500 µs**. The `2929` never reached a servo.

The PCA9685 is 12-bit — 4096 steps per period (NXP PCA9685 datasheet).
`setPWMFreq(50)` programs prescale 121 → 50.03 Hz → 19988 µs period →
**4.88 µs per count**, giving `SERVOMIN 150` (732 µs) and `SERVOMAX 512`
(2500 µs).

Measured fidelity against upstream across all 181 integer angles: **worst
deviation 6.1 µs = 0.62° of travel**, which is under a third of one step of
upstream's own 10-bit LEDC timer (~19.5 µs). The port is finer than the
original.

> **`SERVOMAX 600` is a trap.** 600 counts = 2928 µs — the value upstream
> *asked* for and never got, and the value the initial 3-servo bench sketch
> used. It sweeps **17.1% further** at the top end than any existing animation
> was authored for. Raise it only after a loaded, one-leg-at-a-time bench test.

## Dependencies

Verified against these exact versions:

| Requirement | Version used |
|---|---|
| ESP32 Arduino core | 3.3.11 |
| Adafruit PWM Servo Driver Library | 3.0.3 |
| Adafruit SSD1306 + Adafruit GFX + Adafruit BusIO | installed |

`ESP32Servo` is **no longer needed** and should not be installed for this
sketch.

### Upstream headers (not vendored)

Three unmodified upstream headers must sit **in this folder, next to the
`.ino`** — an Arduino sketch folder is the compilation unit, so the compiler
looks nowhere else.

They are not committed — `firmware/` holds our modified files only, and
re-committing 297 KB of unchanged upstream bitmaps would just create a silent
fork. All three are listed in `.gitignore`, so a plain `git add firmware/` will
not pick them up by accident. Fetch them with:

```sh
cd firmware/sesame-s3-pca9685
U=https://raw.githubusercontent.com/dorianborian/sesame-robot/86d2bf8099754fd548c7cf98ee11fc9e9cdb5092/firmware
curl -sfLO $U/face-bitmaps.h
curl -sfLO $U/movement-sequences.h
curl -sfLO $U/captive-portal.h
```

The unmodified upstream sketch is excluded on the same grounds. Fetch it into
`firmware/` when you want a baseline to diff this port against:

```sh
curl -sfL $U/sesame-firmware-main.ino \
  -o "firmware/original sesame-firmware-main.ino"
```

The delta it would show is described in
[`docs/upstream/divergence.md`](../../docs/upstream/divergence.md).

## Build

```sh
arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  -u -p /dev/cu.usbmodem* firmware/sesame-s3-pca9685
```

**`CDCOnBoot=cdc` is not optional.** The ESP32-S3 Super Mini has native USB and
no UART bridge. The core defaults this to *Disabled*, which sends `Serial`
output to UART0 on GPIO43/44 instead of the USB port — so the serial monitor
stays completely blank and every diagnostic in this sketch is invisible. In the
Arduino IDE the same setting is **Tools → USB CDC On Boot → Enabled**.

Last verified result: **1106845 bytes, 84% of program storage**, from a
`--clean` build. That is tight on the default partition scheme — if you add
code and it overflows, switch to a partition scheme with a larger app slot
rather than deleting faces.

> **Always verify with `--clean`.** `arduino-cli` caches aggressively and will
> happily report a successful size for a *previous* build while the current
> source does not compile at all. A stale cache already produced one false
> "verified" result on this sketch.

## Before first power-up

Full checklist is in [`docs/wiring/README.md`](../../docs/wiring/README.md).
The three that destroy hardware:

1. **PCA9685 `VCC` is 3V3, `V+` is the 5 V rail.** They are different supplies
   on the same board. 5 V into `VCC` destroys it.
2. **Set the LM2596S to 5.2 V no-load *before* connecting anything.**
3. **Servo current must not flow through the ESP32** — servo power comes off
   the PCA9685's own 3-pin headers.

On boot the sketch drives `OE` HIGH (outputs disabled) before touching I2C,
and releases it LOW only after the PWM frequency is programmed. Servos stay
limp until the first command, same as upstream.

If the PCA9685 does not answer at `0x40`, the serial log says so at 115200
baud rather than failing silently.

One more that destroys nothing but costs a day: **seat the board so its
antenna end overhangs the breadboard**, clear of the metal strips — see
[`docs/wiring/antenna.md`](../../docs/wiring/antenna.md).

## Known trap: a missing OLED kills the Wi-Fi AP

Inherited from upstream, unchanged:

```c
if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
  Serial.println(F("SSD1306 allocation failed."));
  while (1);            // halts here
}
```

This runs **before** `WiFi.softAP()`. If the SSD1306 does not answer at `0x3C`,
the board stops dead and the `Sesame-Controller` network never appears — which
looks like a Wi-Fi fault but is an I2C fault.

First checkpoint on boot: the OLED should display `Setting up WiFi...`. If it
does, I2C is fine and the halt is not your problem.

To find out what is actually on the bus, run
[`firmware/test/i2c-scan`](../test/i2c-scan/i2c-scan.ino). Some SSD1306 modules
are strapped to `0x3D` rather than `0x3C`.

## Known trap: a breadboard kills the Wi-Fi radio

The Super Mini's antenna is printed on one end of its own PCB. Seated
centrally in a breadboard, that antenna sits over the metal contact strips,
which detune and absorb it. The board still *hears* nearby networks, but
nothing can reach it: `Sesame-Controller` reports a successful start and stays
invisible to every client.

**Seat the board with its antenna end overhanging the breadboard.** The full
account, including the measurements and the PCB keep-out rules, is in
[`docs/wiring/antenna.md`](../../docs/wiring/antenna.md).

This is not a firmware fault and no code change fixes it. If the network does
not appear, check the board's physical placement before reading a single line
of this sketch.

## Not implemented

The UWB header is **reserved, not populated**. The sketch defines the pin
numbers (netlist rows 27–34) and deliberately never calls `pinMode()` on them,
so they stay high-Z — an unpopulated header should not be driven.

`RSTn` (GPIO21) is **open-drain**: pull low to reset, release to high-Z, never
drive high. See [`docs/wiring/expansion.md`](../../docs/wiring/expansion.md)
before fitting a module.
