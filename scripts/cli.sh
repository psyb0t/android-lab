#!/bin/bash
set -euo pipefail

readonly TOOL_ROOT=/opt/android-lab
command="${1:-help}"
if (($# > 0)); then
	shift
fi
case "$command" in
help | --help | -h)
	printf '%s\n' 'Usage: android-lab <command>' \
		'Commands: version, gradle, check, lint, start, stop, status, forward, unforward,' \
		'  device-info, apk-install, screenshot, ui-layout, device-shell, app-start, app-stop.' \
		'Set ANDROID_LAB_WORKSPACE to the mounted project directory. See make help for device operations.'
	;;
version | --version)
	cat "$TOOL_ROOT/VERSION"
	;;
gradle)
	exec bash "$TOOL_ROOT/scripts/gradle-project.sh" "$@"
	;;
check)
	exec bash "$TOOL_ROOT/scripts/test-lab.sh" "$@"
	;;
lint)
	exec bash "$TOOL_ROOT/scripts/lint.sh" "$@"
	;;
*)
	exec bash "$TOOL_ROOT/scripts/android-lab.sh" "$command" "$@"
	;;
esac
