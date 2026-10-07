---
name: android-lab
description: "Build, run and inspect Android apps through locally built Android Lab Docker images. Use for lab setup, Gradle tasks, emulator operations and device-local port forwarding."
metadata:
  author: psyb0t
  version: "1.0"
---

# Android Lab

Use the current project's Makefile for supported operations. It may consume the lab image without containing the lab source. Check its image requirements first. Missing images require the [local image build](https://github.com/psyb0t/android-lab#build-the-images-locally), not a registry pull.

The tools are embedded at `/opt/android-lab`; `android-lab` is on PATH. Do not call workspace `scripts/lab-device.sh` or infer the workspace from an embedded script's location. `ANDROID_LAB_WORKSPACE` selects the mounted workspace; `ANDROID_PROJECT=.` supports a Gradle project at its root. The wrapper must be executable and pin its distribution checksum.

```bash
make help
make gradle ANDROID_PROJECT=. GRADLE_TASK=:app:assembleDebug
make run
make device-info
make ui-layout
make screenshot
make stop
```

App flavours may require a different qualified Gradle task. Inspect the app Makefile instead of assuming `Debug` is its product variant. App-specific install, control and reset targets belong to that app.

All normal device operations target only the private `emulator:5556`. Do not use host ADB, USB, host SDK state or physical devices. Keep `.android-lab/` ignored; it contains caches, a stable signing identity and saved phone state. Stopping the stack does not authorize deleting that state or resetting an app.

Start with compact layout JSON for UI inspection, then use screenshots/XML when necessary. The viewer binds host loopback, normally port 61326. Forwarding is a tunnel to listeners implemented by the app, not an MCP server supplied by Android Lab.

Build/lint containers do not get the Docker socket. Lifecycle controllers require it and must mount the workspace at its exact host path for sibling binds. Run as the caller's UID/GID. Read [integration settings](https://github.com/psyb0t/android-lab/blob/main/docs/integration.md) when changing mounts, image overrides or lifecycle configuration.

Complete an operation only after its exit status and saved output verify the requested result. Leave the emulator running or stopped as requested by the user.
