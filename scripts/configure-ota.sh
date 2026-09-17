#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_path=${SESAME_OTA_CONFIG_PATH:-"$repo_root/firmware/sesame-s3-pca9685/ota-local-config.h"}
temp_config=
ap_ssid=
ap_password=
ap_password_confirmation=
ota_password=
ota_password_confirmation=
ota_password_hash=
escaped_ap_ssid=
escaped_ap_password=

cleanup() {
  unset ap_ssid ap_password ap_password_confirmation ota_password \
    ota_password_confirmation ota_password_hash escaped_ap_ssid \
    escaped_ap_password
  if test -n "$temp_config"; then
    rm -f "$temp_config"
  fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

printf 'Device hostname: '
IFS= read -r hostname ||
  fail 'No hostname entered (input ended); local configuration was not changed.'
case "$hostname" in
  ''|*[!a-z0-9-]*|-*|*-) fail 'Hostname must use 1-32 lowercase letters, digits, or internal hyphens.' ;;
esac
test "${#hostname}" -le 32 ||
  fail 'Hostname must use 1-32 lowercase letters, digits, or internal hyphens.'

printf 'Robot AP SSID: '
IFS= read -r ap_ssid ||
  fail 'No AP SSID entered (input ended); local configuration was not changed.'
ap_ssid_bytes=$(printf '%s' "$ap_ssid" | wc -c | tr -d '[:space:]')
test "$ap_ssid_bytes" -ge 1 && test "$ap_ssid_bytes" -le 32 ||
  fail 'Robot AP SSID must be 1-32 bytes.'
printf '%s\n' "$ap_ssid" | LC_ALL=C grep -Eq '^[ -~]+$' ||
  fail 'Robot AP SSID must contain printable ASCII characters only.'

printf 'Robot AP password: '
IFS= read -r -s ap_password ||
  fail 'No AP password entered (input ended); local configuration was not changed.'
printf '\n'
printf 'Confirm robot AP password: '
IFS= read -r -s ap_password_confirmation ||
  fail 'No AP password confirmation entered (input ended); local configuration was not changed.'
printf '\n'
ap_password_bytes=$(printf '%s' "$ap_password" | wc -c | tr -d '[:space:]')
test "$ap_password_bytes" -ge 8 && test "$ap_password_bytes" -le 63 ||
  fail 'Robot AP password must be 8-63 bytes.'
printf '%s\n' "$ap_password" | LC_ALL=C grep -Eq '^[ -~]+$' ||
  fail 'Robot AP password must contain printable ASCII characters only.'
test "$ap_password" = "$ap_password_confirmation" ||
  fail 'Robot AP passwords do not match.'

printf 'OTA password: '
IFS= read -r -s ota_password ||
  fail 'No OTA password entered (input ended); local configuration was not changed.'
printf '\n'
printf 'Confirm OTA password: '
IFS= read -r -s ota_password_confirmation ||
  fail 'No OTA password confirmation entered (input ended); local configuration was not changed.'
printf '\n'

test "$(printf '%s' "$ota_password" | wc -c | tr -d '[:space:]')" -ge 8 ||
  fail 'OTA password must be at least 8 bytes.'
test "$ota_password" = "$ota_password_confirmation" ||
  fail 'OTA passwords do not match.'

if command -v shasum >/dev/null 2>&1; then
  ota_password_hash=$(printf '%s' "$ota_password" | shasum -a 256 | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  ota_password_hash=$(printf '%s' "$ota_password" | sha256sum | awk '{print $1}')
else
  fail 'Neither shasum nor sha256sum is available; local OTA config was not changed.'
fi

escaped_ap_ssid=${ap_ssid//\\/\\\\}
escaped_ap_ssid=${escaped_ap_ssid//\"/\\\"}
escaped_ap_password=${ap_password//\\/\\\\}
escaped_ap_password=${escaped_ap_password//\"/\\\"}

umask 077
temp_config=$(mktemp "${config_path}.tmp.XXXXXX")
cat >"$temp_config" <<EOF
#ifndef SESAME_OTA_LOCAL_CONFIG_H
#define SESAME_OTA_LOCAL_CONFIG_H
#define SESAME_DEVICE_HOSTNAME "$hostname"
#define SESAME_AP_SSID "$escaped_ap_ssid"
#define SESAME_AP_PASSWORD "$escaped_ap_password"
#define SESAME_OTA_PASSWORD_HASH "$ota_password_hash"
#endif
EOF
chmod 600 "$temp_config"
mv -f "$temp_config" "$config_path"
temp_config=
unset ap_ssid ap_password ap_password_confirmation ota_password \
  ota_password_confirmation ota_password_hash escaped_ap_ssid \
  escaped_ap_password
printf 'Local robot configuration written to %s\n' "$config_path"
