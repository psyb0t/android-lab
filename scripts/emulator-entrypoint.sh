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

LOG_FILE="${LOG_FILE:-/tmp/android-lab-emulator.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

KEY_DIR=/android-lab/adb
HOME=/data/android-lab-home
AVD_DIRECTORY="$HOME/.android/avd/android-lab.avd"
AVD_HARDWARE_LOCK_FILE="$AVD_DIRECTORY/hardware-qemu.ini.lock"
AVD_MULTIINSTANCE_LOCK_FILE="$AVD_DIRECTORY/multiinstance.lock"
EMULATOR_CONSOLE_AUTH_TOKEN_FILE="$HOME/.emulator_console_auth_token"
EMULATOR_CONSOLE_AUTH_TOKEN_OUTPUT_FILE=/android-lab/emulator-control/auth-token
EMULATOR_CONSOLE_BOOTSTRAP_HOST=127.0.0.1
EMULATOR_CONSOLE_BOOTSTRAP_PORT=5554
EMULATOR_CONSOLE_BOOTSTRAP_TIMEOUT_SECONDS=5
EMULATOR_CONSOLE_AUTH_TOKEN_READY_ATTEMPTS=30
EMULATOR_CONSOLE_AUTH_TOKEN_RETRY_SECONDS=1
X_DISPLAY=:99
X_DISPLAY_SOCKET=/tmp/.X11-unix/X99
X_DISPLAY_SCREEN=1120x2460x24
X_DISPLAY_READY_ATTEMPTS=20
VNC_BIND_ADDRESS=0.0.0.0
VNC_PORT=5900
EMULATOR_WINDOW_NAME_PATTERN='^Android Emulator - android-lab:5554$'
EMULATOR_WINDOW_READY_ATTEMPTS=60
EMULATOR_WINDOW_RETRY_SECONDS=1
EMULATOR_WINDOW_X=18
EMULATOR_WINDOW_Y=18
EMULATOR_PID=""
DISPLAY="$X_DISPLAY"
export HOME
export DISPLAY

stop_emulator() {
	trap - INT TERM
	log INFO "stopping isolated Android emulator"
	terminate_emulator
	exit 0
}

terminate_emulator() {
	# It may have stopped itself before Compose delivers the container signal.
	if [[ -z "$EMULATOR_PID" ]] || ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
		return 0
	fi
	if ! kill "$EMULATOR_PID"; then
		log WARN "could not signal isolated Android emulator pid=${EMULATOR_PID}"
	fi
	if ! wait "$EMULATOR_PID"; then
		: # Intentional: the emulator exits nonzero after receiving the requested termination signal.
	fi
}

remove_stale_avd_locks() {
	local lock_path
	local -a lock_paths=(
		"$AVD_HARDWARE_LOCK_FILE"
		"$AVD_MULTIINSTANCE_LOCK_FILE"
	)
	for lock_path in "${lock_paths[@]}"; do
		[[ -e "$lock_path" ]] || continue
		if ! rm -- "$lock_path"; then
			log ERROR "could not remove stale Android AVD lock path=${lock_path}"
			exit 1
		fi
		log WARN "removed stale Android AVD lock path=${lock_path}"
	done
}

position_emulator_window() {
	local attempt emulator_window_id
	local -a emulator_window_ids=()
	for ((attempt = 1; attempt <= EMULATOR_WINDOW_READY_ATTEMPTS; attempt++)); do
		emulator_window_ids=()
		# Intentional: no matching Qt window is normal while the emulator starts.
		mapfile -t emulator_window_ids < <(xdotool search --name "$EMULATOR_WINDOW_NAME_PATTERN" 2>/dev/null || :)
		if ((${#emulator_window_ids[@]} != 1)); then
			sleep "$EMULATOR_WINDOW_RETRY_SECONDS"
			continue
		fi
		emulator_window_id="${emulator_window_ids[0]}"
		if ! xdotool windowmap "$emulator_window_id"; then
			log WARN "could not restore Android emulator window attempt=${attempt}"
			sleep "$EMULATOR_WINDOW_RETRY_SECONDS"
			continue
		fi
		if ! xdotool windowmove "$emulator_window_id" "$EMULATOR_WINDOW_X" "$EMULATOR_WINDOW_Y"; then
			log WARN "could not position Android emulator window attempt=${attempt}"
			sleep "$EMULATOR_WINDOW_RETRY_SECONDS"
			continue
		fi
		if ! xdotool windowactivate --sync "$emulator_window_id"; then
			log WARN "could not focus Android emulator window attempt=${attempt}"
			sleep "$EMULATOR_WINDOW_RETRY_SECONDS"
			continue
		fi
		log INFO "positioned and focused Android emulator window"
		return 0
	done
	log ERROR "Android emulator window did not appear"
	return 1
}

publish_emulator_console_auth_token() {
	local attempt
	for ((attempt = 1; attempt <= EMULATOR_CONSOLE_AUTH_TOKEN_READY_ATTEMPTS; attempt++)); do
		if [[ -s "$EMULATOR_CONSOLE_AUTH_TOKEN_FILE" ]]; then
			install --mode=0600 "$EMULATOR_CONSOLE_AUTH_TOKEN_FILE" "$EMULATOR_CONSOLE_AUTH_TOKEN_OUTPUT_FILE" || {
				log ERROR "could not publish the isolated emulator console credential"
				return 1
			}
			log INFO "published the isolated emulator console credential"
			return 0
		fi
		if ! printf 'quit\n' | timeout "$EMULATOR_CONSOLE_BOOTSTRAP_TIMEOUT_SECONDS" \
			socat -T "$EMULATOR_CONSOLE_BOOTSTRAP_TIMEOUT_SECONDS" - \
			"TCP:${EMULATOR_CONSOLE_BOOTSTRAP_HOST}:${EMULATOR_CONSOLE_BOOTSTRAP_PORT}" >/dev/null; then
			log DEBUG "waiting for the isolated emulator console credential attempt=${attempt}"
		fi
		sleep "$EMULATOR_CONSOLE_AUTH_TOKEN_RETRY_SECONDS"
	done
	log ERROR "isolated emulator console credential did not appear"
	return 1
}

trap stop_emulator INT TERM

[[ -c /dev/kvm ]] || {
	log ERROR "/dev/kvm is required by the Android emulator"
	exit 1
}
[[ -s "$KEY_DIR/adbkey" && -s "$KEY_DIR/adbkey.pub" ]] || {
	log ERROR "dedicated Android lab ADB key is missing"
	exit 1
}

mkdir --parents "$HOME/.android/avd"
cp --preserve=mode "$KEY_DIR/adbkey" "$HOME/.android/adbkey"
cp --preserve=mode "$KEY_DIR/adbkey.pub" "$HOME/.android/adbkey.pub"
cp --recursive --preserve=mode /opt/android-home/.android/avd/. "$HOME/.android/avd/"
chmod 0600 "$HOME/.android/adbkey"
remove_stale_avd_locks

log INFO "starting private X display for web VNC"
Xvfb "$X_DISPLAY" -screen 0 "$X_DISPLAY_SCREEN" -nolisten tcp &
for ((attempt = 1; attempt <= X_DISPLAY_READY_ATTEMPTS; attempt++)); do
	[[ -S "$X_DISPLAY_SOCKET" ]] && break
	sleep 1
done
[[ -S "$X_DISPLAY_SOCKET" ]] || {
	log ERROR "private X display did not start"
	exit 1
}
log INFO "starting private Openbox window manager"
openbox --sm-disable &
x11vnc \
	-display "$X_DISPLAY" \
	-forever \
	-listen "$VNC_BIND_ADDRESS" \
	-nopw \
	-rfbport "$VNC_PORT" \
	-shared &

log INFO "starting isolated Android emulator with private X display"
emulator \
	-avd android-lab \
	-no-audio \
	-no-boot-anim \
	-no-metrics \
	-no-snapshot \
	-wipe-data \
	-data /data/userdata-qemu.img \
	-gpu swiftshader_indirect \
	-fixed-scale \
	-use-keycode-forwarding \
	-ports 5554,5555 \
	-grpc 8554 &
EMULATOR_PID=$!

if ! position_emulator_window; then
	terminate_emulator
	exit 1
fi
if ! publish_emulator_console_auth_token; then
	terminate_emulator
	exit 1
fi

wait "$EMULATOR_PID" || {
	emulator_exit_code=$?
	log ERROR "isolated Android emulator exited unexpectedly exit=${emulator_exit_code}"
	exit "$emulator_exit_code"
}
