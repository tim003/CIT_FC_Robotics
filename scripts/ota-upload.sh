#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_path=${SESAME_OTA_CONFIG_PATH:-"$repo_root/firmware/sesame-s3-pca9685/ota-local-config.h"}
ARDUINO_CLI=${ARDUINO_CLI:-arduino-cli}
password=
# Created only after the local configuration has been validated, so a missing
# config cannot leave a temporary directory behind (or fail before reporting
# the real problem). cleanup() therefore has to tolerate an unset build_dir.
build_dir=

cleanup() {
  unset password
  if test -n "$build_dir"; then
    rm -rf "$build_dir"
  fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

is_ipv4_literal() {
  printf '%s\n' "$1" | awk -F. '
    BEGIN { valid = 1 }
    NF != 4 { valid = 0 }
    {
      for (i = 1; i <= 4; i++) {
        if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) valid = 0
      }
    }
    END { if (NR != 1 || !valid) exit 1 }
  '
}

resolve_ipv4() {
  local hostname=$1
  if test -n "${SESAME_OTA_RESOLVER:-}"; then
    "$SESAME_OTA_RESOLVER" "$hostname"
  elif command -v dscacheutil >/dev/null 2>&1; then
    dscacheutil -q host -a name "$hostname" | awk '
      $1 == "ip_address:" && $2 !~ /:/ { print $2; exit }
    '
  elif command -v getent >/dev/null 2>&1; then
    getent ahostsv4 "$hostname" | awk 'NR == 1 { print $1; exit }'
  else
    return 1
  fi
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
IFS= read -r target ||
  fail 'No hostname or IP entered (input ended); nothing was uploaded.'
if test -z "$target"; then
  target=$configured_hostname
fi
case "$target" in
  *:*) upload_target=$target ;;
  *)
    if is_ipv4_literal "$target"; then
      upload_target=$target
    else
      case "$target" in
        *.*) ;;
        *) target="${target}.local" ;;
      esac
      upload_target=$(resolve_ipv4 "$target") ||
        fail "Could not resolve OTA target to an IPv4 address: $target"
      is_ipv4_literal "$upload_target" ||
        fail "OTA target did not resolve to one valid IPv4 address: $target"
      printf 'Resolved %s to %s for Arduino CLI.\n' "$target" "$upload_target"
    fi
    ;;
esac

printf 'OTA password: '
IFS= read -r -s password ||
  fail 'No OTA password entered (input ended); nothing was uploaded.'
printf '\n'

build_dir=$(mktemp -d "${TMPDIR:-/tmp}/sesame-ota-build.XXXXXX") ||
  fail "Could not create a temporary build directory under ${TMPDIR:-/tmp}."

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
  --port "$upload_target" \
  --protocol network \
  --input-file "$firmware_bin" \
  --upload-property upload.port.properties.port=3232 \
  --upload-field "password=$password"
