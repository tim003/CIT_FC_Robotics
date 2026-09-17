# Firmware installation — ESP32-S3 Super Mini

Use this guide to install the latest production firmware on a new or replacement
ESP32-S3 Super Mini. The first installation is over USB; later updates can use
authenticated Wi-Fi OTA.

## Safety boundary

Flash the ESP32 **before seating it in the robot circuit**. On this Super Mini,
USB VBUS is directly connected to the 5V pin. Connecting USB while the board is
installed can backfeed `5V_RAIL`, energize the PCA9685 servo rail, and feed the
buck converter from the wrong direction.

Before handling the assembled robot:

- turn off and disconnect robot power;
- keep the old controller powered off;
- support the robot before any powered test;
- use the battery/LM2596 rail, never laptop USB, for servo movement;
- preserve the ESP32 antenna keep-out described in
  [`docs/wiring/antenna.md`](wiring/antenna.md).

## 1. Prepare the workstation

The verified environment is macOS with Arduino CLI 1.5.1. Install the CLI if it
is not already available:

```sh
brew install arduino-cli
```

Configure the Espressif package index, then install the verified ESP32 core:

```sh
arduino-cli config init
arduino-cli config add board_manager.additional_urls \
  https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core update-index
arduino-cli core install esp32:esp32@3.3.11
```

If `arduino-cli config init` reports that a configuration already exists, keep
that file and run the remaining commands. Confirm the installed core:

```sh
arduino-cli core list
```

Install the firmware libraries:

```sh
arduino-cli lib install "Adafruit PWM Servo Driver Library@3.0.3"
arduino-cli lib install "Adafruit SSD1306@2.5.17"
```

Arduino CLI installs the SSD1306 dependencies, including Adafruit GFX and
Adafruit BusIO. Do not install `ESP32Servo`; this PCA9685 build does not use it.

## 2. Obtain the repository and upstream headers

For a new checkout:

```sh
git clone https://github.com/tim003/CIT_FC_Robotics.git
cd CIT_FC_Robotics
```

Three byte-identical upstream headers are intentionally not committed. Fetch
the pinned versions into the Arduino sketch directory:

```sh
cd firmware/sesame-s3-pca9685
U=https://raw.githubusercontent.com/dorianborian/sesame-robot/86d2bf8099754fd548c7cf98ee11fc9e9cdb5092/firmware
curl -sfLO "$U/face-bitmaps.h"
curl -sfLO "$U/movement-sequences.h"
curl -sfLO "$U/captive-portal.h"
cd ../..
```

## 3. Configure this robot

Run the configuration script from the repository root:

```sh
./scripts/configure-ota.sh
```

It prompts for:

1. device hostname, such as `ssbot-1`;
2. robot AP SSID, such as `Sesame_One`;
3. robot AP password and confirmation;
4. OTA password and confirmation.

The hostname must be unique while multiple robots are powered. The AP SSID
should also be unique for each robot. A replacement controller for the same
robot should reuse that robot's identity; do not power the old and replacement
controllers simultaneously.

The script writes:

```text
firmware/sesame-s3-pca9685/ota-local-config.h
```

This mode-`0600`, gitignored file contains the plaintext AP password and an
authentication-equivalent OTA password hash. Never commit or share it. Verify
that Git ignores it:

```sh
git check-ignore -v firmware/sesame-s3-pca9685/ota-local-config.h
```

A replacement board does **not** require rerunning the script when the existing
header already contains the desired hostname, AP identity, and credentials.
Rerun it if the header came from an older build and does not contain
`SESAME_AP_SSID` and `SESAME_AP_PASSWORD`, or if any identity or password must
change. The sketch deliberately refuses to compile when an older, incomplete
local header is present, preventing a configured robot from silently reverting
to the public AP defaults.

Without this local header, the firmware still compiles with public defaults,
but OTA is omitted entirely. Do not use that build for a controller that should
receive future Wi-Fi updates.

## 4. Flash the isolated ESP32 over USB

Keep the ESP32 out of the robot circuit. Connect only its USB-C port, then find
the exact serial device:

```sh
arduino-cli board list
```

Compile from scratch and upload, replacing the example port with the listed
`/dev/cu.usbmodem...` path:

```sh
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  -u -p /dev/cu.usbmodemXXXX \
  firmware/sesame-s3-pca9685
```

`CDCOnBoot=cdc` is required for USB serial diagnostics on the ESP32-S3 Super
Mini.

If the board does not enter the bootloader, hold **BOOT**, tap **RESET**, release
**BOOT**, rerun `arduino-cli board list`, and upload again. Do not solve an
upload failure by connecting USB while the board is seated in the powered robot.

After upload succeeds, disconnect USB before installing the controller.

## 5. Install and perform first-boot checks

1. Confirm robot power is off.
2. Seat the ESP32 in the verified orientation from the
   [netlist](wiring/netlist.md), with its PCB antenna end overhanging the board
   and clear of metal strips.
3. Recheck that PCA9685 `VCC` is 3.3V logic and `V+` is the separate 5V servo
   rail.
4. Raise or securely support the robot.
5. Power it normally from the battery/LM2596 rail.
6. Confirm the OLED shows `Setting up WiFi...`.
7. Confirm the configured robot AP appears and connect to it.
8. Open `http://<hostname>.local`; while connected directly to the robot AP,
   `http://192.168.4.1` is the fallback.
9. Confirm the controller page loads before commanding movement.

A missing OLED halts firmware before Wi-Fi starts. If the AP does not appear,
first verify that the OLED responds at `0x3C`, the PCA9685 responds at `0x40`,
and the ESP32 antenna is not positioned over breadboard metal.

For movement acceptance, follow the staged **Rest → Stand → Wave → raised Walk
→ Stop** procedure in the
[production firmware README](../firmware/sesame-s3-pca9685/README.md#staged-acceptance-sequence).
Do not begin with Walk on the floor.

## 6. Later Wi-Fi updates

Once this configured build is running, future firmware can be installed from
the repository root with:

```sh
./scripts/ota-upload.sh
```

Keep the robot supported throughout the transfer and reboot. Enter the current
hostname or IP and the OTA password when prompted. The uploader always performs
a clean build, checks the image against the OTA slot limit, and resolves a
hostname to the numeric network port required by Arduino CLI on macOS.

For detailed OTA failure behavior and recovery, see
[`firmware/sesame-s3-pca9685/README.md`](../firmware/sesame-s3-pca9685/README.md#wi-fi-firmware-updates).
