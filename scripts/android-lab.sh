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

LOG_FILE="${LOG_FILE:-/tmp/android-lab.log}"
exec 3>&1
exec > >(tee -a "$LOG_FILE" >&3) 2> >(tee -a "$LOG_FILE" >&2)

TOOL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOSITORY_DIR="$(realpath "${ANDROID_LAB_WORKSPACE:-$PWD}")"
export ANDROID_LAB_HOST_WORKSPACE="$REPOSITORY_DIR"
COMMAND="${1:-}"
DEFAULT_FORWARD_PORT=19001
DEFAULT_MCP_FORWARD_PORT=19002
WEB_VNC_PORT=61325
SHARED_VNC_PORT=61326
VNC_SERVER_PORT=5900
VNC_READY_TIMEOUT_SECONDS=60
EMULATOR_WINDOW_NAME_PATTERN='^Android Emulator - android-lab:5554$'
EMULATOR_VIEWPORT_WIDTH=1080
EMULATOR_VIEWPORT_HEIGHT=2400
KVM_PROBE_CPU_LIMIT=0.25
KVM_PROBE_MEMORY_LIMIT=128m
KVM_PROBE_PIDS_LIMIT=32

[[ -n "$COMMAND" ]] || {
	log ERROR "Android lab command is required"
	exit 1
}

configure_instance() {
	[[ "${ANDROID_LAB_INSTANCE:-shared}" == shared ]] || {
		log ERROR "ANDROID_LAB_INSTANCE must be shared. This lab has one emulator."
		exit 1
	}
	ANDROID_LAB_INSTANCE=shared
	LAB_STATE_DIRECTORY="$REPOSITORY_DIR/.android-lab/shared"
	COMPOSE_PROJECT_NAME="${ANDROID_LAB_COMPOSE_PROJECT:-android-lab-$(printf '%s' "$REPOSITORY_DIR" | sha256sum | cut -c1-12)}"
	[[ "$COMPOSE_PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || {
		log ERROR "invalid Compose project name"
		exit 1
	}
	ARTIFACT_DIR="$LAB_STATE_DIRECTORY/artifacts"
	ADB_KEY_DIR="$LAB_STATE_DIRECTORY/adb"
	EMULATOR_CONTROL_DIRECTORY="$LAB_STATE_DIRECTORY/emulator-control"
	EMULATOR_DATA_DIR="$LAB_STATE_DIRECTORY/emulator-data"
	ADB_BRIDGE_EMULATOR_GENERATION_FILE="$EMULATOR_CONTROL_DIRECTORY/adb-bridge-emulator-generation"
	export ANDROID_LAB_INSTANCE LAB_STATE_DIRECTORY COMPOSE_PROJECT_NAME
	export ANDROID_LAB_STATE_DIRECTORY="$LAB_STATE_DIRECTORY"
	export ANDROID_LAB_EMULATOR_CONTROL_DIRECTORY="$EMULATOR_CONTROL_DIRECTORY"
}

configure_instance

clean() {
	local lab_directory="$LAB_STATE_DIRECTORY"
	[[ -d "$lab_directory" ]] || {
		log INFO "no Android lab artifacts to clean"
		return 0
	}
	[[ "$lab_directory" == "$REPOSITORY_DIR/.android-lab/shared" ]] || {
		log ERROR "refusing unexpected cleanup directory"
		exit 1
	}
	find "$lab_directory" -mindepth 1 -maxdepth 1 -type f -delete
	find "$lab_directory" -mindepth 1 -type d -empty -delete
	log INFO "removed ignored Android lab files without touching Docker resources"
}

if [[ "$COMMAND" == "clean" ]]; then
	clean
	exit 0
fi

ANDROID_LAB_DEV_IMAGE="${ANDROID_LAB_DEV_IMAGE:?ANDROID_LAB_DEV_IMAGE is required}"
ANDROID_LAB_EMULATOR_IMAGE="${ANDROID_LAB_EMULATOR_IMAGE:?ANDROID_LAB_EMULATOR_IMAGE is required}"
ANDROID_LAB_UID="${ANDROID_LAB_UID:?ANDROID_LAB_UID is required}"
ANDROID_LAB_GID="${ANDROID_LAB_GID:?ANDROID_LAB_GID is required}"

[[ "$ANDROID_LAB_UID" =~ ^[0-9]+$ && "$ANDROID_LAB_GID" =~ ^[0-9]+$ ]] || {
	log ERROR "Android lab UID and GID must be numeric"
	exit 1
}

export ANDROID_LAB_DEV_IMAGE ANDROID_LAB_EMULATOR_IMAGE ANDROID_LAB_UID ANDROID_LAB_GID

compose() {
	docker compose --project-name "$COMPOSE_PROJECT_NAME" --file "$TOOL_ROOT/docker-compose.yml" "$@"
}

ensure_lab_directories() {
	mkdir --parents "$ARTIFACT_DIR" "$ADB_KEY_DIR" "$EMULATOR_CONTROL_DIRECTORY" "$EMULATOR_DATA_DIR"
	chmod 0700 "$ADB_KEY_DIR"
	chmod 0700 "$EMULATOR_CONTROL_DIRECTORY"
}

ensure_image() {
	docker image inspect "$ANDROID_LAB_EMULATOR_IMAGE" >/dev/null 2>&1 || {
		log ERROR "emulator image is absent. Run make image first"
		exit 1
	}
}

validate_tcp_port() {
	local name="$1"
	local value="$2"
	if [[ "$value" =~ ^[1-9][0-9]{0,4}$ ]] && ((10#$value <= 65535)); then
		return 0
	fi
	log ERROR "${name} must be an integer from 1 through 65535"
	exit 1
}

detect_kvm_gid() {
	local probe_name
	probe_name="android-lab-kvm-gid-${RANDOM}-${RANDOM}"
	ANDROID_LAB_KVM_GID="$(docker run --rm --init --name "$probe_name" \
		--network none \
		--read-only \
		--tmpfs /tmp:rw,noexec,nosuid,size=8m \
		--cpus "$KVM_PROBE_CPU_LIMIT" \
		--memory "$KVM_PROBE_MEMORY_LIMIT" \
		--memory-swap "$KVM_PROBE_MEMORY_LIMIT" \
		--pids-limit "$KVM_PROBE_PIDS_LIMIT" \
		--cap-drop ALL \
		--security-opt no-new-privileges:true \
		--device /dev/kvm \
		"$ANDROID_LAB_DEV_IMAGE" \
		stat -c '%g' /dev/kvm)" || {
		log ERROR "could not determine the Docker host KVM group"
		exit 1
	}
	[[ "$ANDROID_LAB_KVM_GID" =~ ^[0-9]+$ ]] || {
		log ERROR "Docker host KVM group is invalid"
		exit 1
	}
	export ANDROID_LAB_KVM_GID
}

emulator_generation() {
	local emulator_container_id emulator_started_at
	emulator_container_id="$(compose ps --quiet emulator)"
	[[ -n "$emulator_container_id" ]] || {
		log ERROR "could not identify the shared Android emulator container"
		return 1
	}
	emulator_started_at="$(docker inspect --format '{{.State.StartedAt}}' "$emulator_container_id")" || {
		log ERROR "could not inspect the shared Android emulator start time"
		return 1
	}
	[[ -n "$emulator_started_at" ]] || {
		log ERROR "shared Android emulator has no start time"
		return 1
	}
	printf '%s:%s\n' "$emulator_container_id" "$emulator_started_at"
}

ensure_current_adb_bridge() {
	local current_generation previous_generation
	current_generation="$(emulator_generation)" || return 1
	previous_generation=""
	if [[ -f "$ADB_BRIDGE_EMULATOR_GENERATION_FILE" ]]; then
		previous_generation="$(<"$ADB_BRIDGE_EMULATOR_GENERATION_FILE")"
	fi
	if [[ "$previous_generation" == "$current_generation" ]]; then
		compose up --detach --no-deps adb-bridge || {
			log ERROR "could not start the private Android ADB bridge"
			return 1
		}
		return 0
	fi
	log INFO "recreating the private Android ADB bridge for the current emulator generation"
	compose up --detach --no-deps --force-recreate adb-bridge || {
		log ERROR "could not recreate the private Android ADB bridge"
		return 1
	}
	printf '%s\n' "$current_generation" >"$ADB_BRIDGE_EMULATOR_GENERATION_FILE" || {
		log ERROR "could not record the private Android emulator generation"
		return 1
	}
}

start() {
	local default_vnc_port host_port
	local -a services=(emulator web-vnc)
	default_vnc_port="$SHARED_VNC_PORT"
	host_port="${ANDROID_LAB_VNC_HOST_PORT:-$default_vnc_port}"
	validate_tcp_port ANDROID_LAB_VNC_HOST_PORT "$host_port"
	ensure_lab_directories
	ensure_image
	detect_kvm_gid
	log INFO "starting the shared Android lab emulator"
	compose up --detach "${services[@]}" || {
		log ERROR "Android emulator failed to start. Confirm the Docker host exposes /dev/kvm"
		exit 1
	}
	ensure_current_adb_bridge || exit 1
	compose run --rm --no-deps lab bash /opt/android-lab/scripts/lab-device.sh wait || {
		compose logs --no-color emulator || log WARN "could not read Android emulator logs"
		log ERROR "Android emulator failed readiness checks"
		exit 1
	}
	run_device_operation configure-navigation
	wait_for_web_vnc "$host_port" || exit 1
	verify_emulator_window || exit 1
}

stop() {
	detect_kvm_gid
	log INFO "stopping named Android lab services"
	compose down || {
		log ERROR "could not stop Android lab services"
		exit 1
	}
}

forward() {
	local host_port device_port mcp_host_port mcp_device_port
	host_port="${ANDROID_LAB_FORWARD_HOST_PORT:-$DEFAULT_FORWARD_PORT}"
	device_port="${ANDROID_LAB_FORWARD_DEVICE_PORT:-$DEFAULT_FORWARD_PORT}"
	mcp_host_port="${ANDROID_LAB_MCP_HOST_PORT:-$DEFAULT_MCP_FORWARD_PORT}"
	mcp_device_port="${ANDROID_LAB_MCP_DEVICE_PORT:-$DEFAULT_MCP_FORWARD_PORT}"
	validate_tcp_port ANDROID_LAB_FORWARD_HOST_PORT "$host_port"
	validate_tcp_port ANDROID_LAB_FORWARD_DEVICE_PORT "$device_port"
	validate_tcp_port ANDROID_LAB_MCP_HOST_PORT "$mcp_host_port"
	validate_tcp_port ANDROID_LAB_MCP_DEVICE_PORT "$mcp_device_port"
	[[ "$host_port" != "$mcp_host_port" ]] || {
		log ERROR "Android automation and MCP host ports must differ"
		exit 1
	}
	start
	log INFO "forwarding emulator loopback port to host loopback"
	compose up --detach --force-recreate forward || {
		log ERROR "could not start Android lab forwarding service"
		exit 1
	}
}

unforward() {
	detect_kvm_gid
	log INFO "stopping Android lab forwarding service"
	compose stop forward || {
		log ERROR "could not stop Android lab forwarding service"
		exit 1
	}
}

wait_for_web_vnc() {
	local host_port deadline container_id binding expected_binding
	host_port="$1"
	expected_binding="127.0.0.1:${host_port}"
	deadline=$((SECONDS + VNC_READY_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		if compose exec --no-TTY web-vnc bash -c \
			"curl --fail --silent http://127.0.0.1:${WEB_VNC_PORT}/vnc.html >/dev/null && python3 -c 'import socket; connection = socket.create_connection((\"emulator\", ${VNC_SERVER_PORT}), 5); banner = connection.recv(12); connection.close(); raise SystemExit(banner != b\"RFB 003.008\\n\")'" >/dev/null 2>&1; then # Intentional: retries hide startup connection errors until QEMU serves the VNC protocol.
			container_id="$(compose ps --quiet web-vnc)"
			binding="$(docker inspect --format '{{with index .NetworkSettings.Ports "61325/tcp"}}{{range .}}{{.HostIp}}:{{.HostPort}}{{end}}{{end}}' "$container_id")"
			if [[ "$binding" == "$expected_binding" ]]; then
				log INFO "interactive Android web VNC is available at http://127.0.0.1:${host_port}/vnc.html?autoconnect=true&resize=scale"
				return 0
			fi
		fi
		sleep 1
	done
	log ERROR "Android web VNC did not publish ${expected_binding} or connect to the private emulator VNC listener"
	return 1
}

verify_emulator_window() {
	local geometry viewport_width viewport_height
	# shellcheck disable=SC2016 # The remote Bash must expand its positional argument and array.
	geometry="$(compose exec --no-TTY emulator bash -c '
		set -euo pipefail
		export DISPLAY=:99
		window_ids=()
		mapfile -t window_ids < <(xdotool search --name "$1")
		((${#window_ids[@]} == 1))
		xdotool windowmap "${window_ids[0]}"
		visible_window_ids=()
		mapfile -t visible_window_ids < <(xdotool search --onlyvisible --name "$1")
		((${#visible_window_ids[@]} == 1))
		[[ "${visible_window_ids[0]}" == "${window_ids[0]}" ]]
		xdotool getwindowgeometry --shell "${window_ids[0]}"
	' bash "$EMULATOR_WINDOW_NAME_PATTERN")" || {
		log ERROR "could not inspect the Android emulator window through private X"
		return 1
	}
	viewport_width="$(awk -F= '$1 == "WIDTH" { print $2 }' <<<"$geometry")"
	viewport_height="$(awk -F= '$1 == "HEIGHT" { print $2 }' <<<"$geometry")"
	if [[ "$viewport_width" != "$EMULATOR_VIEWPORT_WIDTH" ||
		"$viewport_height" != "$EMULATOR_VIEWPORT_HEIGHT" ]]; then
		log ERROR "Android web VNC did not show a full phone viewport width=${viewport_width} height=${viewport_height}"
		return 1
	fi
	log INFO "Android web VNC shows the full phone viewport width=${viewport_width} height=${viewport_height}"
}

run_device_operation() {
	local operation="$1"
	ensure_lab_directories
	detect_kvm_gid
	compose run --rm --no-deps \
		-e APK \
		-e TEST_APK \
		-e TEST_RUNNER \
		-e ANDROID_LAB_FORWARD_HOST_PORT \
		-e ANDROID_LAB_FORWARD_DEVICE_PORT \
		-e ANDROID_LAB_MCP_HOST_PORT \
		-e ANDROID_LAB_MCP_DEVICE_PORT \
		-e ANDROID_LAB_VNC_HOST_PORT \
		-e ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS \
		-e PACKAGE_NAME \
		-e ACTIVITY \
		-e DEVICE_COMMAND \
		-e DEVICE_FILE \
		-e ARTIFACT_FILE \
		-e EMULATOR_GEO_LATITUDE \
		-e EMULATOR_GEO_LONGITUDE \
		-e EMULATOR_SENSOR_NAME \
		-e EMULATOR_SENSOR_VALUES \
		-e EMULATOR_SMS_SENDER \
		-e EMULATOR_SMS_BODY \
		-e EMULATOR_POWER_AC \
		-e EMULATOR_WIFI_STATE \
		-e EMULATOR_BLUETOOTH_STATE \
		-e EMULATOR_THERMAL_STATE \
		-e EMULATOR_POWER_SAVE_MODE \
		-e EMULATOR_DEVICE_IDLE_MODE \
		-e EMULATOR_NIGHT_MODE \
		-e EMULATOR_DEVICE_ORIENTATION \
		-e EMULATOR_FONT_SCALE_PERCENT \
		-e EMULATOR_RINGER_MODE \
		-e EMULATOR_NOTIFICATION_POLICY_ACCESS \
		-e EMULATOR_INTERRUPTION_FILTER \
		-e ANDROID_LAB_FORCE_NAVIGATION_REBOOT \
		lab bash /opt/android-lab/scripts/lab-device.sh "$operation"
}

if [[ -n "${ANDROID_LAB_EXTENSION:-}" ]]; then
	extension_path="$(realpath "$REPOSITORY_DIR/$ANDROID_LAB_EXTENSION")"
	[[ "$extension_path" == "$REPOSITORY_DIR/"* && -f "$extension_path" ]] || {
		log ERROR "extension must stay inside the workspace"
		exit 1
	}
	# The caller explicitly selects trusted project code, not an image dependency.
	# shellcheck source=/dev/null
	source "$extension_path"
fi

case "$COMMAND" in
start)
	start
	;;
restart)
	stop
	start
	;;
stop)
	stop
	;;
status)
	detect_kvm_gid
	compose ps
	;;
device-info | apk-install | screenshot | uiautomator-dump | ui-layout | uiautomator-run | app-current | app-start | app-stop | home-role-set | home-start | configure-navigation | device-shell | emulator-geo-fix | emulator-sensor-set | emulator-sms-send | emulator-power-set | emulator-wifi-set | emulator-bluetooth-set | emulator-thermal-set | emulator-power-save-set | emulator-device-idle-set | emulator-night-mode-set | emulator-device-orientation-set | emulator-font-scale-set | emulator-ringer-mode-set | emulator-notification-policy-access-set | emulator-interruption-filter-set | calendar-fixture-create | calendar-fixture-update | calendar-fixture-delete | contacts-fixture-create | contacts-fixture-delete | accessibility-on | accessibility-off | file-pull | file-push)
	run_device_operation "${COMMAND#apk-}"
	;;
forward)
	forward
	;;
unforward)
	unforward
	;;
test-emulator)
	trap stop EXIT
	start
	run_device_operation device-info
	run_device_operation uiautomator-dump
	run_device_operation ui-layout
	run_device_operation screenshot
	;;
test-forward)
	trap stop EXIT
	forward
	run_device_operation forward-test-listener
	compose exec --no-TTY forward sh -c \
		"timeout 5 socat - TCP:127.0.0.1:${ANDROID_LAB_FORWARD_HOST_PORT}" >/dev/null || {
		log ERROR "device loopback forward did not accept a connection"
		exit 1
	}
	log INFO "device loopback forward passed"
	;;
test-vnc)
	trap stop EXIT
	start
	;;
*)
	if declare -F android_lab_extension_command >/dev/null; then
		android_lab_extension_command "$COMMAND"
	else
		log ERROR "unsupported Android lab command=${COMMAND}"
		exit 1
	fi
	;;
esac
