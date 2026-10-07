#!/bin/bash

set -euo pipefail

log() {
	local level="$1"
	shift
	jq -cn \
		--arg time "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" \
		--arg level "$level" \
		--arg file "${BASH_SOURCE[1]##*/}" \
		--argjson line "${BASH_LINENO[0]}" \
		--arg func "${FUNCNAME[1]:-main}" \
		--arg msg "$*" \
		'{time: $time, level: $level, file: $file, line: $line, func: $func, msg: $msg}' >&2
}

on_error() {
	local exit_code=$?
	trap - ERR
	log ERROR "command failed exit=${exit_code}"
	exit "$exit_code"
}

trap on_error ERR

LOG_FILE="${LOG_FILE:-/tmp/android-lab-keygen.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

KEY_DIR=/android-lab/adb
ANDROID_LAB_UID="${ANDROID_LAB_UID:?ANDROID_LAB_UID is required}"
ANDROID_LAB_GID="${ANDROID_LAB_GID:?ANDROID_LAB_GID is required}"

[[ "$ANDROID_LAB_UID" =~ ^[0-9]+$ && "$ANDROID_LAB_GID" =~ ^[0-9]+$ ]] || {
	log ERROR "Android lab UID and GID must be numeric"
	exit 1
}

mkdir --parents "$KEY_DIR"
if [[ ! -s "$KEY_DIR/adbkey" || ! -s "$KEY_DIR/adbkey.pub" ]]; then
	log INFO "creating dedicated Android lab ADB key"
	rm -f "$KEY_DIR/adbkey" "$KEY_DIR/adbkey.pub"
	adb keygen "$KEY_DIR/adbkey" || {
		log ERROR "could not create dedicated ADB key"
		exit 1
	}
else
	log DEBUG "using existing dedicated Android lab ADB key"
fi

chmod 0600 "$KEY_DIR/adbkey"
chmod 0644 "$KEY_DIR/adbkey.pub"
log INFO "Android lab ADB key is ready"
