#!/bin/bash
# Exercises install.sh with stubbed docker, git and make, so it needs neither a
# network, a Docker socket nor an SDK download.
set -euo pipefail

log() {
	local level="$1"
	shift
	jq -cn --arg time "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" --arg level "$level" --arg file "${BASH_SOURCE[1]##*/}" --argjson line "${BASH_LINENO[0]}" --arg func "${FUNCNAME[1]:-main}" --arg msg "$*" '{time:$time,level:$level,file:$file,line:$line,func:$func,msg:$msg}' >&2
}
on_error() {
	local code=$?
	trap - ERR
	log ERROR "installer contract failed exit=$code"
	exit "$code"
}
trap on_error ERR
LOG_FILE="${LOG_FILE:-/tmp/android-lab-test-install.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

REPOSITORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_DIR
readonly INSTALLER="$REPOSITORY_DIR/install.sh"
readonly RELEASE_VERSION=0.13.0
readonly DEV_IMAGE="android-lab:${RELEASE_VERSION}"
readonly EMULATOR_IMAGE="android-lab:${RELEASE_VERSION}-emulator-api36"

fixture="$(mktemp -d '/tmp/android-lab-install contract.XXXXXX')"
trap 'rm -rf -- "$fixture"' EXIT
stub_bin="$fixture/bin"
release_repository="$fixture/repository"
work_dir="$fixture/work"
export STUB_CALLS="$fixture/calls"
export STUB_IMAGES="$fixture/images"
mkdir -p "$stub_bin" "$release_repository/tags/v${RELEASE_VERSION}" "$release_repository/tags/v9.9.9" "$work_dir"
printf '%s\n' "$RELEASE_VERSION" >"$release_repository/tags/v${RELEASE_VERSION}/VERSION"
printf '%s\n' 1.0.0 >"$release_repository/tags/v9.9.9/VERSION"

cat >"$stub_bin/docker" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'docker %s\n' "$*" >>"$STUB_CALLS"
case "$1" in
info) [[ "${STUB_DOCKER_DOWN:-}" != yes ]] ;;
image) [[ "$2" == inspect ]] && grep -qxF -- "$3" "$STUB_IMAGES" ;;
*) exit 1 ;;
esac
EOF
cat >"$stub_bin/git" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'git %s\n' "$*" >>"$STUB_CALLS"
arguments=("$@")
destination="${arguments[-1]}"
repository="${arguments[-2]}"
tag=""
for ((index = 0; index < ${#arguments[@]}; index++)); do
	[[ "${arguments[index]}" == --branch ]] && tag="${arguments[index + 1]}"
done
[[ -d "$repository/tags/$tag" ]] || exit 128
cp -R "$repository/tags/$tag" "$destination"
EOF
cat >"$stub_bin/make" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'make %s\n' "$*" >>"$STUB_CALLS"
source_dir="$2"
target="${*: -1}"
api="${3#ANDROID_API=}"
version="$(<"$source_dir/VERSION")"
case "$target" in
dev-image) printf 'android-lab:%s\n' "$version" >>"$STUB_IMAGES" ;;
image) printf 'android-lab:%s-emulator-api%s\n' "$version" "$api" >>"$STUB_IMAGES" ;;
*) exit 1 ;;
esac
EOF
chmod 0755 "$stub_bin"/*

# Sets installer_output and installer_status. Images listed after -- exist before the run.
run_installer() {
	local existing_images=()
	while (($# > 0)) && [[ "$1" != -- ]]; do
		existing_images+=("$1")
		shift
	done
	shift
	: >"$STUB_CALLS"
	if ((${#existing_images[@]} > 0)); then
		printf '%s\n' "${existing_images[@]}" >"$STUB_IMAGES"
	else
		: >"$STUB_IMAGES"
	fi
	if installer_output="$(
		PATH="$stub_bin:$PATH" TMPDIR="$work_dir" LOG_FILE="$fixture/install.log" \
			ANDROID_LAB_REPOSITORY="$release_repository" \
			bash "$INSTALLER" "$@" 2>"$fixture/stderr"
	)"; then
		installer_status=0
	else
		installer_status=$?
	fi
}

expect_status() {
	[[ "$installer_status" == "$1" ]] || {
		log ERROR "unexpected exit case=$2 expected=$1 actual=$installer_status stderr=$(<"$fixture/stderr")"
		exit 1
	}
}

expect_call() {
	grep -qF -- "$1" "$STUB_CALLS" || {
		log ERROR "missing call case=$2 call=$1"
		exit 1
	}
}

expect_no_call() {
	if grep -qF -- "$1" "$STUB_CALLS"; then
		log ERROR "unexpected call case=$2 call=$1"
		exit 1
	fi
}

expect_output() {
	[[ "$installer_output" == "$1" ]] || {
		log ERROR "unexpected stdout case=$2 expected=$1 actual=$installer_output"
		exit 1
	}
}

expect_clean_work_dir() {
	[[ -z "$(ls -A "$work_dir")" ]] || {
		log ERROR "temporary checkout left behind case=$1"
		exit 1
	}
}

export ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes

for invalid in '' 1.2 v0.13.0 '0.13.0;id' '--api x 0.13.0' '0.13.0 0.14.0' '--bogus 0.13.0' '--api'; do
	read -ra arguments <<<"$invalid"
	run_installer -- "${arguments[@]}"
	expect_status 2 "invalid arguments: ${invalid}"
	expect_no_call 'git ' "invalid arguments: ${invalid}"
done

ANDROID_LAB_ACCEPT_ANDROID_LICENSES=no run_installer -- "$RELEASE_VERSION"
expect_status 1 "license not accepted"
expect_no_call 'git ' "license not accepted"
grep -qF 'developer.android.com/studio/terms' "$fixture/stderr"

STUB_DOCKER_DOWN=yes run_installer -- "$RELEASE_VERSION"
expect_status 1 "docker unreachable"
expect_no_call 'git ' "docker unreachable"

run_installer "$DEV_IMAGE" -- "$RELEASE_VERSION"
expect_status 0 "tool image present"
expect_no_call 'git ' "tool image present"
expect_output "$DEV_IMAGE" "tool image present"

run_installer -- "$RELEASE_VERSION"
expect_status 0 "tool image missing"
expect_call "--branch v${RELEASE_VERSION} ${release_repository}" "tool image missing"
expect_call "ANDROID_API=36 ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes dev-image" "tool image missing"
expect_no_call "=yes image" "tool image missing"
expect_output "$DEV_IMAGE" "tool image missing"
expect_clean_work_dir "tool image missing"

run_installer "$DEV_IMAGE" -- --emulator "$RELEASE_VERSION"
expect_status 0 "emulator image missing"
expect_no_call "dev-image" "emulator image missing"
expect_call "ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes image" "emulator image missing"
expect_output "$DEV_IMAGE"$'\n'"$EMULATOR_IMAGE" "emulator image missing"

run_installer "$DEV_IMAGE" "$EMULATOR_IMAGE" -- --emulator "$RELEASE_VERSION"
expect_status 0 "both images present"
expect_no_call 'git ' "both images present"

run_installer "$DEV_IMAGE" -- --force "$RELEASE_VERSION"
expect_status 0 "forced rebuild"
expect_call "dev-image" "forced rebuild"

run_installer -- --api 35 --emulator "$RELEASE_VERSION"
expect_status 0 "custom API"
expect_call "ANDROID_API=35 ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes image" "custom API"
expect_output "$DEV_IMAGE"$'\n'"android-lab:${RELEASE_VERSION}-emulator-api35" "custom API"

run_installer -- 1.2.3
expect_status 1 "unknown tag"
expect_no_call 'make ' "unknown tag"
expect_clean_work_dir "unknown tag"

run_installer -- 9.9.9
expect_status 1 "tag with another VERSION"
expect_no_call 'make ' "tag with another VERSION"
expect_clean_work_dir "tag with another VERSION"

run_installer -- --work-dir "$fixture/missing" "$RELEASE_VERSION"
expect_status 2 "missing work directory"

: >"$STUB_CALLS"
: >"$STUB_IMAGES"
piped_output="$(
	PATH="$stub_bin:$PATH" TMPDIR="$work_dir" LOG_FILE="$fixture/install.log" \
		ANDROID_LAB_REPOSITORY="$release_repository" \
		bash -s -- "$RELEASE_VERSION" <"$INSTALLER" 2>"$fixture/stderr"
)"
[[ "$piped_output" == "$DEV_IMAGE" ]] || {
	log ERROR "piped installer printed an unexpected result output=$piped_output"
	exit 1
}
expect_call "dev-image" "piped installer"
expect_clean_work_dir "piped installer"

log INFO "installer arguments, license gate, image reuse, tag checkout and cleanup passed"
