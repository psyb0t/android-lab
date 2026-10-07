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

LOG_FILE="${LOG_FILE:-/tmp/android-lab-build-emulator-image.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

REPOSITORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_LAB_API="${ANDROID_LAB_API:-36}"
ANDROID_LAB_EMULATOR_IMAGE="${ANDROID_LAB_EMULATOR_IMAGE:-android-lab/emulator:api-${ANDROID_LAB_API}}"
readonly BUILD_CPU_PERIOD=100000
readonly BUILD_CPU_QUOTA=1000000
readonly BUILD_MEMORY_LIMIT=8g
readonly BUILD_PROCESS_LIMIT=2048

validate_url() {
	local url="$1"
	[[ "$url" == https://dl.google.com/android/repository/* ]] || {
		log ERROR "refusing non-Google artifact URL"
		exit 1
	}
}

validate_sha1() {
	local checksum="$1"
	[[ "$checksum" =~ ^[0-9a-f]{40}$ ]] || {
		log ERROR "refusing malformed SHA-1 from artifact metadata"
		exit 1
	}
}

[[ "${ANDROID_LAB_ACCEPT_ANDROID_LICENSES:-}" == "yes" ]] || {
	log ERROR "set ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes after accepting the Android SDK License Agreement"
	exit 1
}
[[ "$ANDROID_LAB_API" =~ ^[0-9]+$ ]] || {
	log ERROR "ANDROID_LAB_API must be an integer"
	exit 1
}
[[ "$ANDROID_LAB_EMULATOR_IMAGE" =~ ^[a-z0-9][a-z0-9._/-]*:[a-z0-9][a-z0-9._-]*$ ]] || {
	log ERROR "ANDROID_LAB_EMULATOR_IMAGE is malformed"
	exit 1
}

metadata="$(python3 "$REPOSITORY_DIR/scripts/resolve_android_downloads.py" --api "$ANDROID_LAB_API")"
emulator_url="$(jq -er '.emulator.url' <<<"$metadata")"
emulator_sha1="$(jq -er '.emulator.sha1' <<<"$metadata")"
platform_tools_url="$(jq -er '.platform_tools.url' <<<"$metadata")"
platform_tools_sha1="$(jq -er '.platform_tools.sha1' <<<"$metadata")"
system_image_url="$(jq -er '.system_image.url' <<<"$metadata")"
system_image_sha1="$(jq -er '.system_image.sha1' <<<"$metadata")"

for artifact_url in "$emulator_url" "$platform_tools_url" "$system_image_url"; do
	validate_url "$artifact_url"
done
for artifact_sha1 in "$emulator_sha1" "$platform_tools_sha1" "$system_image_sha1"; do
	validate_sha1 "$artifact_sha1"
done

log INFO "building Android API ${ANDROID_LAB_API} emulator image=${ANDROID_LAB_EMULATOR_IMAGE}"
docker build --pull \
	--resource "cpu-period=$BUILD_CPU_PERIOD" \
	--resource "cpu-quota=$BUILD_CPU_QUOTA" \
	--resource "memory=$BUILD_MEMORY_LIMIT" \
	--ulimit "nproc=$BUILD_PROCESS_LIMIT:$BUILD_PROCESS_LIMIT" \
	--file "$REPOSITORY_DIR/Dockerfile.emulator" \
	--build-arg "ANDROID_API=${ANDROID_LAB_API}" \
	--build-arg "EMULATOR_URL=${emulator_url}" \
	--build-arg "EMULATOR_SHA1=${emulator_sha1}" \
	--build-arg "PLATFORM_TOOLS_URL=${platform_tools_url}" \
	--build-arg "PLATFORM_TOOLS_SHA1=${platform_tools_sha1}" \
	--build-arg "SYSTEM_IMAGE_URL=${system_image_url}" \
	--build-arg "SYSTEM_IMAGE_SHA1=${system_image_sha1}" \
	--tag "$ANDROID_LAB_EMULATOR_IMAGE" \
	"$REPOSITORY_DIR" || {
	log ERROR "Android emulator image build failed"
	exit 1
}

log INFO "Android emulator image built"
