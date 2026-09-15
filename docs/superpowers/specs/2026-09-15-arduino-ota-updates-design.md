# Arduino OTA Updates Design

**Date:** 2026-09-15

## Goal

Allow routine production-firmware updates over Wi-Fi while the ESP32-S3 Super
Mini remains installed in the robot. Keep USB flashing as the recovery path,
but require it only once more to install OTA support.

## User workflow

A local setup script configures one robot before its first OTA-enabled USB
flash. A separate upload script performs every later wireless update:

```sh
./scripts/configure-ota.sh
./scripts/ota-upload.sh
```

The setup script asks for a device hostname and OTA password. The upload script
asks for the robot's current hostname or IP and asks for the plaintext password
with terminal echo disabled. No plaintext password is written to the repository
or retained by either script.

## Configuration ownership

The authoritative OTA configuration is the gitignored local file:

```text
firmware/sesame-s3-pca9685/ota-local-config.h
```

It contains:

```c++
#define SESAME_DEVICE_HOSTNAME "chosen-hostname"
#define SESAME_OTA_PASSWORD_HASH "64-lowercase-hex-characters"
```

The hash is authentication-equivalent and must remain untracked even though it
is not the plaintext password. The configuration script writes the file with
mode `0600`.

A clean checkout without this file must still compile. In that state the
existing `sesame-robot` hostname remains active and OTA is disabled. This keeps
reproducible repository builds and prevents accidentally publishing an
unauthenticated update service.

The hostname is device-wide, not OTA-only. It continues to control:

- HTTP mDNS URL (`http://<hostname>.local`)
- Wi-Fi station/DHCP hostname
- `/api/status` host value
- OLED and serial network announcements
- Arduino OTA discovery name

Changing the local configured hostname in an OTA image does not rename the
currently running robot until that image has been uploaded and rebooted. The
uploader therefore asks separately for the robot's current hostname/IP.

## Input validation

The configuration script accepts a single mDNS hostname label:

- 1 through 32 characters
- lowercase ASCII letters, digits, and internal hyphens only
- first and last characters must be a letter or digit
- no `.local` suffix and no dots

The OTA password must be at least 8 characters and must be entered identically
twice. The script recommends 12 or more characters. The password is hashed with
SHA-256 using `shasum -a 256` on macOS, with `sha256sum` as a portable fallback.

## Firmware architecture

Use the `ArduinoOTA` library included with the pinned ESP32 Arduino core
3.3.11. Do not add a third-party OTA dependency or browser upload endpoint.

The existing default 4 MB partition table is retained. It has `otadata`,
`app0`, and `app1`; each OTA application slot is `0x140000` bytes (1,310,720
bytes). The upload script and clean compile verification must reject an image
larger than one slot.

When local OTA configuration exists, firmware:

1. sets `deviceHostname` from `SESAME_DEVICE_HOSTNAME`;
2. configures ArduinoOTA on TCP port 3232;
3. calls `ArduinoOTA.setPasswordHash(SESAME_OTA_PASSWORD_HASH)`;
4. leaves mDNS ownership with the existing responder and advertises the
   authenticated `_arduino._tcp` service alongside HTTP;
5. services ArduinoOTA from the top-level loop and from both existing blocking
   wait helpers (`delayWithFace()` and `pressingCheck()`).

`ArduinoOTA.setMdnsEnabled(false)` prevents ArduinoOTA from starting or ending
a second responder. Every existing `startMdns()` call must re-advertise both
HTTP and Arduino OTA when OTA is configured.

## Actuation safety

Starting OTA is an asynchronous safety boundary. The start callback must:

1. clear `currentCommand`;
2. leave idle animation mode;
3. drive active-low PCA9685 OE HIGH through the existing output-enable adapter;
4. set `servoOutputsReady` false;
5. show an OLED message that firmware update is active and servo outputs are
   disabled.

The shared, host-testable helper has this exact interface:

```c++
template <typename OutputEnable>
void prepareServoOutputsForFirmwareUpdate(OutputEnable& outputEnable,
                                          bool& servoOutputsReady);
```

It calls `holdServoOutputsDisabled(outputEnable)` before setting
`servoOutputsReady = false`.

Track whether the OTA start callback has run. Errors after that boundary leave
outputs disabled until a manual reboot; the firmware must not silently
re-enable them. Authentication and updater-begin errors occur before the start
callback and must not change servo state, otherwise an unauthenticated network
client could make a walking robot collapse merely by submitting a bad password.
On success, ArduinoOTA validates the inactive partition and reboots normally;
the existing boot path again holds OE HIGH, probes `0x40`, clears all sixteen
PCA9685 channels, and only then releases OE.

Because disabling outputs makes the assembled robot limp, operator instructions
must require physically supporting or raising the robot before every OTA
attempt.

## Upload script

`scripts/ota-upload.sh`:

- requires `arduino-cli` and the local configuration file;
- prompts for current hostname/IP, defaulting to the configured hostname;
- appends `.local` to a simple hostname but leaves IP addresses and already
  qualified names unchanged;
- reads the OTA password silently;
- compiles with `--clean` and
  `esp32:esp32:esp32s3:CDCOnBoot=cdc` into a temporary directory;
- checks the generated `.bin` is no larger than 1,310,720 bytes;
- invokes `arduino-cli upload` with network protocol, OTA port 3232, the exact
  `.bin`, and the password upload field;
- removes temporary files and unsets the password on every exit.

The plaintext password does not enter shell history. It necessarily exists
briefly in process memory and in the uploader child process's argument list.
That limitation is documented.

## Security boundary

The OTA password is authentication, not encrypted transport. Anyone who knows
the password and can reach the robot's AP or station interface can replace the
firmware. The password hash is credential-equivalent and remains gitignored.
Physical access still permits USB reflashing; secure boot and flash encryption
are outside this feature.

## Failure and recovery

- Missing local config: firmware compiles with OTA disabled; upload script exits
  before compiling.
- Invalid configuration input: setup script exits without replacing an existing
  valid file.
- Authentication failure before the start callback: active firmware and servo
  state remain unchanged; the failure is logged.
- Interrupted OTA after the start callback: active firmware remains in its
  current partition; servo outputs stay disabled until reboot.
- Invalid/non-booting new image: recovery requires USB flashing, potentially
  requiring access to or removal of the installed ESP32.
- Forgotten password or erased local config: rerun configuration and install by
  USB, or preserve the existing local config backup outside Git.

## Non-goals

- Browser-based firmware upload
- Firmware signing, secure boot, or encrypted flash
- Persisting OTA credentials in ESP32 NVS
- Changing AP SSID/password or Wi-Fi provisioning behavior
- Automatically moving to Rest or Stand before update
- Eliminating USB as the recovery mechanism
- Claiming hardware OTA acceptance before a user-controlled live upload
