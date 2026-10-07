#!/bin/bash

set -euo pipefail

log() {
	local level="$1"
	shift
	jq -cn --arg time "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" --arg level "$level" --arg file "${BASH_SOURCE[1]##*/}" --argjson line "${BASH_LINENO[0]}" --arg func "${FUNCNAME[1]:-main}" --arg msg "$*" '{time: $time, level: $level, file: $file, line: $line, func: $func, msg: $msg}' >&2
}

on_error() {
	local exit_code=$?
	trap - ERR
	log ERROR "command failed exit=${exit_code}"
	exit "$exit_code"
}

trap on_error ERR

LOG_FILE="${LOG_FILE:-/tmp/android-lab-format.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

shfmt -w scripts/*.sh
python3 -m compileall -q scripts
log INFO "Android lab sources formatted"
