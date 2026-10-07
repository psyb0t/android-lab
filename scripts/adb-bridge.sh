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

ADB_BRIDGE_PORT=5556
EMULATOR_ADB_PORT=5555
EMULATOR_CONSOLE_PORT=5554
CONSOLE_BRIDGE_PID=""

emulator_ip="$(getent hosts emulator | awk 'NR == 1 {print $1}')"
[[ "$emulator_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || {
	log ERROR "could not resolve the private emulator address"
	exit 1
}

cleanup_console_bridge() {
	if [[ -n "$CONSOLE_BRIDGE_PID" ]] && kill -0 "$CONSOLE_BRIDGE_PID" 2>/dev/null; then
		kill "$CONSOLE_BRIDGE_PID" || log WARN "could not stop the private emulator console bridge"
	fi
}

forward_private_listener() {
	local listener_name="$1"
	local listener_port="$2"
	local target_port="$3"
	while :; do
		socat "TCP-LISTEN:${listener_port},reuseaddr,fork,bind=${emulator_ip}" "TCP:127.0.0.1:${target_port}" ||
			log WARN "${listener_name} is not ready"
		sleep 1
	done
}

trap cleanup_console_bridge EXIT

log INFO "forwarding the private emulator console listener"
forward_private_listener "emulator console listener" "$EMULATOR_CONSOLE_PORT" "$EMULATOR_CONSOLE_PORT" &
CONSOLE_BRIDGE_PID=$!

log INFO "forwarding the private emulator ADB listener"
while :; do
	socat "TCP-LISTEN:${ADB_BRIDGE_PORT},reuseaddr,fork,bind=${emulator_ip}" "TCP:127.0.0.1:${EMULATOR_ADB_PORT}" ||
		log WARN "emulator ADB listener is not ready"
	sleep 1
done
