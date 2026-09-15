#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_path=${SESAME_OTA_CONFIG_PATH:-"$repo_root/firmware/sesame-s3-pca9685/ota-local-config.h"}
ARDUINO_CLI=${ARDUINO_CLI:-arduino-cli}
password=
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/sesame-ota-build.XXXXXX")

cleanup() {
  unset password
  rm -rf "$build_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

test -f "$config_path" ||
  fail "Local OTA configuration not found: $config_path"

configured_hostname=$(awk '
  $1 == "#define" && $2 == "SESAME_DEVICE_HOSTNAME" &&
  $3 ~ /^"[^"]*"$/ && NF == 3 {
    value = $3
    sub(/^"/, "", value)
    sub(/"$/, "", value)
    print value
  }
' "$config_path")
case "$configured_hostname" in
  ''|*[!a-z0-9-]*|-*|*-) fail 'Local OTA configuration has an invalid hostname.' ;;
esac
test "${#configured_hostname}" -le 32 ||
  fail 'Local OTA configuration has an invalid hostname.'

printf 'Current hostname/IP [%s]: ' "$configured_hostname"
IFS= read -r target
if test -z "$target"; then
  target=$configured_hostname
fi
case "$target" in
  *.*|*:*) ;;
  *) target="${target}.local" ;;
esac

printf 'OTA password: '
IFS= read -r -s password
printf '\n'

"$ARDUINO_CLI" compile --clean \
  --build-path "$build_dir" \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  "$repo_root/firmware/sesame-s3-pca9685"

firmware_bins=("$build_dir"/*.ino.bin)
test "${#firmware_bins[@]}" -eq 1 && test -f "${firmware_bins[0]}" ||
  fail 'Expected exactly one compiled .ino.bin image.'
firmware_bin=${firmware_bins[0]}
firmware_size=$(wc -c <"$firmware_bin" | tr -d '[:space:]')
test "$firmware_size" -le 1310720 ||
  fail "Firmware image is too large for the OTA slot ($firmware_size bytes)."

"$ARDUINO_CLI" upload \
  --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
  --port "$target" \
  --protocol network \
  --input-file "$firmware_bin" \
  --upload-property upload.port.properties.port=3232 \
  --upload-field "password=$password"
