#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config_path=${SESAME_OTA_CONFIG_PATH:-"$repo_root/firmware/sesame-s3-pca9685/ota-local-config.h"}
temp_config=
password=
password_confirmation=
password_hash=

cleanup() {
  unset password password_confirmation password_hash
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
IFS= read -r hostname
case "$hostname" in
  ''|*[!a-z0-9-]*|-*|*-) fail 'Hostname must use 1-32 lowercase letters, digits, or internal hyphens.' ;;
esac
test "${#hostname}" -le 32 ||
  fail 'Hostname must use 1-32 lowercase letters, digits, or internal hyphens.'

printf 'OTA password: '
IFS= read -r -s password
printf '\n'
printf 'Confirm OTA password: '
IFS= read -r -s password_confirmation
printf '\n'

test "$(printf '%s' "$password" | wc -c | tr -d '[:space:]')" -ge 8 ||
  fail 'OTA password must be at least 8 bytes.'
test "$password" = "$password_confirmation" ||
  fail 'OTA passwords do not match.'

if command -v shasum >/dev/null 2>&1; then
  password_hash=$(printf '%s' "$password" | shasum -a 256 | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  password_hash=$(printf '%s' "$password" | sha256sum | awk '{print $1}')
else
  fail 'Neither shasum nor sha256sum is available; local OTA config was not changed.'
fi

umask 077
temp_config=$(mktemp "${config_path}.tmp.XXXXXX")
cat >"$temp_config" <<EOF
#ifndef SESAME_OTA_LOCAL_CONFIG_H
#define SESAME_OTA_LOCAL_CONFIG_H
#define SESAME_DEVICE_HOSTNAME "$hostname"
#define SESAME_OTA_PASSWORD_HASH "$password_hash"
#endif
EOF
chmod 600 "$temp_config"
mv -f "$temp_config" "$config_path"
temp_config=
unset password password_confirmation password_hash
printf 'Local OTA configuration written to %s\n' "$config_path"
