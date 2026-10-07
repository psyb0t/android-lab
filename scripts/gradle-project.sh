#!/bin/bash

set -euo pipefail

readonly GRADLE_PROPERTIES_FILE=gradle/wrapper/gradle-wrapper.properties
readonly GRADLE_TASK_PATTERN='^:[A-Za-z0-9_:-]+$'
readonly GRADLE_STATE_DIRECTORY=.android-lab/gradle
readonly JAVA_USER_HOME_DIRECTORY=.android-lab/java-home
readonly MAX_GRADLE_WORKERS=10

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

REPOSITORY_DIR="$(realpath "${ANDROID_LAB_WORKSPACE:-$PWD}")"
PROJECT="${ANDROID_PROJECT:-}"
TASK="${GRADLE_TASK:-}"
GRADLE_MAX_WORKERS="${ANDROID_LAB_GRADLE_MAX_WORKERS:-$MAX_GRADLE_WORKERS}"

[[ -n "$PROJECT" && "$PROJECT" != /* ]] || {
	log ERROR "ANDROID_PROJECT must be a relative directory under the Android workspace"
	exit 1
}
[[ "$TASK" =~ $GRADLE_TASK_PATTERN ]] || {
	log ERROR "GRADLE_TASK must be one fully-qualified Gradle task"
	exit 1
}
if ! [[ "$GRADLE_MAX_WORKERS" =~ ^[1-9][0-9]*$ ]] ||
	((GRADLE_MAX_WORKERS > MAX_GRADLE_WORKERS)); then
	log ERROR "ANDROID_LAB_GRADLE_MAX_WORKERS must be an integer from 1 through ${MAX_GRADLE_WORKERS}"
	exit 1
fi

PROJECT_DIR="$(realpath -m "$REPOSITORY_DIR/$PROJECT")"
[[ ("$PROJECT_DIR" == "$REPOSITORY_DIR" || "$PROJECT_DIR" == "$REPOSITORY_DIR/"*) && -d "$PROJECT_DIR" ]] || {
	log ERROR "ANDROID_PROJECT is not a directory under the Android workspace"
	exit 1
}
[[ -x "$PROJECT_DIR/gradlew" ]] || {
	log ERROR "ANDROID_PROJECT must contain an executable Gradle wrapper"
	exit 1
}
[[ -s "$PROJECT_DIR/$GRADLE_PROPERTIES_FILE" ]] || {
	log ERROR "ANDROID_PROJECT is missing Gradle wrapper properties"
	exit 1
}
rg --quiet '^distributionSha256Sum=[0-9a-f]{64}$' "$PROJECT_DIR/$GRADLE_PROPERTIES_FILE" || {
	log ERROR "Gradle wrapper requires a pinned distributionSha256Sum"
	exit 1
}

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$REPOSITORY_DIR/$GRADLE_STATE_DIRECTORY}"
JAVA_USER_HOME="$REPOSITORY_DIR/$JAVA_USER_HOME_DIRECTORY"
mkdir --parents "$GRADLE_USER_HOME" "$JAVA_USER_HOME"
export HOME="$JAVA_USER_HOME"
export GRADLE_OPTS="${GRADLE_OPTS:-} -Duser.home=${JAVA_USER_HOME}"
LOG_FILE="${LOG_FILE:-$GRADLE_USER_HOME/android-lab-gradle.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ "${DEBUG:-}" == 1 ]]; then
	log DEBUG "running checked Gradle task"
fi
log INFO "running Gradle task inside the Docker-only Android lab with bounded workers"
cd "$PROJECT_DIR"
./gradlew --no-daemon --max-workers "$GRADLE_MAX_WORKERS" "$TASK"
log INFO "Gradle task completed"
