# Integrate Android Lab

## Local image contract

Build a selected release with `make build` after accepting the Android SDK license. `VERSION` controls both local tags: `android-lab:<version>` and `android-lab:<version>-emulator-api<api>`. No workflow pushes either image. Rebuild after updating the checkout; Docker caches unchanged layers.

The tools live in `/opt/android-lab`. `android-lab version`, `android-lab gradle`, `android-lab check` and `android-lab <device-operation>` call those embedded scripts. A derived image keeps the same interface.

## Workspace and state

`ANDROID_LAB_WORKSPACE` selects the mounted project root, defaulting to the current directory. `ANDROID_PROJECT` selects a relative directory within it, including `.`. The Gradle runner rejects escaping symlinks and traversal, requires an executable wrapper with its distribution checksum, and accepts one fully qualified task through `GRADLE_TASK`. `ANDROID_LAB_GRADLE_MAX_WORKERS` accepts 1 through 10. Make derives its default from the tool CPU limit; a direct CLI call defaults to 10.

Gradle cache and debug-signing identity live in `.android-lab/gradle/` and `.android-lab/java-home/`. Phone data, ADB keys, forwarding metadata and artifacts live in `.android-lab/shared/`. The lab never binds the caller's home directory. Do not delete this directory to upgrade the tools.

For emulator management, bind the workspace at its identical absolute host path and set `ANDROID_LAB_WORKSPACE` to that path. Compose uses that value as its host source and binds it read-only at `/work` in device helper containers. Mount the host Docker socket and add its group to the controller. The emulator receives `/dev/kvm` and its group. Normal Gradle containers need neither.

The default Compose name is a hash of the workspace path. `ANDROID_LAB_COMPOSE_PROJECT` may override it with a lowercase Docker Compose project name. An existing named stack and its disk must have only one owner.

## Image and runtime settings

| Setting | Meaning |
| --- | --- |
| `DEV_IMAGE`, `EMULATOR_IMAGE` | Make overrides for the local tooling and emulator image tags. |
| `ANDROID_API` | API selected when building locally, default 36. |
| `ANDROID_LAB_ACCEPT_ANDROID_LICENSES` | Explicit `yes` records license acceptance for local builds. |
| `ANDROID_LAB_DEV_IMAGE`, `ANDROID_LAB_EMULATOR_IMAGE` | Required image names for direct lifecycle CLI calls. |
| `ANDROID_LAB_UID`, `ANDROID_LAB_GID` | Required numeric caller identity for lifecycle CLI calls. Make supplies the host UID/GID. |
| `ANDROID_LAB_VNC_HOST_PORT` | Viewer loopback port, default 61326. |
| `ANDROID_LAB_FORWARD_HOST_PORT`, `ANDROID_LAB_FORWARD_DEVICE_PORT` | First tunnel host/device ports, default 19001. |
| `ANDROID_LAB_MCP_HOST_PORT`, `ANDROID_LAB_MCP_DEVICE_PORT` | Second TCP tunnel host/device ports, default 19002. |
| `ANDROID_LAB_TOOL_CPU_LIMIT`, `ANDROID_LAB_TOOL_MEMORY_LIMIT`, `ANDROID_LAB_TOOL_PIDS_LIMIT` | Make's tooling-container bounds. CPU count defaults to the Docker host's capacity, capped at 10; memory and PIDs default to 8g and 2048. |
| `ANDROID_LAB_ACCESSIBILITY_SERVICE_CLASS` | Dotted app service class for explicitly requested accessibility enable/disable operations. |
| `ANDROID_LAB_EXTENSION` | Explicit workspace-relative trusted shell extension, described below. |

`make help` lists device commands. They receive named arguments such as `APK`, `PACKAGE_NAME`, `ACTIVITY`, `DEVICE_COMMAND`, `DEVICE_FILE` and `ARTIFACT_FILE`. Event fixture commands accept their respective `EMULATOR_*` values. Invalid values fail before the device mutation.

## Product extensions

A product that needs app-specific orchestration can select `ANDROID_LAB_EXTENSION=scripts/product-lab.sh`. The lifecycle controller resolves and sources that script only if it stays inside the mounted workspace. This is intentional execution of trusted project code, not a sandbox for uploaded scripts.

The extension defines `android_lab_extension_command <command>`. It can call the generic `start`, `forward`, `compose` and `run_device_operation` functions. Unsupported commands must fail. Product resets, fixtures, control clients and package names belong in the product repository, not the Android Lab image.

## Derived images

Use `FROM android-lab:<version>`, then install the project's extra tools. Pass the derived tag through `DEV_IMAGE` in a consumer Makefile or through `ANDROID_LAB_DEV_IMAGE` for direct lifecycle calls. Helper containers use that same image; the emulator stays a separate matching image.
