#!/bin/bash

set -euo pipefail

readonly DEFAULT_FORWARD_PORT=19001
readonly ADB_FORWARD_PORT=29001
readonly DEFAULT_MCP_PORT=19002
readonly ADB_MCP_PORT=29002
readonly EXPECTED_SERIAL=emulator:5556
readonly KEY_DIR=/android-lab/adb

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

LOG_FILE="${LOG_FILE:-/tmp/android-lab-forward.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

SERIAL="${ANDROID_LAB_SERIAL:-$EXPECTED_SERIAL}"
HOST_PORT="${ANDROID_LAB_FORWARD_HOST_PORT:-$DEFAULT_FORWARD_PORT}"
DEVICE_PORT="${ANDROID_LAB_FORWARD_DEVICE_PORT:-$DEFAULT_FORWARD_PORT}"
MCP_HOST_PORT="${ANDROID_LAB_MCP_HOST_PORT:-$DEFAULT_MCP_PORT}"
MCP_DEVICE_PORT="${ANDROID_LAB_MCP_DEVICE_PORT:-$DEFAULT_MCP_PORT}"
SOCAT_PIDS=()

validate_tcp_port() {
	local name="$1"
	local value="$2"
	if [[ "$value" =~ ^[1-9][0-9]{0,4}$ ]] && ((10#$value <= 65535)); then
		return 0
	fi
	log ERROR "${name} must be an integer from 1 through 65535"
	exit 1
}

cleanup_adb() {
	local pid
	for pid in "${SOCAT_PIDS[@]}"; do
		if kill -0 "$pid" >/dev/null 2>&1; then
			kill "$pid" || : # The forwarding script owns this child process.
			wait "$pid" || : # It may have already stopped after an ADB disconnect.
		fi
	done
	adb -s "$SERIAL" forward --remove "tcp:$ADB_FORWARD_PORT" >/dev/null 2>&1 || : # A missing rule is normal during startup failure.
	adb -s "$SERIAL" forward --remove "tcp:$ADB_MCP_PORT" >/dev/null 2>&1 || :     # A missing rule is normal during startup failure.
	adb kill-server >/dev/null 2>&1 || :                                           # The private controller owns this disposable ADB server.
}

trap cleanup_adb EXIT

[[ "$SERIAL" == "$EXPECTED_SERIAL" ]] || {
	log ERROR "refusing a device other than ${EXPECTED_SERIAL}"
	exit 1
}
validate_tcp_port ANDROID_LAB_FORWARD_HOST_PORT "$HOST_PORT"
validate_tcp_port ANDROID_LAB_FORWARD_DEVICE_PORT "$DEVICE_PORT"
validate_tcp_port ANDROID_LAB_MCP_HOST_PORT "$MCP_HOST_PORT"
validate_tcp_port ANDROID_LAB_MCP_DEVICE_PORT "$MCP_DEVICE_PORT"
[[ "$HOST_PORT" != "$MCP_HOST_PORT" ]] || {
	log ERROR "Android automation and MCP host ports must differ"
	exit 1
}

setup_adb() {
	local deadline seconds_left status
	export HOME=/tmp/android-lab-home
	mkdir --parents "$HOME/.android"
	[[ -s "$KEY_DIR/adbkey" && -s "$KEY_DIR/adbkey.pub" ]] || {
		log ERROR "dedicated Android lab ADB key is missing"
		exit 1
	}
	cp --preserve=mode "$KEY_DIR/adbkey" "$HOME/.android/adbkey"
	cp --preserve=mode "$KEY_DIR/adbkey.pub" "$HOME/.android/adbkey.pub"
	chmod 0600 "$HOME/.android/adbkey"

	adb start-server >/dev/null
	deadline=$((SECONDS + 240))
	while ((SECONDS < deadline)); do
		timeout 5 adb connect "$SERIAL" >/dev/null 2>&1 || : # The bridge is allowed to be briefly unavailable while booting.
		status="$(timeout 5 adb -s "$SERIAL" get-state 2>/dev/null || :)"
		if [[ "$status" == device ]]; then
			break
		fi
		sleep 2
	done
	seconds_left=$((deadline - SECONDS))
	((seconds_left > 0)) || {
		log ERROR "Android emulator did not become reachable"
		exit 1
	}
}

setup_adb
forward_device_port() {
	local adb_port="$1"
	local device_port="$2"
	local host_port="$3"
	adb -s "$SERIAL" forward --remove "tcp:$adb_port" >/dev/null 2>&1 || : # No existing mapping is the expected first-run state.
	adb -s "$SERIAL" forward "tcp:$adb_port" "tcp:$device_port" || {
		log ERROR "could not create an Android loopback forward"
		exit 1
	}
	socat "TCP-LISTEN:${host_port},reuseaddr,fork" "TCP:127.0.0.1:${adb_port}" &
	SOCAT_PIDS+=("$!")
	sleep 1
	if ! kill -0 "${SOCAT_PIDS[-1]}" >/dev/null 2>&1; then
		log ERROR "could not expose an Android loopback forward to Docker"
		exit 1
	fi
}

forward_device_port "$ADB_FORWARD_PORT" "$DEVICE_PORT" "$HOST_PORT"
forward_device_port "$ADB_MCP_PORT" "$MCP_DEVICE_PORT" "$MCP_HOST_PORT"
if [[ "${DEBUG:-}" == 1 ]]; then
	log DEBUG "Android loopback forwarding is active"
fi
log INFO "forwarding device-local automation and MCP ports only to host loopback"

while :; do
	status="$(timeout 5 adb -s "$SERIAL" get-state 2>/dev/null || :)"
	[[ "$status" == device ]] || {
		log WARN "Android emulator disconnected from loopback forward"
		exit 1
	}
	sleep 5
done
