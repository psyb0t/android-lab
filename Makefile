SHELL := /bin/bash
.DEFAULT_GOAL := help
VERSION := $(shell cat VERSION)
ANDROID_API ?= 36
DEV_IMAGE ?= android-lab:$(VERSION)
EMULATOR_IMAGE ?= android-lab:$(VERSION)-emulator-api$(ANDROID_API)
ANDROID_PROJECT ?= .
GRADLE_TASK ?= :app:assembleDebug
ANDROID_LAB_LICENSE_MARKER := .android-lab/licenses/android-sdk-license.accepted
ANDROID_LAB_ACCEPT_ANDROID_LICENSES ?= $(if $(wildcard $(ANDROID_LAB_LICENSE_MARKER)),yes,)
ANDROID_LAB_UID := $(shell id -u)
ANDROID_LAB_GID := $(shell id -g)
ANDROID_LAB_SOCKET_GID := $(shell stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 0)
ANDROID_LAB_TOOL_CPU_LIMIT ?= $(shell docker info --format '{{.NCPU}}' | awk -v maximum=10 '{print ($$1 < maximum ? $$1 : maximum)}')
ANDROID_LAB_GRADLE_MAX_WORKERS ?= $(shell printf '%s\n' '$(ANDROID_LAB_TOOL_CPU_LIMIT)' | awk '{print ($$1 < 1 ? 1 : int($$1))}')
ANDROID_LAB_TOOL_MEMORY_LIMIT ?= 8g
ANDROID_LAB_TOOL_PIDS_LIMIT ?= 2048
export ANDROID_PROJECT GRADLE_TASK ANDROID_LAB_GRADLE_MAX_WORKERS

DEVICE_ENV := APK TEST_APK TEST_RUNNER PACKAGE_NAME ACTIVITY DEVICE_COMMAND DEVICE_FILE ARTIFACT_FILE \
	ANDROID_LAB_FORWARD_HOST_PORT ANDROID_LAB_FORWARD_DEVICE_PORT \
	ANDROID_LAB_MCP_HOST_PORT ANDROID_LAB_MCP_DEVICE_PORT ANDROID_LAB_VNC_HOST_PORT \
	ANDROID_LAB_COMPOSE_PROJECT ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS \
	ANDROID_LAB_FORCE_NAVIGATION_REBOOT \
	EMULATOR_GEO_LATITUDE EMULATOR_GEO_LONGITUDE EMULATOR_SENSOR_NAME EMULATOR_SENSOR_VALUES \
	EMULATOR_SMS_SENDER EMULATOR_SMS_BODY EMULATOR_POWER_AC EMULATOR_WIFI_STATE \
	EMULATOR_BLUETOOTH_STATE EMULATOR_THERMAL_STATE EMULATOR_POWER_SAVE_MODE EMULATOR_DEVICE_IDLE_MODE \
	EMULATOR_NIGHT_MODE EMULATOR_DEVICE_ORIENTATION EMULATOR_FONT_SCALE_PERCENT \
	EMULATOR_RINGER_MODE EMULATOR_NOTIFICATION_POLICY_ACCESS EMULATOR_INTERRUPTION_FILTER
export $(DEVICE_ENV)

DEV_RUN := docker run --rm --init --user $(ANDROID_LAB_UID):$(ANDROID_LAB_GID) \
	--cpus $(ANDROID_LAB_TOOL_CPU_LIMIT) --memory $(ANDROID_LAB_TOOL_MEMORY_LIMIT) --memory-swap $(ANDROID_LAB_TOOL_MEMORY_LIMIT) --pids-limit $(ANDROID_LAB_TOOL_PIDS_LIMIT) \
	-e HOME=/tmp -e ANDROID_LAB_WORKSPACE=/work -e ANDROID_PROJECT -e GRADLE_TASK -e ANDROID_LAB_GRADLE_MAX_WORKERS \
	-v "$(CURDIR):/work" -w /work $(DEV_IMAGE)
DEV_RUN_DIND := docker run --rm --init --user $(ANDROID_LAB_UID):$(ANDROID_LAB_GID) --group-add $(ANDROID_LAB_SOCKET_GID) \
	--cpus $(ANDROID_LAB_TOOL_CPU_LIMIT) --memory $(ANDROID_LAB_TOOL_MEMORY_LIMIT) --memory-swap $(ANDROID_LAB_TOOL_MEMORY_LIMIT) --pids-limit $(ANDROID_LAB_TOOL_PIDS_LIMIT) \
	-e HOME=/tmp -e ANDROID_LAB_WORKSPACE="$(CURDIR)" -e ANDROID_LAB_DEV_IMAGE=$(DEV_IMAGE) -e ANDROID_LAB_EMULATOR_IMAGE=$(EMULATOR_IMAGE) \
	-e ANDROID_LAB_UID=$(ANDROID_LAB_UID) -e ANDROID_LAB_GID=$(ANDROID_LAB_GID) -e ANDROID_LAB_API=$(ANDROID_API) \
	-e ANDROID_LAB_ACCEPT_ANDROID_LICENSES=$(ANDROID_LAB_ACCEPT_ANDROID_LICENSES) \
	$(foreach variable,$(DEVICE_ENV),-e $(variable)) \
	-v "$(CURDIR):$(CURDIR)" -v /var/run/docker.sock:/var/run/docker.sock -w "$(CURDIR)" $(DEV_IMAGE)

DEVICE_TARGETS := device-info apk-install screenshot uiautomator-dump ui-layout uiautomator-run app-current app-start app-stop \
	home-role-set home-start device-shell emulator-geo-fix emulator-sensor-set emulator-sms-send emulator-power-set \
	emulator-wifi-set emulator-bluetooth-set emulator-thermal-set emulator-power-save-set emulator-device-idle-set \
	emulator-night-mode-set emulator-device-orientation-set emulator-font-scale-set emulator-ringer-mode-set \
	emulator-notification-policy-access-set emulator-interruption-filter-set accessibility-on accessibility-off \
	calendar-fixture-create calendar-fixture-update calendar-fixture-delete contacts-fixture-create contacts-fixture-delete file-pull file-push
.PHONY: help build dev-image image accept-licenses ensure-dev-image emulator-ready shell gradle app-build app-test app-lint \
	lint format test audit-compose run restart stop status forward unforward test-emulator test-forward test-vnc version navigation-buttons clean $(DEVICE_TARGETS)

help: ## List lab operations
	@grep -E '^[a-zA-Z_-]+:.*## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "%-22s %s\n", $$1, $$2}' | sort
	@printf '%s\n' "Device operations: $(DEVICE_TARGETS)"

accept-licenses: ## Record explicit acceptance of the Android SDK license
	@test "$(ANDROID_LAB_ACCEPT_ANDROID_LICENSES)" = yes || { printf '%s\n' 'Read https://developer.android.com/studio/terms, then set ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes.' >&2; exit 1; }
	@mkdir -p "$(dir $(ANDROID_LAB_LICENSE_MARKER))"
	@printf '%s\n' accepted >"$(ANDROID_LAB_LICENSE_MARKER)"
	@chmod 0600 "$(ANDROID_LAB_LICENSE_MARKER)"

dev-image: ## Build the SDK/tooling image locally, reusing cached dependency layers
	@test "$(ANDROID_LAB_ACCEPT_ANDROID_LICENSES)" = yes || { printf '%s\n' 'Run ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes make accept-licenses after reading the SDK license.' >&2; exit 1; }
	@docker build --build-arg ANDROID_API=$(ANDROID_API) --build-arg ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes --file Dockerfile.dev --tag $(DEV_IMAGE) .

ensure-dev-image: ## Require the locally built tooling image
	@docker image inspect "$(DEV_IMAGE)" >/dev/null 2>&1 || { printf '%s\n' "Missing local image: $(DEV_IMAGE). Run make build in the Android Lab checkout." >&2; exit 1; }

image: ensure-dev-image ## Build the emulator image locally from verified Google artifacts
	@$(DEV_RUN_DIND) bash "$(CURDIR)/scripts/build-emulator-image.sh"

build: dev-image image ## Build both versioned local images

emulator-ready: ensure-dev-image ## Require the matching locally built emulator image
	@docker image inspect "$(EMULATOR_IMAGE)" >/dev/null 2>&1 || { printf '%s\n' "Missing local image: $(EMULATOR_IMAGE). Run make build in the Android Lab checkout." >&2; exit 1; }

shell: ensure-dev-image ## Enter the tooling image without a Docker socket
	@$(subst --rm,--rm -it,$(DEV_RUN)) bash

gradle: ensure-dev-image ## Run one checked Gradle task in the selected workspace project
	@$(DEV_RUN) android-lab gradle
app-build: GRADLE_TASK := :app:assembleDebug
app-build: gradle ## Assemble the selected app's debug variant
app-test: GRADLE_TASK := :app:testDebugUnitTest
app-test: gradle ## Run the selected app's debug unit tests
app-lint: GRADLE_TASK := :app:lintDebug
app-lint: gradle ## Lint the selected app's debug variant

lint: ensure-dev-image ## Check shell syntax, formatting and Python compilation
	@$(DEV_RUN) bash /work/scripts/lint.sh
format: ensure-dev-image ## Format the lab's own sources
	@$(DEV_RUN) bash /work/scripts/format.sh
test: audit-compose ## Test the embedded commands and private Compose configuration
audit-compose: ensure-dev-image ## Exercise the image's embedded fixture and Compose contracts
	@$(DEV_RUN) android-lab check

run: emulator-ready ## Start the persistent emulator and loopback browser viewer
	@$(DEV_RUN_DIND) android-lab start
restart: emulator-ready ## Stop and start the persistent emulator without resetting its disk
	@$(DEV_RUN_DIND) android-lab restart
stop: ensure-dev-image ## Stop only this workspace's lab stack without deleting state
	@$(DEV_RUN_DIND) android-lab stop
status: ensure-dev-image ## Show this workspace's lab services
	@$(DEV_RUN_DIND) android-lab status
forward: emulator-ready ## Forward device-local listeners to host loopback
	@$(DEV_RUN_DIND) android-lab forward
unforward: ensure-dev-image ## Stop this workspace's forwarding service
	@$(DEV_RUN_DIND) android-lab unforward

$(DEVICE_TARGETS): ensure-dev-image
	@$(DEV_RUN_DIND) android-lab $@

navigation-buttons: ensure-dev-image ## Configure Android three-button navigation on this emulator
	@$(DEV_RUN_DIND) android-lab configure-navigation
clean: ensure-dev-image ## Remove transient lab files and empty directories without deleting the phone disk
	@$(DEV_RUN) android-lab clean

test-emulator test-forward test-vnc: emulator-ready ## Run a live lab check and stop its stack afterwards
	@$(DEV_RUN_DIND) android-lab $@
version: ## Print the local image version
	@cat VERSION
