# Arduino OTA Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add authenticated ArduinoOTA updates and prompt-driven local tooling so the installed ESP32 can receive routine firmware updates over Wi-Fi without committing credentials.

**Architecture:** A gitignored local header supplies the device-wide hostname and SHA-256 OTA password verifier; a clean checkout compiles with the existing hostname and OTA disabled. Native ESP32 `ArduinoOTA` shares the existing mDNS responder and crosses a tested fail-closed servo-output boundary before accepting an image. Two shell scripts configure the local header and perform clean, size-checked network uploads.

**Tech Stack:** ESP32 Arduino core 3.3.11, built-in ArduinoOTA/ESPmDNS, Arduino CLI, Bash, SHA-256 (`shasum`/`sha256sum`), C++17 host tests.

**Spec:** [`docs/superpowers/specs/2026-09-15-arduino-ota-updates-design.md`](../specs/2026-09-15-arduino-ota-updates-design.md)

## Global Constraints

- A clean checkout without `ota-local-config.h` must compile with hostname `sesame-robot` and OTA disabled.
- The authoritative local OTA configuration is `firmware/sesame-s3-pca9685/ota-local-config.h`; it is gitignored and mode `0600`.
- Never commit or print a real plaintext OTA password or its authentication-equivalent SHA-256 verifier; the fixed non-secret credential used by automated tests may appear only in tests and this plan.
- Hostnames are 1–32 lowercase letters/digits/internal hyphens, with alphanumeric first and last characters and no dots or `.local` suffix.
- OTA passwords are at least 8 characters, entered twice during configuration, and read with terminal echo disabled.
- Use only the ESP32 core 3.3.11 built-in `ArduinoOTA`; no new third-party dependency or browser endpoint.
- OTA uses port 3232 and the existing mDNS responder; do not create competing mDNS ownership.
- The default dual-slot partition scheme remains unchanged; an OTA image must not exceed 1,310,720 bytes.
- At OTA start, clear the current command, leave idle mode, drive active-low PCA9685 OE HIGH, and mark servo outputs unavailable.
- Errors after the OTA start callback must leave servo outputs disabled until reboot; pre-start authentication/begin failures must not alter servo state.
- Service OTA in `loop()`, `delayWithFace()`, and `pressingCheck()` so animations do not make discovery or update initiation unreachable.
- Preserve `LOGICAL_TO_PCA_CHANNEL = {4,5,0,1,7,6,2,3}`, pulse bounds `150..512`, 50 Hz, the `0x40` fail-closed probe, and all upstream movement data.
- Do not add UWB runtime behavior or change AP SSID/password and Wi-Fi provisioning behavior.
- Preserve the production sketch's existing mixed-EOL convention without whole-file line-ending churn.
- Do not touch or commit non-canonical `firmware/test/robotics_1stservo_test/` material.
- No firmware upload or hardware acceptance claim occurs during automated implementation.

---

### Task 1: Prompt-driven local OTA configuration and uploader

**Files:**
- Modify: `.gitignore`
- Create: `scripts/configure-ota.sh`
- Create: `scripts/ota-upload.sh`
- Create: `tests/ota_scripts_test.sh`

**Interfaces:**
- Consumes: `arduino-cli`; SHA-256 from `shasum -a 256` or `sha256sum`.
- Produces: gitignored `ota-local-config.h` with `SESAME_DEVICE_HOSTNAME` and `SESAME_OTA_PASSWORD_HASH`; `scripts/ota-upload.sh` consumes those exact macros.

- [ ] **Step 1: Write the failing shell regression test**

Create executable `tests/ota_scripts_test.sh`. It must use a temporary directory
and cleanup trap, invoke each repository script with temporary paths supplied by
environment variables, and exercise real script processes rather than
duplicating their validation logic. Cover these behaviors separately:

```sh
# Valid configuration: stdin is hostname, password, confirmation.
printf 'sesame-one\npassword12\npassword12\n' |
  SESAME_OTA_CONFIG_PATH="$tmp/ota-local-config.h" \
  scripts/configure-ota.sh

grep -Fx '#define SESAME_DEVICE_HOSTNAME "sesame-one"' \
  "$tmp/ota-local-config.h"
grep -Eq '^#define SESAME_OTA_PASSWORD_HASH "[0-9a-f]{64}"$' \
  "$tmp/ota-local-config.h"
! grep -F 'password12' "$tmp/ota-local-config.h"
test "$(stat -f '%Lp' "$tmp/ota-local-config.h" 2>/dev/null ||
        stat -c '%a' "$tmp/ota-local-config.h")" = 600

# Invalid hostname must fail and preserve a pre-existing sentinel config.
printf '%s\n' sentinel > "$tmp/ota-local-config.h"
if printf 'Bad.Host\npassword12\npassword12\n' |
   SESAME_OTA_CONFIG_PATH="$tmp/ota-local-config.h" \
   scripts/configure-ota.sh; then
  exit 1
fi
grep -Fx sentinel "$tmp/ota-local-config.h"

# Mismatched passwords must fail without replacing the sentinel.
if printf 'sesame-one\npassword12\npassword13\n' |
   SESAME_OTA_CONFIG_PATH="$tmp/ota-local-config.h" \
   scripts/configure-ota.sh; then
  exit 1
fi
grep -Fx sentinel "$tmp/ota-local-config.h"
```

For the uploader test, create a fake `arduino-cli` selected through the
`ARDUINO_CLI` environment variable. The fake records every argument in a log;
on `compile`, it parses `--build-path` and creates a 1-byte
`sesame-s3-pca9685.ino.bin`; on `upload`, it exits zero. Assert that:

```text
compile uses --clean
FQBN is esp32:esp32:esp32s3:CDCOnBoot=cdc
upload uses network protocol
upload target defaults to sesame-one.local
OTA port property is 3232
input file is the generated .bin
password upload field reaches the fake CLI
uploader stdout/stderr never contains the plaintext password
```

Also make the uploader fail before invoking the fake CLI when the local config
is absent, and fail before upload when the fake creates a 1,310,721-byte image.

- [ ] **Step 2: Run the script test and verify RED**

Run:

```sh
bash tests/ota_scripts_test.sh
```

Expected: FAIL because `scripts/configure-ota.sh` and
`scripts/ota-upload.sh` do not exist.

- [ ] **Step 3: Implement the configuration script minimally**

Create executable `scripts/configure-ota.sh` with `set -eu`. Resolve the repo
root from the script location and default `SESAME_OTA_CONFIG_PATH` to:

```text
<repo>/firmware/sesame-s3-pca9685/ota-local-config.h
```

Prompt with `printf` and read with `IFS= read -r`; use `read -r -s` for both
password entries and print a newline after each hidden read. Validate the
hostname against:

```sh
case "$hostname" in
  ''|*[!a-z0-9-]*|-*|*-) reject ;;
esac
test "${#hostname}" -le 32 || reject
```

Reject passwords shorter than 8 bytes and mismatches. Hash without a trailing
newline:

```sh
if command -v shasum >/dev/null 2>&1; then
  password_hash=$(printf '%s' "$password" | shasum -a 256 | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  password_hash=$(printf '%s' "$password" | sha256sum | awk '{print $1}')
else
  fail_without_replacing_config
fi
```

Write a temporary sibling file with a restrictive umask, then `chmod 600` and
atomically `mv` it into place. Unset password variables before exit. The final
header contains only:

```c++
#ifndef SESAME_OTA_LOCAL_CONFIG_H
#define SESAME_OTA_LOCAL_CONFIG_H
#define SESAME_DEVICE_HOSTNAME "validated-hostname"
#define SESAME_OTA_PASSWORD_HASH "validated-64-char-hash"
#endif
```

- [ ] **Step 4: Implement the upload script minimally**

Create executable `scripts/ota-upload.sh` with `set -eu`, a temporary build
directory, and an EXIT/HUP/INT/TERM trap that unsets the password and removes
the directory. Default `ARDUINO_CLI=arduino-cli`. Require the local header and
parse only the quoted value of `SESAME_DEVICE_HOSTNAME`; verify the parsed value
again with the same hostname rules.

Prompt for the current hostname/IP, showing the configured hostname as default.
An empty answer uses the default. Append `.local` only when the target contains
neither `.` nor `:`. Prompt for the password with `read -r -s`.

Compile exactly with:

```sh
"$ARDUINO_CLI" compile --clean \
  --build-path "$build_dir" \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  "$repo_root/firmware/sesame-s3-pca9685"
```

Find exactly one `*.ino.bin`, read its byte size portably with `wc -c`, and
reject values greater than `1310720`. Upload with:

```sh
"$ARDUINO_CLI" upload \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  --port "$target" \
  --protocol network \
  --input-file "$firmware_bin" \
  --upload-property upload.port.properties.port=3232 \
  --upload-field "password=$password"
```

Do not use `set -x`, echo the password, write it to a file, or include it in a
suggested shell command.

- [ ] **Step 5: Ignore the authoritative local config explicitly**

Add this focused block to `.gitignore`:

```gitignore
# Per-robot ArduinoOTA identity and authentication-equivalent password hash.
firmware/sesame-s3-pca9685/ota-local-config.h
```

Do not weaken existing secret patterns.

- [ ] **Step 6: Run Task 1 tests and verify GREEN**

Run:

```sh
bash tests/ota_scripts_test.sh
git check-ignore -v firmware/sesame-s3-pca9685/ota-local-config.h
git diff --check
```

Expected: all script cases pass; the exact local header path is ignored; no
diff-hygiene output.

- [ ] **Step 7: Commit Task 1**

```sh
git add .gitignore scripts/configure-ota.sh scripts/ota-upload.sh \
  tests/ota_scripts_test.sh
git commit -m "Add local OTA configuration and upload tools"
```

---

### Task 2: Fail-closed ArduinoOTA firmware integration

**Files:**
- Modify: `firmware/common/sesame_servo_map.h`
- Modify: `tests/sesame_servo_translation_test.cpp`
- Modify: `firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino`

**Interfaces:**
- Consumes: Task 1 macros `SESAME_DEVICE_HOSTNAME` and
  `SESAME_OTA_PASSWORD_HASH`; existing `servoOutputEnable`,
  `servoOutputsReady`, `currentCommand`, `exitIdle()`, `display`, and mDNS
  lifecycle.
- Produces: `prepareServoOutputsForFirmwareUpdate(OutputEnable&, bool&)` and an
  authenticated ArduinoOTA endpoint on port 3232 when local config exists.

- [ ] **Step 1: Write the failing host safety test**

Extend `tests/sesame_servo_translation_test.cpp` after the existing boot-disable
assertions:

```c++
FakeOutputEnable otaOe;
bool outputsReady = true;
prepareServoOutputsForFirmwareUpdate(otaOe, outputsReady);
assert(!outputsReady);
assert(otaOe.configuredPin == PCA9685_OUTPUT_ENABLE_PIN);
assert(otaOe.disabledPin == PCA9685_OUTPUT_ENABLE_PIN);
assert(otaOe.enableCount == 0);
```

- [ ] **Step 2: Run the host test and verify RED**

Run:

```sh
out=$(mktemp /tmp/sesame-ota-safety.XXXXXX)
c++ -std=c++17 -Wall -Wextra -Werror -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp -o "$out"
```

Expected: compile failure naming missing
`prepareServoOutputsForFirmwareUpdate`.

- [ ] **Step 3: Add the minimal host-testable safety helper**

Add to `firmware/common/sesame_servo_map.h` immediately after
`holdServoOutputsDisabled()`:

```c++
template <typename OutputEnable>
void prepareServoOutputsForFirmwareUpdate(OutputEnable& outputEnable,
                                          bool& servoOutputsReady) {
  holdServoOutputsDisabled(outputEnable);
  servoOutputsReady = false;
}
```

- [ ] **Step 4: Run the host test and verify GREEN**

Compile and run the temporary binary, then remove it:

```sh
out=$(mktemp /tmp/sesame-ota-safety.XXXXXX)
c++ -std=c++17 -Wall -Wextra -Werror -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp -o "$out"
"$out"
rm -f "$out"
```

Expected: PASS with no compiler warnings.

- [ ] **Step 5: Add optional local configuration and ArduinoOTA setup**

Modify the production sketch without normalizing unrelated line endings.
Include `<ArduinoOTA.h>` and select configuration at compile time:

```c++
#if __has_include("ota-local-config.h")
#include "ota-local-config.h"
#define SESAME_OTA_CONFIGURED 1
#else
#define SESAME_OTA_CONFIGURED 0
#define SESAME_DEVICE_HOSTNAME "sesame-robot"
#endif
```

Initialize the existing device-wide hostname from
`SESAME_DEVICE_HOSTNAME`. Add constants for OTA port 3232 and a configured
boolean.

Create `startOta()` guarded by `SESAME_OTA_CONFIGURED`. Configure hostname,
port, SHA-256 password hash, and `setMdnsEnabled(false)`. Add a global
`bool otaUpdateStarted = false` and register callbacks:

```c++
ArduinoOTA.onStart([]() {
  otaUpdateStarted = true;
  currentCommand = "";
  exitIdle();
  prepareServoOutputsForFirmwareUpdate(servoOutputEnable,
                                       servoOutputsReady);
  showOtaStatus(F("Firmware update"), F("Servos disabled"),
                F("Do not power off"));
});

ArduinoOTA.onEnd([]() {
  showOtaStatus(F("Update complete"), F("Rebooting..."), nullptr);
});

ArduinoOTA.onError([](ota_error_t error) {
  Serial.printf("OTA error: %u.\\n", static_cast<unsigned>(error));
  if (!otaUpdateStarted) {
    return;
  }
  prepareServoOutputsForFirmwareUpdate(servoOutputEnable,
                                       servoOutputsReady);
  Serial.println(F("Servo outputs remain disabled until reboot."));
  showOtaStatus(F("Update failed"), F("Servos disabled"), F("Reboot robot"));
});
```

This pre-start guard is required: ArduinoOTA reports authentication errors
through `onError()` before `onStart()`. Disabling OE for such an error would let
an unauthenticated client make the robot collapse by submitting a bad password.

Implement `showOtaStatus(const __FlashStringHelper* line1,
const __FlashStringHelper* line2, const __FlashStringHelper* line3)` by clearing
the display, selecting white size-1 text at cursor `(0, 0)`, printing each
non-null line with `println`, and calling `display.display()`.

Call `ArduinoOTA.begin()` only after Wi-Fi and the HTTP server are initialized.
Do not move PCA9685 initialization or automatically command a pose.

- [ ] **Step 6: Share the existing mDNS responder correctly**

Keep `startMdns()` authoritative. After successful `MDNS.begin()` and HTTP
service advertisement, add:

```c++
#if SESAME_OTA_CONFIGURED
MDNS.enableArduino(3232, true);
#endif
```

Because every existing network transition calls `startMdns()`, this restores
both advertisements after `MDNS.end()`. ArduinoOTA itself must have mDNS
disabled to avoid competing ownership.

- [ ] **Step 7: Service OTA in every required execution path**

Under the same compile-time guard, call `ArduinoOTA.handle()`:

- once near the top of `loop()`;
- inside each iteration of `delayWithFace()`;
- inside each iteration of `pressingCheck()`.

Do not add it to pre-Wi-Fi setup loops. If an OTA error returns control to an
animation, `servoOutputsReady == false` must make subsequent servo commands
no-ops.

- [ ] **Step 8: Verify clean-checkout and configured builds**

First ensure no local config exists and build the disabled form:

```sh
rm -f firmware/sesame-s3-pca9685/ota-local-config.h
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
```

Then generate a test-only configured header through the real script using a
non-secret fixture password, build again, record flash/RAM use and verify the
maximum remains 1,310,720 bytes:

```sh
printf 'sesame-test\npassword12\npassword12\n' | scripts/configure-ota.sh
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
rm -f firmware/sesame-s3-pca9685/ota-local-config.h
```

Also run both host tests and the diagnostic compile:

```sh
out1=$(mktemp /tmp/sesame-map.XXXXXX)
out2=$(mktemp /tmp/robotics-map.XXXXXX)
c++ -std=c++17 -Wall -Wextra -Werror -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp -o "$out1" && "$out1"
c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/common -Ifirmware/test/robotics_esp32s3 \
  tests/robotics_esp32s3_servo_map_test.cpp -o "$out2" && "$out2"
rm -f "$out1" "$out2"
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/test/robotics_esp32s3
```

- [ ] **Step 9: Commit Task 2**

Confirm the ignored local config is absent, then commit only the three tracked
files:

```sh
test ! -e firmware/sesame-s3-pca9685/ota-local-config.h
git add firmware/common/sesame_servo_map.h \
  tests/sesame_servo_translation_test.cpp \
  firmware/sesame-s3-pca9685/sesame-s3-pca9685.ino
git commit -m "Add fail-closed ArduinoOTA updates"
```

---

### Task 3: Operator documentation and complete verification

**Files:**
- Modify: `firmware/sesame-s3-pca9685/README.md`
- Modify only if needed for accurate architecture status: `ARCHITECTURE.md`
- Verify: all Task 1 and Task 2 files

**Interfaces:**
- Consumes: final script prompts, config path/macros, hostname behavior, safety
  callbacks, image-size limit, and actual configured compile size.
- Produces: exact one-time USB setup and repeated Wi-Fi update procedure for the
  operator.

- [ ] **Step 1: Document configuration and the one-time USB installation**

Add an `## Wi-Fi firmware updates` section to the production README. State
that current released firmware must receive one final USB flash after running:

```sh
./scripts/configure-ota.sh
```

Explain that the generated local header is gitignored, mode 0600, and must be
backed up locally if USB recovery after credential loss would be difficult.
Make clear that it configures the device-wide hostname and OTA password—not AP
SSID/password.

Use the existing USB compile/upload command with `--clean` and
`CDCOnBoot=cdc`. Do not claim this one-time upload has occurred.

- [ ] **Step 2: Document the exact repeated Wi-Fi workflow**

Document these operator steps verbatim in meaning:

1. Raise/support the robot because OTA deliberately makes servos limp.
2. Power it normally and stop movement.
3. Connect the computer to `Sesame-Controller` or the same LAN.
4. Confirm `http://<current-hostname>.local` opens.
5. Run `./scripts/ota-upload.sh` from the repository root.
6. Enter the current hostname/IP and OTA password when prompted.
7. Observe the OLED update message; do not power off.
8. Wait for validation and reboot, then reconnect at the configured hostname.
9. If update fails, reboot manually because outputs remain disabled.
10. Use USB recovery if the old image cannot boot or join Wi-Fi.

Explain that changing the configured hostname affects HTTP mDNS, station DHCP,
status API, OLED/serial announcements, and OTA discovery after reboot. Document
the 1,310,720-byte slot limit and the uploader's password-in-process limitation.

- [ ] **Step 3: Run the complete automated verification suite**

Run with no local config left behind:

```sh
bash tests/ota_scripts_test.sh

test ! -e firmware/sesame-s3-pca9685/ota-local-config.h

out1=$(mktemp /tmp/sesame-map.XXXXXX)
out2=$(mktemp /tmp/robotics-map.XXXXXX)
c++ -std=c++17 -Wall -Wextra -Werror -Ifirmware/common \
  tests/sesame_servo_translation_test.cpp -o "$out1" && "$out1"
c++ -std=c++17 -Wall -Wextra -Werror \
  -Ifirmware/common -Ifirmware/test/robotics_esp32s3 \
  tests/robotics_esp32s3_servo_map_test.cpp -o "$out2" && "$out2"
rm -f "$out1" "$out2"

arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/test/robotics_esp32s3
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685

printf 'sesame-test\npassword12\npassword12\n' | scripts/configure-ota.sh
arduino-cli compile --clean \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  firmware/sesame-s3-pca9685
rm -f firmware/sesame-s3-pca9685/ota-local-config.h

bash scripts/check-wiring-docs.sh
! rg -n '#include.*[Uu][Ww][Bb]|UWB_.*PIN|xTaskCreate.*uwb' \
  firmware/sesame-s3-pca9685
git diff --check
git status --short
```

Expected: shell tests and host tests pass; diagnostic, OTA-disabled production,
and OTA-enabled production builds all fit; wiring checker passes; UWB absence
check finds nothing; only intended tracked changes remain.

- [ ] **Step 4: Verify configuration hygiene explicitly**

Run:

```sh
git check-ignore -q firmware/sesame-s3-pca9685/ota-local-config.h
! git ls-files --error-unmatch \
  firmware/sesame-s3-pca9685/ota-local-config.h 2>/dev/null
! rg -n '#define SESAME_OTA_PASSWORD_HASH "[0-9a-f]{64}"' \
  firmware scripts
```

Expected: local config is ignored and untracked; no generated verifier is
embedded in tracked firmware or tooling. The fixed `password12` test fixture is
non-secret and may appear only in this plan and `tests/ota_scripts_test.sh`.
Do not include a generated verifier in reports.

- [ ] **Step 5: Commit Task 3**

```sh
git add firmware/sesame-s3-pca9685/README.md ARCHITECTURE.md
git commit -m "Document authenticated Wi-Fi firmware updates"
```

If `ARCHITECTURE.md` required no change, omit it from `git add` rather than
creating a gratuitous edit.

- [ ] **Step 6: Record the hardware gate**

The first live OTA upload is user-controlled and remains pending. Record in the
verification report that automated integration passed but no wireless image was
sent and no hardware OTA acceptance is claimed.
