#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ota-scripts.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

config_path="$tmp/ota-local-config.h"
output="$tmp/output.log"
fake_log="$tmp/arduino-cli.log"
fake_cli="$tmp/arduino-cli"

printf 'sesame-one\npassword12\npassword12\n' |
  SESAME_OTA_CONFIG_PATH="$config_path" \
  "$repo_root/scripts/configure-ota.sh"

grep -Fx '#define SESAME_DEVICE_HOSTNAME "sesame-one"' "$config_path"
grep -Eq '^#define SESAME_OTA_PASSWORD_HASH "[0-9a-f]{64}"$' "$config_path"
! grep -F 'password12' "$config_path"
test "$(stat -c '%a' "$config_path" 2>/dev/null ||
        stat -f '%Lp' "$config_path")" = 600

git -C "$repo_root" check-ignore -q \
  firmware/sesame-s3-pca9685/ota-local-config.h
git -C "$repo_root" check-ignore -q \
  firmware/sesame-s3-pca9685/ota-local-config.h.tmp.interrupted

printf '%s\n' sentinel >"$config_path"
if printf 'Bad.Host\npassword12\npassword12\n' |
   SESAME_OTA_CONFIG_PATH="$config_path" \
   "$repo_root/scripts/configure-ota.sh" >"$output" 2>&1; then
  echo 'invalid hostname unexpectedly succeeded' >&2
  exit 1
fi
grep -Fx sentinel "$config_path"

if printf 'sesame-one\npassword12\npassword13\n' |
   SESAME_OTA_CONFIG_PATH="$config_path" \
   "$repo_root/scripts/configure-ota.sh" >"$output" 2>&1; then
  echo 'mismatched passwords unexpectedly succeeded' >&2
  exit 1
fi
grep -Fx sentinel "$config_path"

printf 'sesame-one\npassword12\npassword12\n' |
  SESAME_OTA_CONFIG_PATH="$config_path" \
  "$repo_root/scripts/configure-ota.sh" >"$output" 2>&1

cat >"$fake_cli" <<'EOF'
#!/usr/bin/env bash
set -eu

command_name=${1-}
printf 'CALL:%s\n' "$command_name" >>"$FAKE_ARDUINO_LOG"
for argument in "$@"; do
  printf 'ARG:%s:%s\n' "$command_name" "$argument" >>"$FAKE_ARDUINO_LOG"
done

case "$command_name" in
  compile)
    build_path=
    shift
    while test "$#" -gt 0; do
      if test "$1" = --build-path; then
        shift
        build_path=$1
        break
      fi
      shift
    done
    test -n "$build_path"
    mkdir -p "$build_path"
    dd if=/dev/zero \
      of="$build_path/sesame-s3-pca9685.ino.bin" \
      bs="${FAKE_IMAGE_SIZE:-1}" count=1 2>/dev/null
    ;;
  upload)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x "$fake_cli"

assert_arg_pair() {
  command_name=$1
  flag=$2
  value=$3
  awk -v first="ARG:$command_name:$flag" -v second="ARG:$command_name:$value" '
    previous == first && $0 == second { found = 1 }
    { previous = $0 }
    END { exit(found ? 0 : 1) }
  ' "$fake_log"
}

rm -f "$fake_log"
if printf '\npassword12\n' |
   TMPDIR="$tmp/missing-temp-parent" \
   SESAME_OTA_CONFIG_PATH="$tmp/missing-config.h" \
   ARDUINO_CLI="$fake_cli" FAKE_ARDUINO_LOG="$fake_log" \
   "$repo_root/scripts/ota-upload.sh" >"$output" 2>&1; then
  echo 'upload without local config unexpectedly succeeded' >&2
  exit 1
fi
grep -F 'Local OTA configuration not found:' "$output"
test ! -e "$fake_log"

rm -f "$fake_log"
printf '\npassword12\n' |
  SESAME_OTA_CONFIG_PATH="$config_path" \
  ARDUINO_CLI="$fake_cli" FAKE_ARDUINO_LOG="$fake_log" \
  "$repo_root/scripts/ota-upload.sh" >"$output" 2>&1

grep -Fx 'CALL:compile' "$fake_log"
grep -Fx 'ARG:compile:--clean' "$fake_log"
grep -Fx 'ARG:compile:esp32:esp32:esp32s3:CDCOnBoot=cdc' "$fake_log"
grep -Fx "ARG:compile:$repo_root/firmware/sesame-s3-pca9685" "$fake_log"
build_path=$(awk '
  previous == "ARG:compile:--build-path" {
    sub(/^ARG:compile:/, "")
    print
    exit
  }
  { previous = $0 }
' "$fake_log")
test -n "$build_path"
assert_arg_pair compile --build-path "$build_path"
grep -Fx 'CALL:upload' "$fake_log"
grep -Fx 'ARG:upload:esp32:esp32:esp32s3:CDCOnBoot=cdc' "$fake_log"
assert_arg_pair upload --protocol network
assert_arg_pair upload --port sesame-one.local
assert_arg_pair upload --upload-property upload.port.properties.port=3232
firmware_bin=$(awk '
  previous == "ARG:upload:--input-file" {
    sub(/^ARG:upload:/, "")
    print
    exit
  }
  { previous = $0 }
' "$fake_log")
test -n "$firmware_bin"
case "$firmware_bin" in
  "$build_path"/sesame-s3-pca9685.ino.bin) ;;
  *) echo 'upload input file did not come from the configured build path' >&2; exit 1 ;;
esac
assert_arg_pair upload --input-file "$firmware_bin"
grep -Fx 'ARG:upload:password=password12' "$fake_log"
! grep -F password12 "$output"

rm -f "$fake_log"
if printf '\npassword12\n' |
   SESAME_OTA_CONFIG_PATH="$config_path" \
   ARDUINO_CLI="$fake_cli" FAKE_ARDUINO_LOG="$fake_log" \
   FAKE_IMAGE_SIZE=1310721 \
   "$repo_root/scripts/ota-upload.sh" >"$output" 2>&1; then
  echo 'oversized image unexpectedly uploaded' >&2
  exit 1
fi
grep -Fx 'CALL:compile' "$fake_log"
! grep -Fx 'CALL:upload' "$fake_log"
! grep -F password12 "$output"

# The documented OTA slot limit itself must still be accepted: 1,310,720 bytes
# is the largest image that fits, not the first one that is rejected.
rm -f "$fake_log"
printf '\npassword12\n' |
  SESAME_OTA_CONFIG_PATH="$config_path" \
  ARDUINO_CLI="$fake_cli" FAKE_ARDUINO_LOG="$fake_log" \
  FAKE_IMAGE_SIZE=1310720 \
  "$repo_root/scripts/ota-upload.sh" >"$output" 2>&1
grep -Fx 'CALL:compile' "$fake_log"
grep -Fx 'CALL:upload' "$fake_log"
! grep -F password12 "$output"

printf '%s\n' 'OTA script tests passed.'
