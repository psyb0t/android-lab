# Android lab repository guidance

## Purpose

This repository provides a Docker-only Android build, emulator, inspection,
and automation lab. `dikciz-launcher` is a separate sibling repository that consumes locally built lab images. Never put product code or product-specific commands in this repo.

## Required workflow

- Run builds, Gradle tasks, tests, lint, formatting, and device operations
  through the root `Makefile`.
- Do not use host `adb`, a host Android SDK, USB devices, physical phones, or
  host Gradle state.
- Every device command must target the one private lab device,
  `emulator:5556`.
- Use the persistent shared phone for `make run`. Do not replace or reset it except through the named lab
  targets.
- Never stop or remove Docker containers outside this repository. Lab cleanup
  may touch only the exact services created by this repository.

Read `.agents/skills/android-lab/SKILL.md` before device work. Read
`.agents/skills/android-lab-kotlin/SKILL.md` before changing Kotlin, Java, or
Gradle files. App repositories have their own closer instructions.

## Main commands

```bash
make help
make lint
make audit-compose
make build
make run
make device-info
make stop
make screenshot
make ui-layout
```

Use `make gradle ANDROID_PROJECT=<project> GRADLE_TASK=<qualified-task>` for a
focused Gradle task. Never call a project wrapper from the host.

Commands whose output matters must retain their complete logs. Build both local images after explicit SDK license acceptance. Do not publish SDK-equipped images. Consumers pin an exact version and install missing tags with `install.sh`, never silently select another image. Keep the installer contract in `docs/integration.md` stable so old tags still build.

## Repository map

- `Makefile` is the public command surface.
- `Dockerfile.dev` contains the isolated Android build toolchain.
- `Dockerfile.emulator` and `docker-compose.yml` define the private emulator
  and loopback-only browser and control-plane paths.
- `scripts/` validates inputs and owns all lab lifecycle and device access.
- Scripts are embedded under `/opt/android-lab/scripts`; consumers do not require a live lab checkout after building the images.
- `.android-lab/` contains ignored machine state and test artifacts. Do not
  treat it as source or commit it.

## Documentation ownership

Keep the root `README.md` aligned with Make targets, ports, emulator behavior,
resource limits, and artifact paths. `docs/integration.md` owns consumer setup. Dikciz configuration, automation, and upstream updates belong to its separate repository.

## Releases

`VERSION` is the canonical version. When a release bumps it, update every current copy in the same release commit, then search for the old version to catch any you missed:

- `README.md`: the installer command (`bash -s -- <version>`), the `v<version>` tag, both image names, the `docker run` example, and `FROM android-lab:<version>`.
- The usage comment at the top of `install.sh`.

The published `android-lab` skill names no version. It tells agents to use the project's pinned version or the highest `v*` tag, so it needs no change on a bump. Keep it that way. ClawHub publishes it from each tag.

Leave older `docs/changelog.md` entries untouched; they are history. `scripts/test-install.sh` uses its own fixture version and does not follow `VERSION`. Release tags are `v<version>` on a commit whose `VERSION` matches.

## Verification

For lab changes, run `make lint test`, then the relevant emulator target. Verify consumer integration from the app's checkout. Inspect saved screenshots, compact UI layout, and full test logs when a result depends on visible device state. Static source-string tests are not behavioral evidence. Preserve `.android-lab` state and stop only the exact Compose stack started by the lab.
