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

LOG_FILE="${LOG_FILE:-/tmp/android-lab-device.log}"
exec 3>&1
exec > >(tee -a "$LOG_FILE" >&3) 2> >(tee -a "$LOG_FILE" >&2)

EXPECTED_SERIAL=emulator:5556
HOST_ADB_SERVER_SOCKET='tcp:127.0.0.1:5037'
TEST_REAL="${TEST_REAL:-0}"
DEVICE_UNLOCK_PASSWORD="${DIKCIZ_TEST_UNLOCK_PASSWORD:-}"
if [[ "$TEST_REAL" == 1 ]]; then
	SERIAL="${TEST_DEVIVE_ID:-}"
	[[ "$SERIAL" =~ ^[A-Za-z0-9._:-]+$ ]] || {
		log ERROR "TEST_DEVIVE_ID must contain one configured ADB serial"
		exit 1
	}
	export ADB_SERVER_SOCKET="$HOST_ADB_SERVER_SOCKET"
else
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "TEST_REAL must be 0 or 1"
		exit 1
	}
	SERIAL="${ANDROID_LAB_SERIAL:-$EXPECTED_SERIAL}"
fi
KEY_DIR="${ANDROID_LAB_ADB_KEY_DIR:-/android-lab/adb}"
ARTIFACT_DIR="${ANDROID_LAB_ARTIFACT_DIR:-/artifacts}"
COMMAND="${1:-}"
DEVICE_FILE="${DEVICE_FILE:-}"
ARTIFACT_FILE="${ARTIFACT_FILE:-}"
EMULATOR_GEO_LATITUDE="${EMULATOR_GEO_LATITUDE:-}"
EMULATOR_GEO_LONGITUDE="${EMULATOR_GEO_LONGITUDE:-}"
EMULATOR_SENSOR_NAME="${EMULATOR_SENSOR_NAME:-}"
EMULATOR_SENSOR_VALUES="${EMULATOR_SENSOR_VALUES:-}"
EMULATOR_POWER_AC="${EMULATOR_POWER_AC:-}"
EMULATOR_WIFI_STATE="${EMULATOR_WIFI_STATE:-}"
EMULATOR_BLUETOOTH_STATE="${EMULATOR_BLUETOOTH_STATE:-}"
EMULATOR_THERMAL_STATE="${EMULATOR_THERMAL_STATE:-}"
EMULATOR_POWER_SAVE_MODE="${EMULATOR_POWER_SAVE_MODE:-}"
EMULATOR_DEVICE_IDLE_MODE="${EMULATOR_DEVICE_IDLE_MODE:-}"
EMULATOR_NIGHT_MODE="${EMULATOR_NIGHT_MODE:-}"
EMULATOR_DEVICE_ORIENTATION="${EMULATOR_DEVICE_ORIENTATION:-}"
EMULATOR_FONT_SCALE_PERCENT="${EMULATOR_FONT_SCALE_PERCENT:-}"
EMULATOR_RINGER_MODE="${EMULATOR_RINGER_MODE:-}"
EMULATOR_NOTIFICATION_POLICY_ACCESS="${EMULATOR_NOTIFICATION_POLICY_ACCESS:-}"
EMULATOR_INTERRUPTION_FILTER="${EMULATOR_INTERRUPTION_FILTER:-}"
EMULATOR_SMS_SENDER="${EMULATOR_SMS_SENDER:-}"
EMULATOR_SMS_BODY="${EMULATOR_SMS_BODY:-}"
readonly ACTIVITY_START_WAIT_FLAG="-W"
readonly ACTIVITY_STATE_PATTERN='^[[:space:]]*(topResumedActivity=|mResumedActivity:|mCurrentFocus=|mFocusedApp=)'
readonly ACTIVITY_STATE_WAIT_SECONDS=15
readonly ADB_CONNECTION_TIMEOUT_SECONDS=360
readonly ACCESSIBILITY_ENABLED_SERVICES_SETTING=enabled_accessibility_services
readonly ACCESSIBILITY_ENABLED_SETTING=accessibility_enabled
readonly ACCESSIBILITY_SERVICE_ACTION=android.accessibilityservice.AccessibilityService
readonly ACCESSIBILITY_SERVICE_SEPARATOR=':'
readonly APK_INSTALL_TIMEOUT_SECONDS=60
readonly ANDROID_USER_ID=0
readonly ARTIFACT_FILE_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
readonly BATTERY_AC_OFF=0
readonly BATTERY_AC_ON=1
readonly DEVICE_FILE_PATTERN='^/sdcard(/[A-Za-z0-9._-]+)+$'
readonly EMULATOR_DECIMAL_PATTERN='^-?([0-9]+([.][0-9]+)?|[.][0-9]+)$'
# The emulator writes a base64 token, so the credential has to allow the
# base64 alphabet. What the check is really for is the console protocol:
# the token goes out on an 'auth <token>' line, so anything that could end
# that line or start another one stays rejected.
readonly EMULATOR_CONSOLE_AUTH_TOKEN_PATTERN='^[A-Za-z0-9+/=._-]+$'
readonly EMULATOR_CONSOLE_AUTH_TOKEN_FILE=/android-lab/emulator-control/auth-token
readonly EMULATOR_CONSOLE_HOST=emulator
readonly EMULATOR_CONSOLE_MINIMUM_OK_RESPONSES=2
readonly EMULATOR_CONSOLE_PORT=5554
readonly EMULATOR_CONSOLE_TIMEOUT_SECONDS=5
readonly EMULATOR_POWER_AC_OFF=off
readonly EMULATOR_POWER_AC_ON=on
readonly EMULATOR_DEVICE_IDLE_MODE_ACTIVE=active
readonly EMULATOR_DEVICE_IDLE_MODE_IDLE=idle
readonly EMULATOR_DEVICE_IDLE_MODE_IDLE_DEPTH=deep
readonly EMULATOR_NIGHT_MODE_AUTO=auto
readonly EMULATOR_NIGHT_MODE_NO=no
readonly EMULATOR_NIGHT_MODE_YES=yes
readonly EMULATOR_DEVICE_ORIENTATION_LANDSCAPE=landscape
readonly EMULATOR_DEVICE_ORIENTATION_PORTRAIT=portrait
readonly EMULATOR_FONT_SCALE_PERCENT_SMALL=85
readonly EMULATOR_FONT_SCALE_PERCENT_BASELINE=100
readonly EMULATOR_FONT_SCALE_PERCENT_ENLARGED=130
readonly EMULATOR_FONT_SCALE_VALUE_SMALL=0.85
readonly EMULATOR_FONT_SCALE_VALUE_BASELINE=1.0
readonly EMULATOR_FONT_SCALE_VALUE_ENLARGED=1.3
readonly EMULATOR_FONT_SCALE_SETTING=font_scale
readonly EMULATOR_DEVICE_ROTATION_LOCKED=0
readonly EMULATOR_DEVICE_ROTATION_LANDSCAPE=1
readonly EMULATOR_DEVICE_ROTATION_PORTRAIT=0
readonly EMULATOR_DEVICE_ROTATION_SETTING=accelerometer_rotation
readonly EMULATOR_USER_ROTATION_SETTING=user_rotation
readonly EMULATOR_SENSOR_NAME_PATTERN='^[a-z][a-z0-9_-]{0,63}$'
readonly EMULATOR_SENSOR_VALUES_PATTERN='^-?([0-9]+([.][0-9]+)?|[.][0-9]+)(:-?([0-9]+([.][0-9]+)?|[.][0-9]+)){2}$'
readonly EMULATOR_SMS_BODY_MAXIMUM_CHARACTERS=512
readonly EMULATOR_SMS_SENDER_PATTERN='^[0-9]{1,32}$'
readonly EMULATOR_WIFI_CONNECTED=connected
readonly EMULATOR_WIFI_CONNECTED_STATUS='Wifi is connected to "AndroidWifi"'
readonly EMULATOR_WIFI_DISCONNECTED=disconnected
readonly EMULATOR_WIFI_DISABLED_STATUS='Wifi is disabled'
readonly EMULATOR_WIFI_OPEN_SECURITY=open
readonly EMULATOR_WIFI_RETRY_SECONDS=1
readonly EMULATOR_WIFI_SSID=AndroidWifi
readonly EMULATOR_WIFI_TIMEOUT_SECONDS=30
readonly EMULATOR_BLUETOOTH_STATE_OFF=off
readonly EMULATOR_BLUETOOTH_STATE_ON=on
readonly EMULATOR_BLUETOOTH_TIMEOUT_SECONDS=15
readonly EMULATOR_BLUETOOTH_ENABLE_COMMAND=enable
readonly EMULATOR_BLUETOOTH_DISABLE_COMMAND=disable
readonly EMULATOR_BLUETOOTH_WAIT_FOR_ON_COMMAND=wait-for-state:STATE_ON
readonly EMULATOR_BLUETOOTH_WAIT_FOR_OFF_COMMAND=wait-for-state:STATE_OFF
readonly EMULATOR_THERMAL_STATE_RESET=reset
readonly EMULATOR_THERMAL_STATE_NONE=none
readonly EMULATOR_THERMAL_STATE_LIGHT=light
readonly EMULATOR_THERMAL_STATE_MODERATE=moderate
readonly EMULATOR_THERMAL_STATE_SEVERE=severe
readonly EMULATOR_THERMAL_STATE_CRITICAL=critical
readonly EMULATOR_THERMAL_STATE_EMERGENCY=emergency
readonly EMULATOR_THERMAL_STATE_SHUTDOWN=shutdown
readonly EMULATOR_THERMAL_LEVEL_NONE=0
readonly EMULATOR_THERMAL_LEVEL_LIGHT=1
readonly EMULATOR_THERMAL_LEVEL_MODERATE=2
readonly EMULATOR_THERMAL_LEVEL_SEVERE=3
readonly EMULATOR_THERMAL_LEVEL_CRITICAL=4
readonly EMULATOR_THERMAL_LEVEL_EMERGENCY=5
readonly EMULATOR_THERMAL_LEVEL_SHUTDOWN=6
readonly EMULATOR_POWER_SAVE_MODE_OFF=off
readonly EMULATOR_POWER_SAVE_MODE_ON=on
readonly EMULATOR_POWER_SAVE_MODE_OFF_VALUE=0
readonly EMULATOR_POWER_SAVE_MODE_ON_VALUE=1
readonly EMULATOR_RINGER_MODE_NORMAL=normal
readonly EMULATOR_RINGER_MODE_SILENT=silent
readonly EMULATOR_RINGER_MODE_VIBRATE=vibrate
readonly EMULATOR_RINGER_MODE_NORMAL_COMMAND=NORMAL
readonly EMULATOR_RINGER_MODE_SILENT_COMMAND=SILENT
readonly EMULATOR_RINGER_MODE_VIBRATE_COMMAND=VIBRATE
readonly EMULATOR_NOTIFICATION_POLICY_ACCESS_GRANTED=granted
readonly EMULATOR_NOTIFICATION_POLICY_ACCESS_REVOKED=revoked
readonly EMULATOR_NOTIFICATION_POLICY_ACCESS_GRANTED_COMMAND=allow_dnd
readonly EMULATOR_NOTIFICATION_POLICY_ACCESS_REVOKED_COMMAND=disallow_dnd
readonly EMULATOR_INTERRUPTION_FILTER_ALL=all
readonly EMULATOR_INTERRUPTION_FILTER_PRIORITY=priority
readonly EMULATOR_INTERRUPTION_FILTER_ALARMS=alarms
readonly EMULATOR_INTERRUPTION_FILTER_NONE=none
readonly CALENDAR_ACCOUNT_NAME=android-lab-calendar-fixture
readonly CALENDAR_ACCOUNT_SELECTION="account_name='${CALENDAR_ACCOUNT_NAME}' AND account_type='LOCAL'"
readonly CALENDAR_ACCOUNT_TYPE=LOCAL
readonly CALENDAR_CALENDARS_URI=content://com.android.calendar/calendars
readonly CALENDAR_EVENT_DESCRIPTION='Android lab calendar fixture description'
readonly CALENDAR_EVENT_END_MILLISECONDS=1790003600000
readonly CALENDAR_EVENT_LOCATION='Android lab calendar fixture location'
readonly CALENDAR_EVENT_START_MILLISECONDS=1790000000000
readonly CALENDAR_EVENT_TITLE='Android lab calendar fixture title'
readonly CALENDAR_EVENT_UPDATED_DESCRIPTION='Android lab calendar fixture updated description'
readonly CALENDAR_EVENT_UPDATED_END_MILLISECONDS=1790007200000
readonly CALENDAR_EVENT_UPDATED_LOCATION='Android lab calendar fixture updated location'
readonly CALENDAR_EVENT_UPDATED_TITLE='Android lab calendar fixture updated title'
readonly CALENDAR_EVENTS_URI=content://com.android.calendar/events
readonly CALENDAR_ID_COLUMN=_id
readonly CALENDAR_NAME=android-lab-calendar-fixture
readonly CALENDAR_SYNC_URI="${CALENDAR_CALENDARS_URI}?caller_is_syncadapter=true&account_name=${CALENDAR_ACCOUNT_NAME}&account_type=${CALENDAR_ACCOUNT_TYPE}"
readonly CONTACTS_ACCOUNT_NAME=android-lab-contacts-fixture
readonly CONTACTS_ACCOUNT_TYPE=com.android.localphone
readonly CONTACTS_DATA_URI=content://com.android.contacts/data
readonly CONTACTS_DISPLAY_NAME='Android lab contacts fixture'
readonly CONTACTS_NAME_MIME_TYPE=vnd.android.cursor.item/name
readonly CONTACTS_RAW_CONTACT_ID_COLUMN=_id
readonly CONTACTS_RAW_CONTACTS_URI=content://com.android.contacts/raw_contacts
readonly CONTACTS_RAW_CONTACT_SYNC_URI="${CONTACTS_RAW_CONTACTS_URI}?caller_is_syncadapter=true&account_name=${CONTACTS_ACCOUNT_NAME}&account_type=${CONTACTS_ACCOUNT_TYPE}"
readonly CONTACTS_RAW_CONTACT_SELECTION="sourceid='android-lab-contacts-fixture'"
readonly CONTACTS_SOURCE_ID=android-lab-contacts-fixture
readonly GESTURAL_NAVIGATION_OVERLAY='com.android.internal.systemui.navbar.gestural'
readonly HOME_INTENT_ACTION='android.intent.action.MAIN'
readonly HOME_INTENT_CATEGORY='android.intent.category.HOME'
readonly HOME_ROLE_NAME='android.app.role.HOME'
readonly NAVIGATION_MODE_SETTING='navigation_mode'
readonly PACKAGE_INSTALL_USER_FLAG='--user'
readonly PHYSICAL_APK_INSTALL_PATH='/data/local/tmp/android-lab-install.apk'
readonly PHYSICAL_APK_INSTALL_ATTEMPTS=2
readonly PHYSICAL_APK_INSTALL_RETRY_SECONDS=1
readonly PHYSICAL_APK_INSTALL_TIMEOUT_SECONDS=180
readonly PROVIDER_INVENTORY_ARTIFACT_FILE='appwidget-provider-inventory.txt'
readonly THREE_BUTTON_NAVIGATION_MODE=0
readonly THREE_BUTTON_NAVIGATION_OVERLAY='com.android.internal.systemui.navbar.threebutton'
readonly TALKBACK_ENABLE_RETRY_SECONDS=1
readonly TALKBACK_ENABLE_TIMEOUT_SECONDS=10
readonly TALKBACK_PACKAGE=com.google.android.marvin.talkback
readonly ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS="${ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS:-}"
readonly ACCESSIBILITY_STATE_OFF=off
readonly ACCESSIBILITY_STATE_ON=on
readonly ACCESSIBILITY_TIMEOUT_SECONDS=10
readonly ENGLISH_SYSTEM_LOCALE=en-US
readonly ENGLISH_TTS_LOCALE=eng-USA
readonly GOOGLE_TTS_PACKAGE=com.google.android.tts
readonly SYSTEM_LOCALES_SETTING=system_locales
readonly SYSTEM_UI_DIALOG_POLL_ATTEMPTS=30
readonly SYSTEM_UI_DIALOG_POLL_SECONDS=1
readonly SYSTEM_UI_NOT_RESPONDING_WAIT_BUTTON_RESOURCE_ID='android:id/aerr_wait'
readonly SYSTEM_UI_NOT_RESPONDING_WAIT_X=540
readonly SYSTEM_UI_NOT_RESPONDING_WAIT_Y=1336
readonly TTS_DEFAULT_ENGINE_SETTING=tts_default_synth
readonly TTS_DEFAULT_LOCALE_SETTING=tts_default_locale
readonly UIAUTOMATOR_DUMP_DEVICE_PATH=/sdcard/android-lab-window.xml
readonly UIAUTOMATOR_DUMP_ATTEMPTS=3
readonly UIAUTOMATOR_DUMP_RETRY_SECONDS=1
readonly CONTROL_FORWARD_DEFAULT_DEVICE_PORT=19001
readonly CONTROL_FORWARD_DEFAULT_HOST_PORT=19101
readonly KEYGUARD_LOCKED_STATE=true
readonly KEYGUARD_STATE_FIELD_PATTERN='(isStatusBarKeyguard|mIsKeyguardShowing|mKeyguardShowing|mShowingLockscreen)[[:space:]]*='
readonly KEYGUARD_TRUST_STATE_FIELD_PATTERN='(isDeviceLocked|deviceLocked|mDeviceLockedForUser|isLocked)[[:space:]]*='
readonly KEYGUARD_UNLOCKED_STATE=false
readonly KEYGUARD_UNKNOWN_STATE=unknown
readonly KEYGUARD_UNLOCK_PASSWORD_PATTERN='^[A-Za-z0-9._-]+$'
readonly KEYGUARD_UNLOCK_RETRY_SECONDS=1
readonly KEYGUARD_UNLOCK_SWIPE_DURATION_MILLISECONDS=300
readonly KEYGUARD_UNLOCK_SWIPE_END_PERCENT=20
readonly KEYGUARD_UNLOCK_SWIPE_START_PERCENT=85
readonly KEYGUARD_UNLOCK_TIMEOUT_SECONDS=10

cleanup_adb() {
	if [[ "$TEST_REAL" == 1 ]]; then
		return 0
	fi
	if [[ "${ANDROID_LAB_KEEP_ADB_SERVER:-false}" == true ]]; then
		return 0
	fi
	adb kill-server >/dev/null 2>&1 || :
}

device_description() {
	if [[ "$TEST_REAL" == 1 ]]; then
		printf '%s' "configured physical device"
		return 0
	fi
	printf '%s' "isolated emulator"
}

trap cleanup_adb EXIT

[[ "$TEST_REAL" == 1 || "$SERIAL" == "$EXPECTED_SERIAL" ]] || {
	log ERROR "refusing a device other than ${EXPECTED_SERIAL}"
	exit 1
}
[[ -n "$COMMAND" ]] || {
	log ERROR "device operation is required"
	exit 1
}

setup_adb() {
	local deadline seconds_left status devices
	if [[ "$TEST_REAL" == 1 ]]; then
		mapfile -t devices < <(adb devices | awk 'NR > 1 && NF {print $1 " " $2}')
		[[ "${#devices[@]}" -eq 1 && "${devices[0]}" == "$SERIAL device" ]] || {
			log ERROR "configured real device is unavailable, unauthorized, or not the only ADB device"
			exit 1
		}
		return 0
	fi
	export HOME=/tmp/android-lab-home
	mkdir --parents "$HOME/.android"
	[[ -s "$KEY_DIR/adbkey" && -s "$KEY_DIR/adbkey.pub" ]] || {
		log ERROR "dedicated Android lab ADB key is missing"
		exit 1
	}
	cp --preserve=mode "$KEY_DIR/adbkey" "$HOME/.android/adbkey"
	cp --preserve=mode "$KEY_DIR/adbkey.pub" "$HOME/.android/adbkey.pub"
	chmod 0600 "$HOME/.android/adbkey"

	adb start-server >/dev/null
	deadline=$((SECONDS + ADB_CONNECTION_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		timeout 5 adb connect "$SERIAL" >/dev/null 2>&1 || :
		status="$(timeout 5 adb -s "$SERIAL" get-state 2>/dev/null || :)"
		if [[ "$status" == "device" ]]; then
			break
		fi
		sleep 2
	done
	seconds_left=$((deadline - SECONDS))
	((seconds_left > 0)) || {
		log ERROR "$(device_description) did not become reachable within ${ADB_CONNECTION_TIMEOUT_SECONDS} seconds"
		exit 1
	}

	mapfile -t devices < <(adb devices | awk 'NR > 1 && NF {print $1 " " $2}')
	[[ "${#devices[@]}" -eq 1 && "${devices[0]}" == "$SERIAL device" ]] || {
		log ERROR "refusing unexpected ADB device inventory"
		exit 1
	}
}

wait_for_boot() {
	local deadline boot_completed
	deadline=$((SECONDS + 300))
	while ((SECONDS < deadline)); do
		boot_completed="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null || :)" # Intentional: the guest disconnects while it is rebooting.
		boot_completed="${boot_completed//$'\r'/}"
		if [[ "$boot_completed" == "1" ]]; then
			log INFO "Android device booted"
			return 0
		fi
		sleep 2
	done
	log ERROR "$(device_description) did not finish booting"
	return 1
}

resolve_apk() {
	local value="$1"
	local resolved
	[[ -n "$value" && "$value" != /* && "$value" == *.apk ]] || {
		log ERROR "APK must be a relative .apk path under the Android workspace"
		exit 1
	}
	resolved="$(realpath -m "/work/$value")"
	[[ "$resolved" == /work/* && -f "$resolved" ]] || {
		log ERROR "APK is not a file under the Android workspace"
		exit 1
	}
	printf '%s\n' "$resolved"
}

install_apk() {
	local apk_path
	setup_adb
	wait_for_boot
	apk_path="$(resolve_apk "${APK:-}")"
	if [[ "$TEST_REAL" == 1 ]]; then
		install_apk_on_physical_device "$apk_path"
		log INFO "APK installed"
		return 0
	fi
	timeout "$APK_INSTALL_TIMEOUT_SECONDS" adb -s "$SERIAL" install -r "$apk_path" || {
		log ERROR "APK installation failed"
		exit 1
	}
	log INFO "APK installed"
}

install_apk_on_physical_device() {
	local apk_path="$1"
	local attempt
	for ((attempt = 1; attempt <= PHYSICAL_APK_INSTALL_ATTEMPTS; attempt++)); do
		timeout "$APK_INSTALL_TIMEOUT_SECONDS" adb -s "$SERIAL" push "$apk_path" "$PHYSICAL_APK_INSTALL_PATH" || {
			log ERROR "could not transfer the APK to the configured physical device"
			return 1
		}
		log INFO "installing the APK for Android user ${ANDROID_USER_ID} on the configured physical device attempt=${attempt}"
		if install_physical_apk_once; then
			adb -s "$SERIAL" shell rm -f "$PHYSICAL_APK_INSTALL_PATH" || {
				log ERROR "could not remove the physical APK transfer"
				return 1
			}
			enable_physical_package || return 1
			return 0
		fi
		adb -s "$SERIAL" shell rm -f "$PHYSICAL_APK_INSTALL_PATH" >/dev/null 2>&1 || log WARN "could not remove the failed physical APK transfer"
		if ((attempt < PHYSICAL_APK_INSTALL_ATTEMPTS)); then
			log WARN "Android package manager did not complete, retrying the current APK without rebooting the configured physical device"
			sleep "$PHYSICAL_APK_INSTALL_RETRY_SECONDS"
		fi
	done
	log ERROR "Android package manager could not install the APK on the configured physical device after ${PHYSICAL_APK_INSTALL_ATTEMPTS} attempts"
	return 1
}

install_physical_apk_once() {
	local exit_code install_output
	if install_output="$(timeout "$PHYSICAL_APK_INSTALL_TIMEOUT_SECONDS" adb -s "$SERIAL" shell pm install \
		-r \
		"$PACKAGE_INSTALL_USER_FLAG" \
		"$ANDROID_USER_ID" \
		"$PHYSICAL_APK_INSTALL_PATH" 2>&1)"; then
		printf '%s\n' "$install_output"
		return 0
	else
		exit_code=$?
	fi
	[[ -z "$install_output" ]] || log ERROR "Android package manager output: ${install_output}"
	log ERROR "Android package manager install attempt exited status=${exit_code}"
	return "$exit_code"
}

enable_physical_package() {
	local package_name
	package_name="${PACKAGE_NAME:-}"
	validate_package_name "$package_name"
	adb -s "$SERIAL" shell pm enable --user "$ANDROID_USER_ID" "$package_name" || {
		log ERROR "could not enable the current physical-test package"
		return 1
	}
	log INFO "current physical-test package enabled"
}

run_instrumentation() {
	local test_apk runner
	test_apk="$(resolve_apk "${TEST_APK:-}")"
	runner="${TEST_RUNNER:-}"
	[[ "$runner" =~ ^[A-Za-z0-9_.]+/[A-Za-z0-9_.]+$ ]] || {
		log ERROR "TEST_RUNNER must be package/runner"
		exit 1
	}
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" install -r "$test_apk" || {
		log ERROR "UIAutomator test APK installation failed"
		exit 1
	}
	adb -s "$SERIAL" shell am instrument --wait "$runner" || {
		log ERROR "UIAutomator instrumentation failed"
		exit 1
	}
	log INFO "UIAutomator instrumentation passed"
}

capture_screenshot() {
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" exec-out screencap -p >"$ARTIFACT_DIR/screenshot.png" || {
		log ERROR "screenshot capture failed"
		exit 1
	}
	[[ -s "$ARTIFACT_DIR/screenshot.png" ]] || {
		log ERROR "screenshot is empty"
		exit 1
	}
	log INFO "screenshot saved at ${ARTIFACT_DIR}/screenshot.png"
}

dump_uiautomator() {
	capture_uiautomator_xml
	log INFO "UIAutomator dump saved at ${ARTIFACT_DIR}/window.xml"
}

capture_uiautomator_xml() {
	local attempt
	setup_adb
	wait_for_boot
	for ((attempt = 1; attempt <= UIAUTOMATOR_DUMP_ATTEMPTS; attempt++)); do
		if adb -s "$SERIAL" shell uiautomator dump "$UIAUTOMATOR_DUMP_DEVICE_PATH" >/dev/null &&
			adb -s "$SERIAL" exec-out cat "$UIAUTOMATOR_DUMP_DEVICE_PATH" >"$ARTIFACT_DIR/window.xml" &&
			[[ -s "$ARTIFACT_DIR/window.xml" ]]; then
			return 0
		fi
		if ((attempt < UIAUTOMATOR_DUMP_ATTEMPTS)); then
			log WARN "UIAutomator dump failed, retrying attempt=${attempt}"
			sleep "$UIAUTOMATOR_DUMP_RETRY_SECONDS"
		fi
	done
	log ERROR "UIAutomator dump failed after ${UIAUTOMATOR_DUMP_ATTEMPTS} attempts"
	exit 1
}

write_ui_layout() {
	capture_uiautomator_xml
	python3 /opt/android-lab/scripts/uiautomator_to_json.py "$ARTIFACT_DIR/window.xml" >"$ARTIFACT_DIR/layout.json" || {
		log ERROR "could not convert UIAutomator XML into a JSON layout"
		exit 1
	}
	[[ -s "$ARTIFACT_DIR/layout.json" ]] || {
		log ERROR "UI layout JSON is empty"
		exit 1
	}
	log INFO "UI layout saved at ${ARTIFACT_DIR}/layout.json"
}

device_info() {
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell getprop ro.build.version.sdk
	adb -s "$SERIAL" shell getprop ro.build.version.release
	adb -s "$SERIAL" shell getprop ro.product.model
}

provider_inventory() {
	local inventory_path
	setup_adb
	wait_for_boot
	mkdir --parents "$ARTIFACT_DIR"
	inventory_path="$ARTIFACT_DIR/$PROVIDER_INVENTORY_ARTIFACT_FILE"
	adb -s "$SERIAL" shell dumpsys appwidget | tee "$inventory_path" || {
		log ERROR "could not read the configured physical device AppWidget provider inventory"
		exit 1
	}
	[[ -s "$inventory_path" ]] || {
		log ERROR "configured physical device AppWidget provider inventory is empty"
		exit 1
	}
	log INFO "configured physical device AppWidget provider inventory saved at ${inventory_path}"
}

validate_package_name() {
	local package_name="$1"
	[[ "$package_name" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$ ]] || {
		log ERROR "PACKAGE_NAME must be a dotted Android package name"
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

physical_device_keyguard_state() {
	local keyguard_state trust_state window_policy
	if ! trust_state="$(adb -s "$SERIAL" shell dumpsys trust)"; then
		log ERROR "could not read the configured physical device trust state"
		return 1
	fi
	keyguard_state="$(
		awk -F= -v pattern="$KEYGUARD_TRUST_STATE_FIELD_PATTERN" '
			$0 ~ pattern {
				state = $NF
				gsub(/[^[:alnum:]]/, "", state)
				print state
				exit
			}
		' <<<"$trust_state"
	)"
	case "$keyguard_state" in
	"$KEYGUARD_LOCKED_STATE" | 1)
		printf '%s\n' "$KEYGUARD_LOCKED_STATE"
		return 0
		;;
	"$KEYGUARD_UNLOCKED_STATE" | 0)
		printf '%s\n' "$KEYGUARD_UNLOCKED_STATE"
		return 0
		;;
	esac
	if ! window_policy="$(adb -s "$SERIAL" shell dumpsys window policy)"; then
		log ERROR "could not read the configured physical device keyguard state"
		return 1
	fi
	keyguard_state="$(
		awk -F= -v pattern="$KEYGUARD_STATE_FIELD_PATTERN" '
			$0 ~ pattern {
				state = $NF
				gsub(/[^[:alnum:]]/, "", state)
				print state
				exit
			}
		' <<<"$window_policy"
	)"
	case "$keyguard_state" in
	"$KEYGUARD_LOCKED_STATE" | "$KEYGUARD_UNLOCKED_STATE")
		printf '%s\n' "$keyguard_state"
		;;
	*)
		printf '%s\n' "$KEYGUARD_UNKNOWN_STATE"
		;;
	esac
}

physical_display_size() {
	local display_size window_manager_size
	if ! window_manager_size="$(adb -s "$SERIAL" shell wm size)"; then
		log ERROR "could not read the configured physical device display size"
		return 1
	fi
	display_size="$(awk '/Physical size:/{print $3; exit}' <<<"$window_manager_size")"
	[[ "$display_size" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] || {
		log ERROR "configured physical device reported an unsupported display size"
		return 1
	}
	printf '%s\n' "$display_size"
}

unlock_physical_device() {
	local display_height display_size display_width keyguard_state deadline unlock_end_y unlock_start_x unlock_start_y
	[[ "$TEST_REAL" == 1 ]] || {
		log ERROR "physical-device unlocking is only supported for the configured physical device"
		return 1
	}
	setup_adb
	wait_for_boot
	if ! keyguard_state="$(physical_device_keyguard_state)"; then
		return 1
	fi
	if [[ "$keyguard_state" == "$KEYGUARD_UNLOCKED_STATE" ]]; then
		log INFO "configured physical device is already unlocked"
		return 0
	fi
	if [[ "$keyguard_state" == "$KEYGUARD_UNKNOWN_STATE" ]]; then
		adb -s "$SERIAL" shell input keyevent KEYCODE_HOME || {
			log ERROR "could not return the configured physical device to Android Home before unlock input"
			return 1
		}
		log WARN "configured physical device keyguard state is hidden by the system, returned to Android Home before unlock input"
	fi
	[[ "$DEVICE_UNLOCK_PASSWORD" =~ $KEYGUARD_UNLOCK_PASSWORD_PATTERN ]] || {
		log ERROR "DIKCIZ_TEST_UNLOCK_PASSWORD must be a non-empty local lock credential with only letters, digits, dots, underscores, or hyphens"
		return 1
	}
	if ! display_size="$(physical_display_size)"; then
		return 1
	fi
	read -r display_width display_height <<<"${display_size/x/ }"
	unlock_start_x=$((display_width / 2))
	unlock_start_y=$((display_height * KEYGUARD_UNLOCK_SWIPE_START_PERCENT / 100))
	unlock_end_y=$((display_height * KEYGUARD_UNLOCK_SWIPE_END_PERCENT / 100))
	adb -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP || {
		log ERROR "could not wake the configured physical device"
		return 1
	}
	adb -s "$SERIAL" shell input swipe \
		"$unlock_start_x" \
		"$unlock_start_y" \
		"$unlock_start_x" \
		"$unlock_end_y" \
		"$KEYGUARD_UNLOCK_SWIPE_DURATION_MILLISECONDS" || {
		log ERROR "could not reveal the configured physical device lock input"
		return 1
	}
	adb -s "$SERIAL" shell input text "$DEVICE_UNLOCK_PASSWORD" || {
		log ERROR "could not enter the configured physical device lock credential"
		return 1
	}
	adb -s "$SERIAL" shell input keyevent KEYCODE_ENTER || {
		log ERROR "could not submit the configured physical device lock credential"
		return 1
	}
	deadline=$((SECONDS + KEYGUARD_UNLOCK_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		if ! keyguard_state="$(physical_device_keyguard_state)"; then
			return 1
		fi
		if [[ "$keyguard_state" == "$KEYGUARD_UNLOCKED_STATE" ]]; then
			log INFO "configured physical device unlocked"
			return 0
		fi
		if [[ "$keyguard_state" == "$KEYGUARD_UNKNOWN_STATE" ]]; then
			log INFO "configured physical device unlock input completed"
			return 0
		fi
		sleep "$KEYGUARD_UNLOCK_RETRY_SECONDS"
	done
	log ERROR "configured physical device remained locked after one unlock attempt"
	return 1
}

read_enabled_accessibility_services() {
	local enabled_services
	enabled_services="$(adb -s "$SERIAL" shell settings get secure "$ACCESSIBILITY_ENABLED_SERVICES_SETTING" | tr -d '\r')" || {
		log ERROR "could not read Android enabled accessibility services"
		return 1
	}
	if [[ "$enabled_services" == null ]]; then
		printf '%s\n' ''
		return 0
	fi
	printf '%s\n' "$enabled_services"
}

accessibility_service_is_enabled() {
	local enabled_services="$1"
	local service_component="$2"
	case "$ACCESSIBILITY_SERVICE_SEPARATOR$enabled_services$ACCESSIBILITY_SERVICE_SEPARATOR" in
	*"$ACCESSIBILITY_SERVICE_SEPARATOR$service_component$ACCESSIBILITY_SERVICE_SEPARATOR"*) return 0 ;;
	*) return 1 ;;
	esac
}

remove_accessibility_service_component() {
	local enabled_services="$1"
	local service_component="$2"
	local service
	local -a services=()
	local -a remaining_services=()
	IFS="$ACCESSIBILITY_SERVICE_SEPARATOR" read -r -a services <<<"$enabled_services" || {
		log ERROR "could not parse Android enabled accessibility services"
		return 1
	}
	for service in "${services[@]}"; do
		[[ -z "$service" || "$service" == "$service_component" ]] && continue
		remaining_services+=("$service")
	done
	(
		IFS="$ACCESSIBILITY_SERVICE_SEPARATOR"
		printf '%s' "${remaining_services[*]}"
	)
}

resolve_talkback_service_component() {
	local service_component
	if ! adb -s "$SERIAL" shell pm path "$TALKBACK_PACKAGE" >/dev/null; then
		log ERROR "TalkBack is not installed on the configured physical device"
		return 1
	fi
	service_component="$(
		adb -s "$SERIAL" shell cmd package query-services \
			--brief \
			--user "$ANDROID_USER_ID" \
			-a "$ACCESSIBILITY_SERVICE_ACTION" | awk -v package_name="$TALKBACK_PACKAGE" '
			{
				for (field_index = 1; field_index <= NF; field_index++) {
					if (index($field_index, package_name "/") == 1) {
						print $field_index
						exit
					}
				}
			}
		'
	)" || {
		log ERROR "could not resolve the installed TalkBack accessibility service"
		return 1
	}
	[[ "$service_component" == "$TALKBACK_PACKAGE/"* ]] || {
		log ERROR "TalkBack did not expose an accessibility service component"
		return 1
	}
	[[ "${service_component#"$TALKBACK_PACKAGE"/}" =~ ^\.?[A-Za-z_][A-Za-z0-9_.$]*$ ]] || {
		log ERROR "TalkBack exposed an unsupported accessibility service component"
		return 1
	}
	printf '%s\n' "$service_component"
}

configure_english_talkback_voice() {
	local default_engine default_locale system_locales
	if ! adb -s "$SERIAL" shell pm path "$GOOGLE_TTS_PACKAGE" >/dev/null; then
		log ERROR "Google text-to-speech is not installed on the configured physical device"
		return 1
	fi
	adb -s "$SERIAL" shell settings put system \
		"$SYSTEM_LOCALES_SETTING" \
		"$ENGLISH_SYSTEM_LOCALE" || {
		log ERROR "could not set the Android system locale to English"
		return 1
	}
	adb -s "$SERIAL" shell settings put secure \
		"$TTS_DEFAULT_ENGINE_SETTING" \
		"$GOOGLE_TTS_PACKAGE" || {
		log ERROR "could not set Google text-to-speech as the Android default"
		return 1
	}
	adb -s "$SERIAL" shell settings put secure \
		"$TTS_DEFAULT_LOCALE_SETTING" \
		"$ENGLISH_TTS_LOCALE" || {
		log ERROR "could not set the Android text-to-speech locale to English"
		return 1
	}
	system_locales="$(adb -s "$SERIAL" shell settings get system "$SYSTEM_LOCALES_SETTING" | tr -d '\r')" || return 1
	default_engine="$(adb -s "$SERIAL" shell settings get secure "$TTS_DEFAULT_ENGINE_SETTING" | tr -d '\r')" || return 1
	default_locale="$(adb -s "$SERIAL" shell settings get secure "$TTS_DEFAULT_LOCALE_SETTING" | tr -d '\r')" || return 1
	[[ "$system_locales" == "$ENGLISH_SYSTEM_LOCALE"* ]] || {
		log ERROR "Android did not retain the English system locale"
		return 1
	}
	[[ "$default_engine" == "$GOOGLE_TTS_PACKAGE" ]] || {
		log ERROR "Android did not retain Google text-to-speech as the default"
		return 1
	}
	[[ "$default_locale" == "$ENGLISH_TTS_LOCALE" ]] || {
		log ERROR "Android did not retain the English text-to-speech locale"
		return 1
	}
	log INFO "Android locale and text-to-speech are set to English for TalkBack"
}

enable_talkback() {
	local deadline enabled_services service_component
	[[ "$TEST_REAL" == 1 ]] || {
		log ERROR "TalkBack is only supported on the configured physical device"
		return 1
	}
	unlock_physical_device
	configure_english_talkback_voice
	start_home
	service_component="$(resolve_talkback_service_component)" || return 1
	enabled_services="$(read_enabled_accessibility_services)" || return 1
	if ! accessibility_service_is_enabled "$enabled_services" "$service_component"; then
		if [[ -n "$enabled_services" ]]; then
			enabled_services="${enabled_services}:$service_component"
		else
			enabled_services="$service_component"
		fi
		adb -s "$SERIAL" shell settings put secure \
			"$ACCESSIBILITY_ENABLED_SERVICES_SETTING" \
			"$enabled_services" || {
			log ERROR "could not enable TalkBack in Android accessibility services"
			return 1
		}
	fi
	adb -s "$SERIAL" shell settings put secure \
		"$ACCESSIBILITY_ENABLED_SETTING" \
		1 || {
		log ERROR "could not enable Android accessibility services"
		return 1
	}
	deadline=$((SECONDS + TALKBACK_ENABLE_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		enabled_services="$(read_enabled_accessibility_services)" || return 1
		if accessibility_service_is_enabled "$enabled_services" "$service_component"; then
			start_home
			log INFO "TalkBack is enabled on the configured physical device and Dikciz Home is open"
			return 0
		fi
		sleep "$TALKBACK_ENABLE_RETRY_SECONDS"
	done
	log ERROR "TalkBack did not become enabled before the bounded timeout"
	return 1
}

disable_talkback() {
	local deadline enabled_services remaining_services service_component
	[[ "$TEST_REAL" == 1 ]] || {
		log ERROR "TalkBack is only supported on the configured physical device"
		return 1
	}
	unlock_physical_device
	service_component="$(resolve_talkback_service_component)" || return 1
	enabled_services="$(read_enabled_accessibility_services)" || return 1
	if ! accessibility_service_is_enabled "$enabled_services" "$service_component"; then
		start_home
		log INFO "TalkBack is already disabled on the configured physical device and Dikciz Home is open"
		return 0
	fi
	remaining_services="$(remove_accessibility_service_component "$enabled_services" "$service_component")" || return 1
	if [[ -z "$remaining_services" ]]; then
		adb -s "$SERIAL" shell settings delete secure \
			"$ACCESSIBILITY_ENABLED_SERVICES_SETTING" || {
			log ERROR "could not remove TalkBack from Android accessibility services"
			return 1
		}
		adb -s "$SERIAL" shell settings put secure \
			"$ACCESSIBILITY_ENABLED_SETTING" \
			0 || {
			log ERROR "could not disable Android accessibility services after removing TalkBack"
			return 1
		}
	else
		adb -s "$SERIAL" shell settings put secure \
			"$ACCESSIBILITY_ENABLED_SERVICES_SETTING" \
			"$remaining_services" || {
			log ERROR "could not remove TalkBack from Android accessibility services"
			return 1
		}
	fi
	deadline=$((SECONDS + TALKBACK_ENABLE_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		enabled_services="$(read_enabled_accessibility_services)" || return 1
		if ! accessibility_service_is_enabled "$enabled_services" "$service_component"; then
			start_home
			log INFO "TalkBack is disabled on the configured physical device and Dikciz Home is open"
			return 0
		fi
		sleep "$TALKBACK_ENABLE_RETRY_SECONDS"
	done
	log ERROR "TalkBack did not become inactive before the bounded timeout"
	return 1
}

set_app_accessibility() {
	local desired_state="$1"
	local deadline enabled_services package_name service_component updated_services
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "app accessibility service changes are only supported on the isolated emulator"
		return 1
	}
	[[ "$desired_state" == "$ACCESSIBILITY_STATE_ON" || "$desired_state" == "$ACCESSIBILITY_STATE_OFF" ]] || {
		log ERROR "app accessibility state must be on or off"
		return 1
	}
	package_name="${PACKAGE_NAME:-}"
	validate_package_name "$package_name"
	[[ "$ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$ ]] || {
		log ERROR "accessibility service class is required"
		return 1
	}
	service_component="${package_name}/${ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS}"
	setup_adb
	wait_for_boot
	enabled_services="$(read_enabled_accessibility_services)" || return 1
	if [[ "$desired_state" == "$ACCESSIBILITY_STATE_ON" ]]; then
		if ! accessibility_service_is_enabled "$enabled_services" "$service_component"; then
			if [[ -n "$enabled_services" ]]; then
				updated_services="${enabled_services}:${service_component}"
			else
				updated_services="$service_component"
			fi
			adb -s "$SERIAL" shell settings put secure \
				"$ACCESSIBILITY_ENABLED_SERVICES_SETTING" \
				"$updated_services" || {
				log ERROR "could not enable the app accessibility service on the isolated emulator"
				return 1
			}
		fi
		adb -s "$SERIAL" shell settings put secure "$ACCESSIBILITY_ENABLED_SETTING" 1 || {
			log ERROR "could not enable Android accessibility services on the isolated emulator"
			return 1
		}
	else
		if accessibility_service_is_enabled "$enabled_services" "$service_component"; then
			updated_services="$(remove_accessibility_service_component "$enabled_services" "$service_component")" || return 1
			if [[ -n "$updated_services" ]]; then
				adb -s "$SERIAL" shell settings put secure \
					"$ACCESSIBILITY_ENABLED_SERVICES_SETTING" \
					"$updated_services" || {
					log ERROR "could not remove the app accessibility service from the isolated emulator"
					return 1
				}
			else
				adb -s "$SERIAL" shell settings delete secure \
					"$ACCESSIBILITY_ENABLED_SERVICES_SETTING" || {
					log ERROR "could not clear Android accessibility services on the isolated emulator"
					return 1
				}
				adb -s "$SERIAL" shell settings put secure "$ACCESSIBILITY_ENABLED_SETTING" 0 || {
					log ERROR "could not disable Android accessibility services on the isolated emulator"
					return 1
				}
			fi
		fi
	fi
	deadline=$((SECONDS + ACCESSIBILITY_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		enabled_services="$(read_enabled_accessibility_services)" || return 1
		if [[ "$desired_state" == "$ACCESSIBILITY_STATE_ON" ]] &&
			accessibility_service_is_enabled "$enabled_services" "$service_component"; then
			log INFO "app accessibility service is enabled on the isolated emulator"
			return 0
		fi
		if [[ "$desired_state" == "$ACCESSIBILITY_STATE_OFF" ]] &&
			! accessibility_service_is_enabled "$enabled_services" "$service_component"; then
			log INFO "app accessibility service is disabled on the isolated emulator"
			return 0
		fi
		sleep "$TALKBACK_ENABLE_RETRY_SECONDS"
	done
	log ERROR "app accessibility service did not reach state=${desired_state} before the bounded timeout"
	return 1
}

app_current() {
	setup_adb
	wait_for_boot
	wait_for_foreground_activity
}

wait_for_foreground_activity() {
	local activity_state deadline
	deadline=$((SECONDS + ACTIVITY_STATE_WAIT_SECONDS))
	while ((SECONDS < deadline)); do
		activity_state="$(adb -s "$SERIAL" shell dumpsys activity activities)"
		if grep -Eq "$ACTIVITY_STATE_PATTERN" <<<"$activity_state"; then
			awk -v pattern="$ACTIVITY_STATE_PATTERN" '
				$0 ~ pattern && !printed {
					print
					printed = 1
				}
			' <<<"$activity_state"
			return 0
		fi
		if [[ "${DEBUG:-false}" == true ]]; then
			log DEBUG "foreground app not reported yet, retrying"
		fi
		sleep 1
	done
	log ERROR "could not determine the foreground app before timeout"
	exit 1
}

wait_for_foreground_package() {
	local activity_state deadline package_name
	package_name="$1"
	deadline=$((SECONDS + ACTIVITY_STATE_WAIT_SECONDS))
	while ((SECONDS < deadline)); do
		activity_state="$(adb -s "$SERIAL" shell dumpsys activity activities)"
		if grep -Fq "$package_name" <<<"$activity_state"; then
			printf '%s\n' "$activity_state"
			return 0
		fi
		if [[ "${DEBUG:-false}" == true ]]; then
			log DEBUG "expected foreground package not reported yet, retrying"
		fi
		sleep 1
	done
	log ERROR "expected foreground package did not appear before timeout"
	exit 1
}

home_role_contains_package() {
	local package_name role_holders
	package_name="$1"
	role_holders="$(adb -s "$SERIAL" shell cmd role get-role-holders "$HOME_ROLE_NAME" | tr -d '\r')"
	grep -Fqx "$package_name" <<<"$role_holders"
}

set_home_role() {
	local force_reassignment package_name
	package_name="${PACKAGE_NAME:-}"
	force_reassignment="${ANDROID_LAB_FORCE_HOME_ROLE_REASSIGN:-false}"
	validate_package_name "$package_name"
	case "$force_reassignment" in
	true | false) ;;
	*)
		log ERROR "ANDROID_LAB_FORCE_HOME_ROLE_REASSIGN must be true or false"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	if home_role_contains_package "$package_name"; then
		if [[ "$force_reassignment" == false ]]; then
			log INFO "Android Home role is already assigned to the requested package"
			return 0
		fi
		adb -s "$SERIAL" shell cmd role remove-role-holder \
			--user "$ANDROID_USER_ID" \
			"$HOME_ROLE_NAME" \
			"$package_name" || {
			log ERROR "could not refresh the Android Home role"
			exit 1
		}
		log INFO "Android Home role holder removed before the requested-package refresh"
	fi
	adb -s "$SERIAL" shell cmd role add-role-holder \
		--user "$ANDROID_USER_ID" \
		"$HOME_ROLE_NAME" \
		"$package_name" || {
		log ERROR "could not assign Android Home role"
		exit 1
	}
	if ! home_role_contains_package "$package_name"; then
		log ERROR "Android Home role verification failed"
		exit 1
	fi
	log INFO "Android Home role assigned to the requested package"
}

start_home() {
	local package_name
	package_name="${PACKAGE_NAME:-}"
	validate_package_name "$package_name"
	setup_adb
	wait_for_boot
	if ! home_role_contains_package "$package_name"; then
		log ERROR "requested package does not hold the Android Home role"
		exit 1
	fi
	adb -s "$SERIAL" shell am start \
		"$ACTIVITY_START_WAIT_FLAG" \
		-a "$HOME_INTENT_ACTION" \
		-c "$HOME_INTENT_CATEGORY" || {
		log ERROR "could not launch Android Home"
		exit 1
	}
	wait_for_foreground_package "$package_name" >/dev/null
	log INFO "Android Home started through the system resolver after Home-role verification"
}

navigation_overlay_status() {
	local overlay_name="$1"
	adb -s "$SERIAL" shell cmd overlay list \
		--user "$ANDROID_USER_ID" \
		"$overlay_name" | tr -d '\r'
}

navigation_is_configured() {
	local gestural_status navigation_mode three_button_status
	navigation_mode="$(adb -s "$SERIAL" shell settings get secure "$NAVIGATION_MODE_SETTING" | tr -d '\r')"
	three_button_status="$(navigation_overlay_status "$THREE_BUTTON_NAVIGATION_OVERLAY")"
	gestural_status="$(navigation_overlay_status "$GESTURAL_NAVIGATION_OVERLAY")"
	[[ "$navigation_mode" == "$THREE_BUTTON_NAVIGATION_MODE" ]] &&
		[[ "$three_button_status" == "[x] $THREE_BUTTON_NAVIGATION_OVERLAY" ]] &&
		[[ "$gestural_status" == "[ ] $GESTURAL_NAVIGATION_OVERLAY" ]]
}

system_ui_not_responding_dialog_state() {
	local ui_xml
	if ! adb -s "$SERIAL" shell uiautomator dump "$UIAUTOMATOR_DUMP_DEVICE_PATH" >/dev/null; then
		log WARN "could not inspect the Android System UI error dialog"
		return 2
	fi
	if ! ui_xml="$(adb -s "$SERIAL" exec-out cat "$UIAUTOMATOR_DUMP_DEVICE_PATH")"; then
		log WARN "could not retrieve the Android System UI error dialog state"
		return 2
	fi
	if [[ "$ui_xml" == *"resource-id=\"$SYSTEM_UI_NOT_RESPONDING_WAIT_BUTTON_RESOURCE_ID\""* ]]; then
		return 0
	fi
	return 1
}

wait_for_system_ui_recovery() {
	local attempt dialog_state
	for ((attempt = 1; attempt <= SYSTEM_UI_DIALOG_POLL_ATTEMPTS; attempt++)); do
		if system_ui_not_responding_dialog_state; then
			log WARN "waiting for Android System UI after navigation configuration"
			adb -s "$SERIAL" shell input tap \
				"$SYSTEM_UI_NOT_RESPONDING_WAIT_X" \
				"$SYSTEM_UI_NOT_RESPONDING_WAIT_Y" || {
				log ERROR "could not choose Android System UI recovery"
				return 1
			}
		else
			dialog_state=$?
			if ((dialog_state == 2)); then
				sleep "$SYSTEM_UI_DIALOG_POLL_SECONDS"
				continue
			fi
		fi
		sleep "$SYSTEM_UI_DIALOG_POLL_SECONDS"
	done
	if system_ui_not_responding_dialog_state; then
		log ERROR "Android System UI did not recover after navigation configuration"
		return 1
	fi
	dialog_state=$?
	if ((dialog_state == 2)); then
		log ERROR "could not verify Android System UI recovery"
		return 1
	fi
}

configure_navigation() {
	local force_reboot
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "navigation configuration is only supported on the isolated emulator"
		exit 1
	}
	force_reboot="${ANDROID_LAB_FORCE_NAVIGATION_REBOOT:-false}"
	case "$force_reboot" in
	true | false) ;;
	*)
		log ERROR "ANDROID_LAB_FORCE_NAVIGATION_REBOOT must be true or false"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	if navigation_is_configured && [[ "$force_reboot" == false ]]; then
		log INFO "Android three-button navigation is already configured"
		return 0
	fi
	if ! navigation_is_configured; then
		adb -s "$SERIAL" shell settings put secure \
			"$NAVIGATION_MODE_SETTING" \
			"$THREE_BUTTON_NAVIGATION_MODE" || {
			log ERROR "could not set Android navigation mode"
			exit 1
		}
		adb -s "$SERIAL" shell cmd overlay disable \
			--user "$ANDROID_USER_ID" \
			"$GESTURAL_NAVIGATION_OVERLAY" || {
			log ERROR "could not disable Android gestural navigation"
			exit 1
		}
		adb -s "$SERIAL" shell cmd overlay enable \
			--user "$ANDROID_USER_ID" \
			"$THREE_BUTTON_NAVIGATION_OVERLAY" || {
			log ERROR "could not enable Android three-button navigation"
			exit 1
		}
	fi
	log INFO "rebooting the Android guest to apply three-button navigation"
	adb -s "$SERIAL" reboot || {
		log ERROR "could not reboot Android guest after navigation configuration"
		exit 1
	}
	setup_adb
	wait_for_boot
	if ! navigation_is_configured; then
		log ERROR "Android three-button navigation verification failed"
		exit 1
	fi
	wait_for_system_ui_recovery || exit 1
	log INFO "Android three-button navigation is configured"
}

app_start() {
	local activity package_name
	package_name="${PACKAGE_NAME:-}"
	activity="${ACTIVITY:-}"
	validate_package_name "$package_name"
	[[ -z "$activity" || "$activity" =~ ^[.A-Za-z0-9_]+$ ]] || {
		log ERROR "ACTIVITY contains unsupported characters"
		exit 1
	}
	setup_adb
	wait_for_boot
	if [[ -n "$activity" ]]; then
		adb -s "$SERIAL" shell am start "$ACTIVITY_START_WAIT_FLAG" --activity-clear-top -n "$package_name/$activity" || {
			log ERROR "could not launch the requested app activity"
			exit 1
		}
	else
		adb -s "$SERIAL" shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 || {
			log ERROR "could not launch the requested app package"
			exit 1
		}
	fi
	wait_for_foreground_package "$package_name" >/dev/null
	log INFO "app started on $(device_description)"
}

app_stop() {
	local package_name
	package_name="${PACKAGE_NAME:-}"
	validate_package_name "$package_name"
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell am force-stop "$package_name"
	log INFO "app stopped on $(device_description)"
}

app_uninstall() {
	local package_name
	package_name="${PACKAGE_NAME:-}"
	validate_package_name "$package_name"
	setup_adb
	wait_for_boot
	if ! adb -s "$SERIAL" shell pm path --user "$ANDROID_USER_ID" "$package_name" >/dev/null 2>&1; then # Intentional: Package Manager reports an error when an idempotent reset finds no prior app install.
		log INFO "requested app is already absent from $(device_description)"
		return 0
	fi
	adb -s "$SERIAL" shell pm uninstall \
		"$PACKAGE_INSTALL_USER_FLAG" \
		"$ANDROID_USER_ID" \
		"$package_name" || {
		log ERROR "could not uninstall the requested app"
		exit 1
	}
	log INFO "app uninstalled from $(device_description)"
}

device_shell() {
	local device_command
	device_command="${DEVICE_COMMAND:-}"
	[[ -n "$device_command" ]] || {
		log ERROR "DEVICE_COMMAND is required"
		exit 1
	}
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell "$device_command"
}

validate_decimal_range() {
	local maximum="$1"
	local minimum="$2"
	local name="$3"
	local value="$4"
	[[ "$value" =~ $EMULATOR_DECIMAL_PATTERN ]] || {
		log ERROR "${name} must be a finite decimal"
		exit 1
	}
	awk -v maximum="$maximum" -v minimum="$minimum" -v value="$value" 'BEGIN { exit !(value >= minimum && value <= maximum) }' || {
		log ERROR "${name} must be between ${minimum} and ${maximum}"
		exit 1
	}
}

send_emulator_console_command() {
	local auth_token console_output ok_count
	local command="$1"
	[[ -s "$EMULATOR_CONSOLE_AUTH_TOKEN_FILE" ]] || {
		log ERROR "isolated emulator console credential is unavailable"
		exit 1
	}
	auth_token="$(<"$EMULATOR_CONSOLE_AUTH_TOKEN_FILE")"
	[[ "$auth_token" =~ $EMULATOR_CONSOLE_AUTH_TOKEN_PATTERN ]] || {
		log ERROR "isolated emulator console credential is invalid"
		exit 1
	}
	console_output="$(
		{
			printf 'auth %s\n' "$auth_token"
			printf '%s\n' "$command"
			printf 'quit\n'
		} | timeout "$EMULATOR_CONSOLE_TIMEOUT_SECONDS" \
			socat -T "$EMULATOR_CONSOLE_TIMEOUT_SECONDS" - "TCP:${EMULATOR_CONSOLE_HOST}:${EMULATOR_CONSOLE_PORT}"
	)" || {
		log ERROR "isolated emulator console command failed"
		exit 1
	}
	console_output="${console_output//$'\r'/}"
	if ! ok_count="$(grep -c '^OK$' <<<"$console_output")"; then
		ok_count=0
	fi
	((ok_count >= EMULATOR_CONSOLE_MINIMUM_OK_RESPONSES)) || {
		log ERROR "isolated emulator console rejected a validated command"
		exit 1
	}
}

emulator_geo_fix() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator GPS injection is only supported on the isolated emulator"
		exit 1
	}
	validate_decimal_range 180 -180 EMULATOR_GEO_LONGITUDE "$EMULATOR_GEO_LONGITUDE"
	validate_decimal_range 90 -90 EMULATOR_GEO_LATITUDE "$EMULATOR_GEO_LATITUDE"
	setup_adb
	wait_for_boot
	send_emulator_console_command "geo fix ${EMULATOR_GEO_LONGITUDE} ${EMULATOR_GEO_LATITUDE}"
	log INFO "emulator GPS fix injected"
}

emulator_sensor_set() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator sensor injection is only supported on the isolated emulator"
		exit 1
	}
	[[ "$EMULATOR_SENSOR_NAME" =~ $EMULATOR_SENSOR_NAME_PATTERN ]] || {
		log ERROR "EMULATOR_SENSOR_NAME must be a supported emulator sensor name"
		exit 1
	}
	[[ "$EMULATOR_SENSOR_VALUES" =~ $EMULATOR_SENSOR_VALUES_PATTERN ]] || {
		log ERROR "EMULATOR_SENSOR_VALUES must contain exactly three finite decimal values"
		exit 1
	}
	setup_adb
	wait_for_boot
	send_emulator_console_command "sensor set ${EMULATOR_SENSOR_NAME} ${EMULATOR_SENSOR_VALUES}"
	log INFO "emulator sensor values injected"
}

emulator_sms_send() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator SMS injection is only supported on the isolated emulator"
		exit 1
	}
	[[ "$EMULATOR_SMS_SENDER" =~ $EMULATOR_SMS_SENDER_PATTERN ]] || {
		log ERROR "EMULATOR_SMS_SENDER must contain 1 through 32 digits"
		exit 1
	}
	[[ -n "$EMULATOR_SMS_BODY" && "${#EMULATOR_SMS_BODY}" -le "$EMULATOR_SMS_BODY_MAXIMUM_CHARACTERS" &&
		"$EMULATOR_SMS_BODY" != *$'\n'* && "$EMULATOR_SMS_BODY" != *$'\r'* ]] || {
		log ERROR "EMULATOR_SMS_BODY must be non-empty, at most ${EMULATOR_SMS_BODY_MAXIMUM_CHARACTERS} characters, and one line"
		exit 1
	}
	setup_adb
	wait_for_boot
	send_emulator_console_command "sms send ${EMULATOR_SMS_SENDER} ${EMULATOR_SMS_BODY}"
	log INFO "isolated emulator SMS injected"
}

emulator_power_set() {
	local battery_ac
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator power injection is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_POWER_AC" in
	"$EMULATOR_POWER_AC_ON") battery_ac="$BATTERY_AC_ON" ;;
	"$EMULATOR_POWER_AC_OFF") battery_ac="$BATTERY_AC_OFF" ;;
	*)
		log ERROR "EMULATOR_POWER_AC must be on or off"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	send_emulator_console_command "power ac ${EMULATOR_POWER_AC}"
	adb -s "$SERIAL" shell dumpsys battery set ac "$battery_ac" || {
		log ERROR "could not deliver the emulator battery AC state change"
		exit 1
	}
	log INFO "emulator AC power state injected"
}

wait_for_emulator_wifi_state() {
	local deadline status status_pattern
	local expected_state="$1"
	case "$expected_state" in
	"$EMULATOR_WIFI_CONNECTED") status_pattern="$EMULATOR_WIFI_CONNECTED_STATUS" ;;
	"$EMULATOR_WIFI_DISCONNECTED") status_pattern="$EMULATOR_WIFI_DISABLED_STATUS" ;;
	*)
		log ERROR "unsupported expected emulator WiFi state"
		exit 1
		;;
	esac
	deadline=$((SECONDS + EMULATOR_WIFI_TIMEOUT_SECONDS))
	while ((SECONDS < deadline)); do
		status="$(adb -s "$SERIAL" shell cmd wifi status)" || {
			log ERROR "could not read isolated emulator WiFi state"
			exit 1
		}
		if [[ "$status" == *"$status_pattern"* ]]; then
			return 0
		fi
		sleep "$EMULATOR_WIFI_RETRY_SECONDS"
	done
	log ERROR "isolated emulator did not reach requested WiFi state=$expected_state"
	exit 1
}

emulator_wifi_set() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator WiFi control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_WIFI_STATE" in
	"$EMULATOR_WIFI_CONNECTED")
		setup_adb
		wait_for_boot
		adb -s "$SERIAL" shell cmd wifi set-wifi-enabled enabled || {
			log ERROR "could not enable isolated emulator WiFi"
			exit 1
		}
		adb -s "$SERIAL" shell cmd wifi connect-network "$EMULATOR_WIFI_SSID" "$EMULATOR_WIFI_OPEN_SECURITY" || {
			log ERROR "could not request the isolated emulator built-in WiFi network"
			exit 1
		}
		wait_for_emulator_wifi_state "$EMULATOR_WIFI_CONNECTED"
		;;
	"$EMULATOR_WIFI_DISCONNECTED")
		setup_adb
		wait_for_boot
		adb -s "$SERIAL" shell cmd wifi set-wifi-enabled disabled || {
			log ERROR "could not disable isolated emulator WiFi"
			exit 1
		}
		wait_for_emulator_wifi_state "$EMULATOR_WIFI_DISCONNECTED"
		;;
	*)
		log ERROR "EMULATOR_WIFI_STATE must be connected or disconnected"
		exit 1
		;;
	esac
	log INFO "isolated emulator WiFi state applied state=$EMULATOR_WIFI_STATE"
}

emulator_bluetooth_set() {
	local bluetooth_command wait_command
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator Bluetooth control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_BLUETOOTH_STATE" in
	"$EMULATOR_BLUETOOTH_STATE_ON")
		bluetooth_command="$EMULATOR_BLUETOOTH_ENABLE_COMMAND"
		wait_command="$EMULATOR_BLUETOOTH_WAIT_FOR_ON_COMMAND"
		;;
	"$EMULATOR_BLUETOOTH_STATE_OFF")
		bluetooth_command="$EMULATOR_BLUETOOTH_DISABLE_COMMAND"
		wait_command="$EMULATOR_BLUETOOTH_WAIT_FOR_OFF_COMMAND"
		;;
	*)
		log ERROR "EMULATOR_BLUETOOTH_STATE must be on or off"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell cmd bluetooth_manager "$bluetooth_command" || {
		log ERROR "could not set isolated emulator Bluetooth state=$EMULATOR_BLUETOOTH_STATE"
		exit 1
	}
	timeout "$EMULATOR_BLUETOOTH_TIMEOUT_SECONDS" \
		adb -s "$SERIAL" shell cmd bluetooth_manager "$wait_command" || {
		log ERROR "isolated emulator Bluetooth did not reach state=$EMULATOR_BLUETOOTH_STATE"
		exit 1
	}
	log INFO "isolated emulator Bluetooth state applied state=$EMULATOR_BLUETOOTH_STATE"
}

emulator_thermal_set() {
	local thermal_level
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "thermal service control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_THERMAL_STATE" in
	"$EMULATOR_THERMAL_STATE_RESET") thermal_level='' ;;
	"$EMULATOR_THERMAL_STATE_NONE") thermal_level="$EMULATOR_THERMAL_LEVEL_NONE" ;;
	"$EMULATOR_THERMAL_STATE_LIGHT") thermal_level="$EMULATOR_THERMAL_LEVEL_LIGHT" ;;
	"$EMULATOR_THERMAL_STATE_MODERATE") thermal_level="$EMULATOR_THERMAL_LEVEL_MODERATE" ;;
	"$EMULATOR_THERMAL_STATE_SEVERE") thermal_level="$EMULATOR_THERMAL_LEVEL_SEVERE" ;;
	"$EMULATOR_THERMAL_STATE_CRITICAL") thermal_level="$EMULATOR_THERMAL_LEVEL_CRITICAL" ;;
	"$EMULATOR_THERMAL_STATE_EMERGENCY") thermal_level="$EMULATOR_THERMAL_LEVEL_EMERGENCY" ;;
	"$EMULATOR_THERMAL_STATE_SHUTDOWN") thermal_level="$EMULATOR_THERMAL_LEVEL_SHUTDOWN" ;;
	*)
		log ERROR "EMULATOR_THERMAL_STATE must be reset, none, light, moderate, severe, critical, emergency, or shutdown"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	if [[ "$EMULATOR_THERMAL_STATE" == "$EMULATOR_THERMAL_STATE_RESET" ]]; then
		adb -s "$SERIAL" shell cmd thermalservice reset || {
			log ERROR "could not reset isolated emulator thermal service"
			exit 1
		}
	else
		adb -s "$SERIAL" shell cmd thermalservice override-status "$thermal_level" || {
			log ERROR "could not set isolated emulator thermal state=$EMULATOR_THERMAL_STATE"
			exit 1
		}
	fi
	log INFO "isolated emulator thermal state applied state=$EMULATOR_THERMAL_STATE"
}

emulator_power_save_set() {
	local power_save_mode
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator Battery Saver control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_POWER_SAVE_MODE" in
	"$EMULATOR_POWER_SAVE_MODE_OFF") power_save_mode="$EMULATOR_POWER_SAVE_MODE_OFF_VALUE" ;;
	"$EMULATOR_POWER_SAVE_MODE_ON") power_save_mode="$EMULATOR_POWER_SAVE_MODE_ON_VALUE" ;;
	*)
		log ERROR "EMULATOR_POWER_SAVE_MODE must be on or off"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell cmd power set-mode "$power_save_mode" || {
		log ERROR "could not set isolated emulator Battery Saver state=$EMULATOR_POWER_SAVE_MODE"
		exit 1
	}
	log INFO "isolated emulator Battery Saver state applied state=$EMULATOR_POWER_SAVE_MODE"
}

emulator_device_idle_set() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator device-idle control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_DEVICE_IDLE_MODE" in
	"$EMULATOR_DEVICE_IDLE_MODE_ACTIVE" | "$EMULATOR_DEVICE_IDLE_MODE_IDLE") ;;
	*)
		log ERROR "EMULATOR_DEVICE_IDLE_MODE must be active or idle"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	if [[ "$EMULATOR_DEVICE_IDLE_MODE" == "$EMULATOR_DEVICE_IDLE_MODE_ACTIVE" ]]; then
		adb -s "$SERIAL" shell cmd deviceidle unforce || {
			log ERROR "could not clear isolated emulator device idle"
			exit 1
		}
	else
		adb -s "$SERIAL" shell cmd deviceidle force-idle "$EMULATOR_DEVICE_IDLE_MODE_IDLE_DEPTH" || {
			log ERROR "could not force isolated emulator device idle"
			exit 1
		}
	fi
	log INFO "isolated emulator device idle state applied state=$EMULATOR_DEVICE_IDLE_MODE"
}

emulator_night_mode_set() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator night-mode control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_NIGHT_MODE" in
	"$EMULATOR_NIGHT_MODE_AUTO" | "$EMULATOR_NIGHT_MODE_NO" | "$EMULATOR_NIGHT_MODE_YES") ;;
	*)
		log ERROR "EMULATOR_NIGHT_MODE must be yes, no, or auto"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell cmd uimode night "$EMULATOR_NIGHT_MODE" || {
		log ERROR "could not set isolated emulator night mode=$EMULATOR_NIGHT_MODE"
		exit 1
	}
	log INFO "isolated emulator night mode applied mode=$EMULATOR_NIGHT_MODE"
}

emulator_device_orientation_set() {
	local rotation
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator device-configuration control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_DEVICE_ORIENTATION" in
	"$EMULATOR_DEVICE_ORIENTATION_PORTRAIT") rotation="$EMULATOR_DEVICE_ROTATION_PORTRAIT" ;;
	"$EMULATOR_DEVICE_ORIENTATION_LANDSCAPE") rotation="$EMULATOR_DEVICE_ROTATION_LANDSCAPE" ;;
	*)
		log ERROR "EMULATOR_DEVICE_ORIENTATION must be portrait or landscape"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell settings put system "$EMULATOR_DEVICE_ROTATION_SETTING" "$EMULATOR_DEVICE_ROTATION_LOCKED" || {
		log ERROR "could not lock isolated emulator device rotation"
		exit 1
	}
	adb -s "$SERIAL" shell settings put system "$EMULATOR_USER_ROTATION_SETTING" "$rotation" || {
		log ERROR "could not set isolated emulator orientation=$EMULATOR_DEVICE_ORIENTATION"
		exit 1
	}
	log INFO "isolated emulator device orientation applied orientation=$EMULATOR_DEVICE_ORIENTATION"
}

emulator_font_scale_set() {
	local font_scale
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator font-scale control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_FONT_SCALE_PERCENT" in
	"$EMULATOR_FONT_SCALE_PERCENT_SMALL") font_scale="$EMULATOR_FONT_SCALE_VALUE_SMALL" ;;
	"$EMULATOR_FONT_SCALE_PERCENT_BASELINE") font_scale="$EMULATOR_FONT_SCALE_VALUE_BASELINE" ;;
	"$EMULATOR_FONT_SCALE_PERCENT_ENLARGED") font_scale="$EMULATOR_FONT_SCALE_VALUE_ENLARGED" ;;
	*)
		log ERROR "EMULATOR_FONT_SCALE_PERCENT must be 85, 100, or 130"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell settings put system "$EMULATOR_FONT_SCALE_SETTING" "$font_scale" || {
		log ERROR "could not set isolated emulator font scale percent=$EMULATOR_FONT_SCALE_PERCENT"
		exit 1
	}
	log INFO "isolated emulator font scale applied percent=$EMULATOR_FONT_SCALE_PERCENT"
}

emulator_ringer_mode_set() {
	local ringer_mode_command
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator ringer-mode control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_RINGER_MODE" in
	"$EMULATOR_RINGER_MODE_NORMAL") ringer_mode_command="$EMULATOR_RINGER_MODE_NORMAL_COMMAND" ;;
	"$EMULATOR_RINGER_MODE_SILENT") ringer_mode_command="$EMULATOR_RINGER_MODE_SILENT_COMMAND" ;;
	"$EMULATOR_RINGER_MODE_VIBRATE") ringer_mode_command="$EMULATOR_RINGER_MODE_VIBRATE_COMMAND" ;;
	*)
		log ERROR "EMULATOR_RINGER_MODE must be normal, silent, or vibrate"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell cmd audio set-ringer-mode "$ringer_mode_command" || {
		log ERROR "could not set isolated emulator ringer mode=$EMULATOR_RINGER_MODE"
		exit 1
	}
	log INFO "isolated emulator ringer mode applied mode=$EMULATOR_RINGER_MODE"
}

emulator_notification_policy_access_set() {
	local notification_policy_access_command
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator Notification Policy access control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_NOTIFICATION_POLICY_ACCESS" in
	"$EMULATOR_NOTIFICATION_POLICY_ACCESS_GRANTED") notification_policy_access_command="$EMULATOR_NOTIFICATION_POLICY_ACCESS_GRANTED_COMMAND" ;;
	"$EMULATOR_NOTIFICATION_POLICY_ACCESS_REVOKED") notification_policy_access_command="$EMULATOR_NOTIFICATION_POLICY_ACCESS_REVOKED_COMMAND" ;;
	*)
		log ERROR "EMULATOR_NOTIFICATION_POLICY_ACCESS must be granted or revoked"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell cmd notification "$notification_policy_access_command" "$PACKAGE_NAME" || {
		log ERROR "could not set isolated emulator Notification Policy access=$EMULATOR_NOTIFICATION_POLICY_ACCESS"
		exit 1
	}
	log INFO "isolated emulator Notification Policy access applied state=$EMULATOR_NOTIFICATION_POLICY_ACCESS"
}

emulator_interruption_filter_set() {
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "emulator interruption-filter control is only supported on the isolated emulator"
		exit 1
	}
	case "$EMULATOR_INTERRUPTION_FILTER" in
	"$EMULATOR_INTERRUPTION_FILTER_ALL" | "$EMULATOR_INTERRUPTION_FILTER_PRIORITY" | "$EMULATOR_INTERRUPTION_FILTER_ALARMS" | "$EMULATOR_INTERRUPTION_FILTER_NONE") ;;
	*)
		log ERROR "EMULATOR_INTERRUPTION_FILTER must be all, priority, alarms, or none"
		exit 1
		;;
	esac
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell cmd notification set_dnd "$EMULATOR_INTERRUPTION_FILTER" || {
		log ERROR "could not set isolated emulator interruption filter=$EMULATOR_INTERRUPTION_FILTER"
		exit 1
	}
	log INFO "isolated emulator interruption filter applied mode=$EMULATOR_INTERRUPTION_FILTER"
}

calendar_fixture_calendar_ids() {
	local rows
	rows="$(adb -s "$SERIAL" shell \
		"content query --uri '$CALENDAR_CALENDARS_URI' \
		--projection '$CALENDAR_ID_COLUMN' \
		--where \"$CALENDAR_ACCOUNT_SELECTION\"")" || {
		log ERROR "could not query the fixed isolated-emulator Calendar fixture"
		return 1
	}
	sed -n -E 's/^Row: [0-9]+ _id=([0-9]+)$/\1/p' <<<"$rows"
}

calendar_fixture_calendar_id() {
	local calendar_ids
	calendar_ids="$(calendar_fixture_calendar_ids)" || return 1
	[[ -n "$calendar_ids" && "$calendar_ids" != *$'\n'* ]] || {
		log ERROR "fixed isolated-emulator Calendar fixture does not have exactly one calendar"
		return 1
	}
	[[ "$calendar_ids" =~ ^[0-9]+$ ]] || {
		log ERROR "fixed isolated-emulator Calendar fixture returned an invalid calendar identifier"
		return 1
	}
	printf '%s\n' "$calendar_ids"
}

calendar_fixture_event_id() {
	local calendar_id rows event_id
	calendar_id="$(calendar_fixture_calendar_id)" || return 1
	rows="$(adb -s "$SERIAL" shell \
		"content query --uri '$CALENDAR_EVENTS_URI' \
		--projection '$CALENDAR_ID_COLUMN' \
		--where \"calendar_id=${calendar_id}\"")" || {
		log ERROR "could not query the fixed isolated-emulator Calendar event"
		return 1
	}
	event_id="$(sed -n -E 's/^Row: [0-9]+ _id=([0-9]+)$/\1/p' <<<"$rows")"
	[[ -n "$event_id" && "$event_id" != *$'\n'* && "$event_id" =~ ^[0-9]+$ ]] || {
		log ERROR "fixed isolated-emulator Calendar fixture does not have exactly one event"
		return 1
	}
	printf '%s\n' "$event_id"
}

delete_calendar_fixture_calendar() {
	local calendar_id="$1"
	[[ "$calendar_id" =~ ^[0-9]+$ ]] || {
		log ERROR "fixed isolated-emulator Calendar fixture calendar identifier is invalid"
		return 1
	}
	adb -s "$SERIAL" shell \
		"content delete --uri '$CALENDAR_EVENTS_URI' \
		--where \"calendar_id=${calendar_id}\"" || {
		log ERROR "could not delete fixed isolated-emulator Calendar fixture events"
		return 1
	}
	adb -s "$SERIAL" shell \
		"content delete --uri '$CALENDAR_SYNC_URI' \
		--where \"_id=${calendar_id}\"" || {
		log ERROR "could not delete fixed isolated-emulator Calendar fixture calendar"
		return 1
	}
}

calendar_fixture_delete() {
	local calendar_ids calendar_id
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "Calendar fixture control is only supported on the isolated emulator"
		return 1
	}
	setup_adb
	wait_for_boot
	calendar_ids="$(calendar_fixture_calendar_ids)" || return 1
	if [[ -z "$calendar_ids" ]]; then
		log INFO "fixed isolated-emulator Calendar fixture is already absent"
		return 0
	fi
	while IFS= read -r calendar_id; do
		delete_calendar_fixture_calendar "$calendar_id" || return 1
	done <<<"$calendar_ids"
	log INFO "fixed isolated-emulator Calendar fixture deleted"
}

calendar_fixture_create() {
	local calendar_id
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "Calendar fixture control is only supported on the isolated emulator"
		return 1
	}
	calendar_fixture_delete
	adb -s "$SERIAL" shell \
		"content insert --uri '$CALENDAR_SYNC_URI' \
		--bind \"account_name:s:${CALENDAR_ACCOUNT_NAME}\" \
		--bind \"account_type:s:${CALENDAR_ACCOUNT_TYPE}\" \
		--bind \"name:s:${CALENDAR_NAME}\" \
		--bind \"calendar_displayName:s:${CALENDAR_NAME}\" \
		--bind calendar_color:i:16711680 \
		--bind calendar_access_level:i:700 \
		--bind \"ownerAccount:s:${CALENDAR_ACCOUNT_NAME}\" \
		--bind sync_events:i:1" || {
		log ERROR "could not create fixed isolated-emulator Calendar fixture calendar"
		return 1
	}
	calendar_id="$(calendar_fixture_calendar_id)" || return 1
	adb -s "$SERIAL" shell \
		"content insert --uri '$CALENDAR_EVENTS_URI' \
		--bind \"calendar_id:l:${calendar_id}\" \
		--bind \"title:s:${CALENDAR_EVENT_TITLE}\" \
		--bind \"description:s:${CALENDAR_EVENT_DESCRIPTION}\" \
		--bind \"eventLocation:s:${CALENDAR_EVENT_LOCATION}\" \
		--bind \"dtstart:l:${CALENDAR_EVENT_START_MILLISECONDS}\" \
		--bind \"dtend:l:${CALENDAR_EVENT_END_MILLISECONDS}\" \
		--bind eventTimezone:s:UTC \
		--bind allDay:i:0" || {
		log ERROR "could not create fixed isolated-emulator Calendar fixture event"
		return 1
	}
	calendar_fixture_event_id >/dev/null
	log INFO "fixed isolated-emulator Calendar fixture created"
}

calendar_fixture_update() {
	local event_id
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "Calendar fixture control is only supported on the isolated emulator"
		return 1
	}
	setup_adb
	wait_for_boot
	event_id="$(calendar_fixture_event_id)" || return 1
	adb -s "$SERIAL" shell \
		"content update --uri '$CALENDAR_EVENTS_URI' \
		--where \"_id=${event_id}\" \
		--bind \"title:s:${CALENDAR_EVENT_UPDATED_TITLE}\" \
		--bind \"description:s:${CALENDAR_EVENT_UPDATED_DESCRIPTION}\" \
		--bind \"eventLocation:s:${CALENDAR_EVENT_UPDATED_LOCATION}\" \
		--bind \"dtend:l:${CALENDAR_EVENT_UPDATED_END_MILLISECONDS}\"" || {
		log ERROR "could not update fixed isolated-emulator Calendar fixture event"
		return 1
	}
	log INFO "fixed isolated-emulator Calendar fixture updated"
}

contacts_fixture_raw_contact_ids() {
	local rows
	rows="$(adb -s "$SERIAL" shell \
		"content query --uri '$CONTACTS_RAW_CONTACTS_URI' \
		--projection '$CONTACTS_RAW_CONTACT_ID_COLUMN' \
		--where \"$CONTACTS_RAW_CONTACT_SELECTION\"")" || {
		log ERROR "could not query the fixed isolated-emulator contacts fixture"
		return 1
	}
	sed -n -E 's/^Row: [0-9]+ _id=([0-9]+)$/\1/p' <<<"$rows"
}

delete_contacts_fixture_raw_contact() {
	local raw_contact_id="$1"
	[[ "$raw_contact_id" =~ ^[0-9]+$ ]] || {
		log ERROR "fixed isolated-emulator contacts fixture identifier is invalid"
		return 1
	}
	adb -s "$SERIAL" shell \
		"content delete --uri '$CONTACTS_RAW_CONTACT_SYNC_URI' --where \"_id=${raw_contact_id}\"" || {
		log ERROR "could not delete fixed isolated-emulator contacts fixture"
		return 1
	}
}

contacts_fixture_delete() {
	local raw_contact_ids raw_contact_id
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "contacts fixture control is only supported on the isolated emulator"
		return 1
	}
	setup_adb
	wait_for_boot
	raw_contact_ids="$(contacts_fixture_raw_contact_ids)" || return 1
	if [[ -z "$raw_contact_ids" ]]; then
		log INFO "fixed isolated-emulator contacts fixture is already absent"
		return 0
	fi
	while IFS= read -r raw_contact_id; do
		delete_contacts_fixture_raw_contact "$raw_contact_id" || return 1
	done <<<"$raw_contact_ids"
	log INFO "fixed isolated-emulator contacts fixture deleted"
}

contacts_fixture_create() {
	local raw_contact_ids raw_contact_id
	[[ "$TEST_REAL" == 0 ]] || {
		log ERROR "contacts fixture control is only supported on the isolated emulator"
		return 1
	}
	contacts_fixture_delete
	adb -s "$SERIAL" shell \
		"content insert --uri '$CONTACTS_RAW_CONTACT_SYNC_URI' \
		--bind \"account_name:s:${CONTACTS_ACCOUNT_NAME}\" \
		--bind \"account_type:s:${CONTACTS_ACCOUNT_TYPE}\" \
		--bind \"sourceid:s:${CONTACTS_SOURCE_ID}\"" || {
		log ERROR "could not create fixed isolated-emulator contacts raw contact"
		return 1
	}
	raw_contact_ids="$(contacts_fixture_raw_contact_ids)" || return 1
	[[ -n "$raw_contact_ids" && "$raw_contact_ids" != *$'\n'* ]] || {
		log ERROR "fixed isolated-emulator contacts fixture does not have exactly one raw contact"
		return 1
	}
	raw_contact_id="$raw_contact_ids"
	adb -s "$SERIAL" shell \
		"content insert --uri '$CONTACTS_DATA_URI' \
		--bind \"raw_contact_id:l:${raw_contact_id}\" \
		--bind \"mimetype:s:${CONTACTS_NAME_MIME_TYPE}\" \
		--bind \"data1:s:${CONTACTS_DISPLAY_NAME}\"" || {
		log ERROR "could not create fixed isolated-emulator contacts name"
		return 1
	}
	log INFO "fixed isolated-emulator contacts fixture created"
}

validate_file_transfer_paths() {
	[[ "$DEVICE_FILE" =~ $DEVICE_FILE_PATTERN ]] || {
		log ERROR "DEVICE_FILE must be a simple absolute path under /sdcard"
		exit 1
	}
	[[ "$ARTIFACT_FILE" =~ $ARTIFACT_FILE_PATTERN ]] || {
		log ERROR "ARTIFACT_FILE must be a simple filename"
		exit 1
	}
}

pull_device_file() {
	local artifact_path
	validate_file_transfer_paths
	setup_adb
	wait_for_boot
	artifact_path="$ARTIFACT_DIR/$ARTIFACT_FILE"
	adb -s "$SERIAL" pull "$DEVICE_FILE" "$artifact_path" || {
		log ERROR "could not pull requested device file"
		exit 1
	}
	[[ -s "$artifact_path" ]] || {
		log ERROR "pulled device file is empty"
		exit 1
	}
	log INFO "device file pulled into ${ARTIFACT_DIR}"
}

push_device_file() {
	local artifact_path
	validate_file_transfer_paths
	artifact_path="$ARTIFACT_DIR/$ARTIFACT_FILE"
	[[ -s "$artifact_path" ]] || {
		log ERROR "artifact file is absent or empty"
		exit 1
	}
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" push "$artifact_path" "$DEVICE_FILE" || {
		log ERROR "could not push requested artifact file"
		exit 1
	}
	log INFO "artifact file pushed into $(device_description)"
}

start_forward_test_listener() {
	local device_port
	device_port="${ANDROID_LAB_FORWARD_DEVICE_PORT:-}"
	validate_tcp_port ANDROID_LAB_FORWARD_DEVICE_PORT "$device_port"
	setup_adb
	wait_for_boot
	adb -s "$SERIAL" shell \
		"toybox nc -s 127.0.0.1 -p ${device_port} -L sh -c 'true' >/dev/null 2>&1 &"
	timeout 5 adb -s "$SERIAL" shell \
		"toybox nc -z -w 2 127.0.0.1 ${device_port}" || {
		log ERROR "could not start the device-loopback test listener"
		exit 1
	}
	log INFO "device-loopback test listener is ready"
}

configure_control_forward() {
	local device_port host_port
	[[ "$TEST_REAL" == 1 ]] || {
		log ERROR "control forwarding is only available for the configured real device"
		exit 1
	}
	device_port="${ANDROID_LAB_FORWARD_DEVICE_PORT:-$CONTROL_FORWARD_DEFAULT_DEVICE_PORT}"
	host_port="${ANDROID_LAB_FORWARD_HOST_PORT:-$CONTROL_FORWARD_DEFAULT_HOST_PORT}"
	validate_tcp_port ANDROID_LAB_FORWARD_DEVICE_PORT "$device_port"
	validate_tcp_port ANDROID_LAB_FORWARD_HOST_PORT "$host_port"
	setup_adb
	adb -s "$SERIAL" forward --remove "tcp:$host_port" >/dev/null 2>&1 || :
	adb -s "$SERIAL" forward "tcp:$host_port" "tcp:$device_port" || {
		log ERROR "could not create the local physical-device control forward"
		exit 1
	}
	log INFO "physical-device control forward is active only inside this controller"
}

remove_control_forward() {
	local host_port
	[[ "$TEST_REAL" == 1 ]] || {
		log ERROR "control forwarding is only available for the configured real device"
		exit 1
	}
	host_port="${ANDROID_LAB_FORWARD_HOST_PORT:-$CONTROL_FORWARD_DEFAULT_HOST_PORT}"
	validate_tcp_port ANDROID_LAB_FORWARD_HOST_PORT "$host_port"
	setup_adb
	adb -s "$SERIAL" forward --remove "tcp:$host_port" >/dev/null 2>&1 || :
	log INFO "physical-device control forward removed"
}

case "$COMMAND" in
wait)
	setup_adb
	wait_for_boot
	;;
device-info)
	device_info
	;;
provider-inventory)
	provider_inventory
	;;
unlock)
	unlock_physical_device
	;;
talkback-on)
	enable_talkback
	;;
talkback-off)
	disable_talkback
	;;
accessibility-on)
	set_app_accessibility "$ACCESSIBILITY_STATE_ON"
	;;
accessibility-off)
	set_app_accessibility "$ACCESSIBILITY_STATE_OFF"
	;;
install)
	install_apk
	;;
screenshot)
	capture_screenshot
	;;
uiautomator-dump)
	dump_uiautomator
	;;
ui-layout)
	write_ui_layout
	;;
uiautomator-run)
	run_instrumentation
	;;
app-current)
	app_current
	;;
app-start)
	app_start
	;;
home-role-set)
	set_home_role
	;;
home-start)
	start_home
	;;
configure-navigation)
	configure_navigation
	;;
app-stop)
	app_stop
	;;
app-uninstall)
	app_uninstall
	;;
device-shell)
	device_shell
	;;
emulator-geo-fix)
	emulator_geo_fix
	;;
emulator-sensor-set)
	emulator_sensor_set
	;;
emulator-sms-send)
	emulator_sms_send
	;;
emulator-power-set)
	emulator_power_set
	;;
emulator-wifi-set)
	emulator_wifi_set
	;;
emulator-bluetooth-set)
	emulator_bluetooth_set
	;;
emulator-thermal-set)
	emulator_thermal_set
	;;
emulator-power-save-set)
	emulator_power_save_set
	;;
emulator-device-idle-set)
	emulator_device_idle_set
	;;
emulator-night-mode-set)
	emulator_night_mode_set
	;;
emulator-device-orientation-set)
	emulator_device_orientation_set
	;;
emulator-font-scale-set)
	emulator_font_scale_set
	;;
emulator-ringer-mode-set)
	emulator_ringer_mode_set
	;;
emulator-notification-policy-access-set)
	emulator_notification_policy_access_set
	;;
emulator-interruption-filter-set)
	emulator_interruption_filter_set
	;;
calendar-fixture-create)
	calendar_fixture_create
	;;
calendar-fixture-update)
	calendar_fixture_update
	;;
calendar-fixture-delete)
	calendar_fixture_delete
	;;
contacts-fixture-create)
	contacts_fixture_create
	;;
contacts-fixture-delete)
	contacts_fixture_delete
	;;
file-pull)
	pull_device_file
	;;
file-push)
	push_device_file
	;;
forward-test-listener)
	start_forward_test_listener
	;;
control-forward)
	configure_control_forward
	;;
control-unforward)
	remove_control_forward
	;;
*)
	log ERROR "unsupported device operation=${COMMAND}"
	exit 1
	;;
esac
