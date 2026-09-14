# Bench test sketches

Small single-purpose sketches for bringing up hardware and for proving a new
board works *before* it is wired into anything. Each one tests exactly one
thing, so a failure points at one cause.

## Board acceptance test

Run this on every new ESP32-S3 before wiring it up. Two minutes, and it
catches the failures that are painful to diagnose through a full harness.

| Step | Sketch | Pass condition |
|---|---|---|
| 1 | `wifi-sta-test` | `CONNECTED -- THE TRANSMITTER WORKS` |
| 2 | `wifi-ap-test` | Access point visible on a phone |
| 3 | `i2c-scan` | Both devices found, once wired |

Repeat steps 1–2 again in the final mechanical assembly. The chassis can
detune the radio just as a breadboard does — see
[../../docs/wiring/antenna.md](../../docs/wiring/antenna.md).

## The sketches

### `i2c-scan`
Scans the I2C bus on GPIO2 (SDA) and GPIO3 (SCL) and lists what answers.
Expect the SSD1306 and the PCA9685 at the two addresses given in
[../../docs/wiring/netlist.md](../../docs/wiring/netlist.md). Use it whenever
the display stays blank or the servo driver does not respond — the main
firmware halts on a missing display, which looks like a boot failure.

### `wifi-ap-test`
Starts the same access point the robot firmware does, then reports what
actually happened — including the return value of `softAP()`, which upstream
discards. It also scans for nearby networks first, so a receive failure can
be told apart from a transmit failure without needing a second device.

### `wifi-sta-test`
Joins an existing network. Edit `TEST_SSID` and `TEST_PASS` at the top before
flashing; the target must be **2.4 GHz**, since the ESP32 cannot see 5 GHz.

This is the strongest single test of the radio: association requires
transmitting and being heard back. Prefer a phone hotspot over an office
network — it rules out enterprise authentication, MAC filtering and a wrong
password in one move.

### `robotics_esp32s3/robotics_esp32s3.ino`
Eight-servo PCA9685 mapping test plus OLED display, with no Wi-Fi. It uses the
production pulse limits and tests one channel at a time at 0°, 90°, and 180°,
returns it to 90°, then releases its PWM output before advancing.

| PCA9685 pin | Physical joint | Upstream name | PCA9685 pin | Physical joint | Upstream name |
|---:|---|---|---:|---|---|
| 0 | ULF — Upper Left Front | L1 | 4 | URF — Upper Right Front | R1 |
| 1 | ULB — Upper Left Back | L2 | 5 | URB — Upper Right Back | R2 |
| 2 | LLF — Lower Left Front | L3 | 6 | LRF — Lower Right Front | R3 |
| 3 | LLB — Lower Left Back | L4 | 7 | LRB — Lower Right Back | R4 |

The OLED shows these pin numbers, abbreviations, and last commanded angles in
two columns. A leading `*` marks the currently energized servo. The displayed
angles are commands, not measurements; MG90S servos provide no position
feedback in this build.

> **Physical test order differs from production logical order.** This sketch
> exercises channels 0–7 in physical PCA9685 sequence. The production firmware
> uses logical indices 0–7 (R1, R2, L1, L2, R4, R3, L3, L4) and applies the
> translation `{4,5,0,1,7,6,2,3}` to reach the physical channels. Upstream
> build-guide procedure: fit servo horns while the motors hold Stand position,
> then alternate Rest/Stand several times before fastening the horns, and again
> before running Wave. This catches bind and polarity errors before the robot
> is fully assembled.

## Building

All sketches need the native-USB serial flag, or the serial monitor stays
blank and you lose every diagnostic message:

```sh
arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  -u -p /dev/cu.usbmodem101 firmware/test/<sketch>
arduino-cli monitor -p /dev/cu.usbmodem101 -c baudrate=115200
```

For the servo mapping test, `<sketch>` is `robotics_esp32s3`:

```sh
arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/test/robotics_esp32s3
```

Find the port with `arduino-cli board list`.

The host-side mapping and OLED-format regression test does not require Arduino
libraries:

```sh
c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/test/robotics_esp32s3 \
  tests/robotics_esp32s3_servo_map_test.cpp \
  -o /tmp/robotics_esp32s3_servo_map_test
/tmp/robotics_esp32s3_servo_map_test
```

Two traps worth knowing, both of which cost time here:

- **Always pass `--clean`.** `arduino-cli` caches builds and will report a
  successful size for a *previous* build while the current source does not
  compile at all.
- **Close the serial monitor before flashing.** Only one program can hold a
  serial port. A monitor left running in another window produces
  `Download mode successfully detected, but getting no sync reply`, which
  reads like a dead board. Recover with:

  ```sh
  lsof /dev/cu.usbmodem101   # find the process holding it
  kill <PID>
  ```
