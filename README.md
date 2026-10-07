# Android Lab

[![CI](https://github.com/psyb0t/android-lab/actions/workflows/pipeline.yml/badge.svg?branch=main)](https://github.com/psyb0t/android-lab/actions/workflows/pipeline.yml)
[![version](https://raw.githubusercontent.com/psyb0t/android-lab/badges/version.svg)](https://github.com/psyb0t/android-lab/releases)
[![license](https://raw.githubusercontent.com/psyb0t/android-lab/badges/license.svg)](LICENSE)

Build an Android app, boot a phone, poke its UI. Keep the SDK and emulator out of your host installation. Android Lab puts the tools and device scripts in locally built Docker images that any Android project can use or extend.

## Build the images locally

The host needs Linux on x86_64, Docker with Compose v2, Make, Git and usable `/dev/kvm`. The build tools use Java 17 and Android API 36. The emulator is a persistent Google APIs x86_64 phone, 1080×2400, with four virtual cores and 4 GiB guest RAM.

```bash
git clone https://github.com/psyb0t/android-lab.git
cd android-lab
```

Read the [Android SDK license](https://developer.android.com/studio/terms). If you accept it:

```bash
ANDROID_LAB_ACCEPT_ANDROID_LICENSES=yes make accept-licenses
make build
```

That creates these images on your own Docker daemon:

```text
android-lab:0.13.0
android-lab:0.13.0-emulator-api36
```

Nothing is pushed to a registry. Google artifacts are downloaded during your local build and checked against Google's repository metadata. Keep these SDK-equipped images local. The tool image contains ADB, Java, SDK platform/build tools, Python, pytest, shell tooling, Docker/Compose, noVNC and the lab scripts. The emulator image contains the emulator, system image and its display stack.

After updating the checkout, run `make build` again. Local image tags derive from `VERSION`; existing tags are not silently selected by newer consumers. Docker reuses unchanged dependency layers. App source and device data never enter either image.

Make limits tool containers to the Docker host's CPU count, capped at 10. Gradle workers follow that limit. Override them with `make build ANDROID_LAB_TOOL_CPU_LIMIT=2 ANDROID_LAB_GRADLE_MAX_WORKERS=2` to leave more CPU time for other work. This does not change the emulator's virtual CPU configuration.

## Use it from an Android project

Your project needs its executable Gradle wrapper and `distributionSha256Sum` in `gradle/wrapper/gradle-wrapper.properties`.

```bash
cd /path/to/your/android-project
docker run --rm --init --user "$(id -u):$(id -g)" \
  -e ANDROID_LAB_WORKSPACE=/work -e ANDROID_PROJECT=. \
  -e GRADLE_TASK=:app:assembleDebug \
  -v "$PWD:/work" -w /work \
  android-lab:0.13.0 android-lab gradle
```

The APK appears in your project's normal build output. Gradle downloads, logs and the stable debug-signing identity stay under that project's `.android-lab/`. Ignore that directory in Git. Run the container as your host UID/GID so it does not leave root-owned output behind.

The lab checkout is needed to build the images, not to run app builds afterwards. [Dikciz Launcher](https://github.com/psyb0t/dikciz-launcher) exposes its build, install, test and inspection commands through its own Makefile.

## Extend the tools

```dockerfile
FROM android-lab:0.13.0

# Install the extra project-specific tools here.
```

```bash
docker build -t my-android-tools:1 .
```

The embedded `android-lab` command still works. Consumers that start an emulator or forwarding service must also select the derived image as `ANDROID_LAB_DEV_IMAGE`; those sibling services need the same extra tools. Dikciz's Makefile accepts `DEV_IMAGE=my-android-tools:1`.

## Boot and inspect a phone

From the lab checkout:

```bash
make run
make device-info
make screenshot
make ui-layout
make stop
```

Open `http://127.0.0.1:61326/vnc.html?autoconnect=true&resize=scale` while it is running. Screenshots, UI XML and compact layout JSON land in `.android-lab/shared/artifacts/`. `make stop` removes this lab's containers and networks, not its saved phone disk.

`make help` lists generic device operations, including APK installation, Home role selection, shell commands, file transfer and emulator event fixtures. Device operations use only the private `emulator:5556` ADB endpoint.

## Device-local listeners

```bash
make forward ANDROID_LAB_FORWARD_HOST_PORT=19001 ANDROID_LAB_FORWARD_DEVICE_PORT=19001 \
  ANDROID_LAB_MCP_HOST_PORT=19002 ANDROID_LAB_MCP_DEVICE_PORT=19002
make unforward
```

These are TCP tunnels for listeners implemented by your app. Android Lab does not supply a WebSocket or MCP server. Published viewer and tunnel ports bind host loopback; ADB is not published.

## Workspaces and Docker access

Builds, lint and fixture tests do not get the Docker socket. Emulator-management commands need it to create sibling containers, plus `/dev/kvm` for the emulator. The controller mounts the workspace at its real host path so sibling bind mounts resolve correctly, even when invoked from a container with the host socket mounted. Ordinary Gradle runs mount the project at `/work`.

Each workspace gets a separate Compose project name. Set `ANDROID_LAB_COMPOSE_PROJECT` to deliberately share an existing project. Phone state is workspace-local; callers must not point unrelated stacks at the same emulator disk.

## Check the lab

```bash
make lint
make test
make test-emulator
make test-forward
```

The normal suite tests the embedded CLI, Gradle project boundaries and rendered Compose configuration. Live checks require KVM, start the lab, then stop it. They preserve the phone disk. See [configuration and integration](docs/integration.md), [third-party notices](THIRD_PARTY.md) and [changelog](docs/changelog.md).
