#!/bin/bash
set -euo pipefail

log() {
	local level="$1"
	shift
	jq -cn --arg time "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" --arg level "$level" --arg file "${BASH_SOURCE[1]##*/}" --argjson line "${BASH_LINENO[0]}" --arg func "${FUNCNAME[1]:-main}" --arg msg "$*" '{time:$time,level:$level,file:$file,line:$line,func:$func,msg:$msg}' >&2
}
on_error() {
	local code=$?
	log ERROR "lab contract failed exit=$code"
	exit "$code"
}
trap on_error ERR
LOG_FILE="${LOG_FILE:-/tmp/android-lab-check.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

readonly TOOL_ROOT=/opt/android-lab
fixture_workspace="$(mktemp -d '/tmp/android-lab-contract with spaces.XXXXXX')"
trap 'rm -rf -- "$fixture_workspace"' EXIT
cp -a "$TOOL_ROOT/tests/gradle-project" "$fixture_workspace/project"
export ANDROID_LAB_WORKSPACE="$fixture_workspace"
export ANDROID_PROJECT=project GRADLE_TASK=:app:verifyProjectDirectory
android-lab gradle
ANDROID_LAB_WORKSPACE="$fixture_workspace/project" ANDROID_PROJECT=. android-lab gradle
ANDROID_LAB_TEST_EXPECTED_WORKERS=1 ANDROID_LAB_GRADLE_MAX_WORKERS=1 android-lab gradle
ln -s "$TOOL_ROOT/tests/gradle-project" "$fixture_workspace/escape"
for project in '' ../outside /tmp escape; do
	if ANDROID_PROJECT="$project" android-lab gradle >"$fixture_workspace/rejected.log" 2>&1; then
		log ERROR "accepted an invalid project directory"
		exit 1
	fi
done
for task in '' 'assembleDebug' ':app:test;unexpected' ':app:test foo'; do
	if GRADLE_TASK="$task" android-lab gradle >"$fixture_workspace/rejected.log" 2>&1; then
		log ERROR "accepted an invalid Gradle task"
		exit 1
	fi
done
for workers in 0 11 -1 garbage; do
	if ANDROID_LAB_GRADLE_MAX_WORKERS="$workers" android-lab gradle >"$fixture_workspace/rejected.log" 2>&1; then
		log ERROR "accepted an invalid Gradle worker count"
		exit 1
	fi
done
cp -a "$fixture_workspace/project" "$fixture_workspace/no-checksum"
printf '%s\n' 'distributionUrl=https://example.invalid/gradle.zip' >"$fixture_workspace/no-checksum/gradle/wrapper/gradle-wrapper.properties"
if ANDROID_PROJECT=no-checksum android-lab gradle >"$fixture_workspace/rejected.log" 2>&1; then
	log ERROR "accepted a wrapper without a distribution checksum"
	exit 1
fi

export ANDROID_LAB_HOST_WORKSPACE="$fixture_workspace"
export ANDROID_LAB_STATE_DIRECTORY="$fixture_workspace/state/shared"
export ANDROID_LAB_EMULATOR_CONTROL_DIRECTORY="$ANDROID_LAB_STATE_DIRECTORY/emulator-control"
export ANDROID_LAB_DEV_IMAGE=android-lab:contract
export ANDROID_LAB_EMULATOR_IMAGE=android-lab:contract-emulator
export ANDROID_LAB_UID=1000 ANDROID_LAB_GID=1000 ANDROID_LAB_KVM_GID=993
docker compose --file "$TOOL_ROOT/docker-compose.yml" config --format json >"$fixture_workspace/compose.json"
jq -e --arg workspace "$fixture_workspace" --arg state "$ANDROID_LAB_STATE_DIRECTORY" '(
	.services.emulator.ports == null
	and .services.lab.ports == null
	and .services.keygen.network_mode == "none"
	and .networks.device.internal == true
	and .services["adb-bridge"].network_mode == "service:emulator"
	and .services["adb-bridge"].command == ["bash", "/opt/android-lab/scripts/adb-bridge.sh"]
	and any(.services.lab.volumes[]; .source == $workspace and .target == "/work" and .read_only)
	and any(.services.emulator.volumes[]; .source == ($state + "/emulator-data") and .target == "/data")
	and all(.services[]; .user == "1000:1000" and .read_only and .init and (.cap_drop | index("ALL")) != null)
	and all(.services[]; .pids_limit > 0 and (.cpus | tonumber) > 0 and (.mem_limit | length) > 0)
	and all(.services.forward.ports[]; .host_ip == "127.0.0.1")
	and .services["web-vnc"].ports[0].host_ip == "127.0.0.1"
)' "$fixture_workspace/compose.json" >/dev/null
python3 "$TOOL_ROOT/scripts/uiautomator_to_json.py" "$TOOL_ROOT/tests/uiautomator_layout.xml" | jq -e '(
	.schemaVersion == 1 and (.elements | length) == 2
	and .elements[0].center == {x:60,y:45}
	and .elements[1].visibleToUser == false
)' >/dev/null
log INFO "embedded CLI, standalone Gradle roots, boundary inputs and Compose mounts passed"
