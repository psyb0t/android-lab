#!/bin/bash
# Builds the local Android Lab images for one tagged release.
#
#   curl -fsSL https://raw.githubusercontent.com/psyb0t/android-lab/main/install.sh |
#     ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes bash -s -- 0.13.0 --emulator
#
# The installer always comes from main; the images always come from the
# requested tag. It relies only on the release-stable contract documented in
# docs/integration.md: the VERSION file and the `dev-image` and `image` Make
# targets with ANDROID_API and ANDROID_LAB_ACCEPT_ANDROID_LICENSES.
set -euo pipefail

readonly SCRIPT_NAME=install.sh
readonly DEFAULT_REPOSITORY=https://github.com/psyb0t/android-lab.git
readonly DEFAULT_API=36
readonly SDK_TERMS_URL=https://developer.android.com/studio/terms
readonly CLONE_ATTEMPTS=3
readonly CLONE_RETRY_SECONDS=2
readonly VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'
readonly EXIT_USAGE=2
readonly REQUIRED_HOST_TOOLS=(docker git make)

json_string() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\t'/\\t}"
	printf '"%s"' "$value"
}

# jq is not a host requirement, so the JSON line is assembled here.
log() {
	local level="$1"
	shift
	printf '{"time":%s,"level":%s,"file":%s,"line":%d,"func":%s,"msg":%s}\n' \
		"$(json_string "$(date -u '+%Y-%m-%dT%H:%M:%SZ')")" \
		"$(json_string "$level")" \
		"$(json_string "$SCRIPT_NAME")" \
		"${BASH_LINENO[0]}" \
		"$(json_string "${FUNCNAME[1]:-main}")" \
		"$(json_string "$*")" >&2
}

on_error() {
	local exit_code=$?
	trap - ERR
	log ERROR "command failed exit=${exit_code}"
	exit "$exit_code"
}

trap on_error ERR

LOG_FILE="${LOG_FILE:-${TMPDIR:-/tmp}/android-lab-install.log}"
# stdout carries only the image names, so the two streams are teed separately.
exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)

usage() {
	cat <<EOF
Usage: install.sh [options] VERSION

Build android-lab:VERSION from the vVERSION tag of Android Lab. Images that
already exist locally are kept unless --force is given.

Options:
  --emulator        Also build android-lab:VERSION-emulator-apiAPI.
  --api API         Android API level, default ${DEFAULT_API}.
  --force           Rebuild the requested images even when they exist.
  --work-dir DIR    Parent directory for the temporary checkout, default \${TMPDIR:-/tmp}.
                    The emulator build bind-mounts the checkout through the host
                    Docker daemon, so DIR must exist at the same path on that host.
  -h, --help        Show this help.

Environment:
  ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes   Required. Read ${SDK_TERMS_URL} first.
  ANDROID_LAB_REPOSITORY                    Git URL to build from, default ${DEFAULT_REPOSITORY}.

Prints the requested image names on stdout.
EOF
}

version=""
api="$DEFAULT_API"
build_emulator_requested=false
force_rebuild=false
work_dir="${TMPDIR:-/tmp}"
repository="${ANDROID_LAB_REPOSITORY:-$DEFAULT_REPOSITORY}"
checkout_parent=""

parse_args() {
	while (($# > 0)); do
		case "$1" in
		--emulator) build_emulator_requested=true ;;
		--force) force_rebuild=true ;;
		--api | --work-dir)
			[[ $# -ge 2 ]] || {
				log ERROR "option needs a value option=$1"
				exit "$EXIT_USAGE"
			}
			if [[ "$1" == --api ]]; then
				api="$2"
			else
				work_dir="$2"
			fi
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			log ERROR "unknown option option=$1"
			usage >&2
			exit "$EXIT_USAGE"
			;;
		*)
			[[ -z "$version" ]] || {
				log ERROR "only one VERSION is accepted"
				exit "$EXIT_USAGE"
			}
			version="$1"
			;;
		esac
		shift
	done
}

validate_inputs() {
	[[ -n "$version" ]] || {
		log ERROR "VERSION is required"
		usage >&2
		exit "$EXIT_USAGE"
	}
	[[ "$version" =~ $VERSION_PATTERN ]] || {
		log ERROR "VERSION must look like X.Y.Z version=${version}"
		exit "$EXIT_USAGE"
	}
	[[ "$api" =~ ^[0-9]+$ ]] || {
		log ERROR "API must be an integer api=${api}"
		exit "$EXIT_USAGE"
	}
	[[ -d "$work_dir" ]] || {
		log ERROR "work directory does not exist work_dir=${work_dir}"
		exit "$EXIT_USAGE"
	}
	[[ "${ANDROID_LAB_ACCEPT_ANDROID_LICENSES:-}" == yes ]] || {
		log ERROR "read ${SDK_TERMS_URL}, then set ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes"
		exit 1
	}

	local tool
	for tool in "${REQUIRED_HOST_TOOLS[@]}"; do
		command -v "$tool" >/dev/null || {
			log ERROR "missing required host tool tool=${tool}"
			exit 1
		}
	done
	# docker info prints a long client report on failure; the log line below replaces it.
	docker info >/dev/null 2>&1 || {
		log ERROR "cannot reach the Docker daemon"
		exit 1
	}
}

image_exists() {
	# A missing image is an expected answer here, not an error worth printing.
	docker image inspect "$1" >/dev/null 2>&1
}

clone_release() {
	local tag="$1" destination="$2" attempt
	for ((attempt = 1; attempt <= CLONE_ATTEMPTS; attempt++)); do
		if git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$repository" "$destination"; then
			return 0
		fi
		rm -rf -- "$destination"
		log WARN "clone failed repository=${repository} tag=${tag} attempt=${attempt}"
		if ((attempt < CLONE_ATTEMPTS)); then
			sleep "$CLONE_RETRY_SECONDS"
		fi
	done
	log ERROR "release tag not found or not reachable repository=${repository} tag=${tag}"
	exit 1
}

print_images() {
	local dev_image="$1" emulator_image="$2"
	printf '%s\n' "$dev_image"
	if [[ "$build_emulator_requested" == true ]]; then
		printf '%s\n' "$emulator_image"
	fi
}

main() {
	parse_args "$@"
	validate_inputs

	local dev_image="android-lab:${version}"
	local emulator_image="android-lab:${version}-emulator-api${api}"
	local build_dev=true build_emulator="$build_emulator_requested"
	if [[ "$force_rebuild" == false ]] && image_exists "$dev_image"; then
		log INFO "keeping image image=${dev_image} reason=image_exists"
		build_dev=false
	fi
	if [[ "$force_rebuild" == false && "$build_emulator" == true ]] && image_exists "$emulator_image"; then
		log INFO "keeping image image=${emulator_image} reason=image_exists"
		build_emulator=false
	fi
	if [[ "$build_dev" == false && "$build_emulator" == false ]]; then
		print_images "$dev_image" "$emulator_image"
		log INFO "Android Lab is ready version=${version}"
		return 0
	fi

	checkout_parent="$(mktemp -d "${work_dir%/}/android-lab-install.XXXXXX")"
	trap 'rm -rf -- "$checkout_parent"' EXIT
	local source_dir="$checkout_parent/android-lab"

	log INFO "fetching Android Lab repository=${repository} tag=v${version}"
	clone_release "v${version}" "$source_dir"

	local source_version
	source_version="$(<"$source_dir/VERSION")"
	[[ "$source_version" == "$version" ]] || {
		log ERROR "tag carries a different VERSION tag=v${version} source_version=${source_version}"
		exit 1
	}

	local make_args=(-C "$source_dir" "ANDROID_API=${api}" ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes)
	if [[ "$build_dev" == true ]]; then
		log INFO "building image image=${dev_image}"
		make "${make_args[@]}" dev-image >&2
	fi
	if [[ "$build_emulator" == true ]]; then
		log INFO "building image image=${emulator_image}"
		make "${make_args[@]}" image >&2
	fi

	print_images "$dev_image" "$emulator_image"
	log INFO "Android Lab is ready version=${version}"
}

# Piped through `curl | bash`, stdin is this script. Keep child processes off it.
main "$@" </dev/null
