# Set up Android Lab for another project

The installed skill can live anywhere. Run commands from the user's selected Android project, never the skill directory. Check the project's existing integration before adding anything.

## Images

Read the [local image build instructions](https://github.com/psyb0t/android-lab#build-the-images-locally). Build in a separate Android Lab checkout after the user accepts the SDK license. Use the matching local tool and emulator tags from that checkout's `VERSION`. Do not silently pull a different image or record license acceptance for the user.

## A project without a lab-aware Makefile

For a single Gradle task, select the locally built tool image and run from the Android project root:

```bash
IMAGE=android-lab:0.13.0
docker image inspect "$IMAGE" >/dev/null
docker run --rm --init --user "$(id -u):$(id -g)" \
  -e HOME=/tmp -e ANDROID_LAB_WORKSPACE=/work -e ANDROID_PROJECT=. \
  -e GRADLE_TASK=:app:assembleDebug -e ANDROID_LAB_GRADLE_MAX_WORKERS=2 \
  -v "$PWD:/work" -w /work "$IMAGE" android-lab gradle
```

Select the actual qualified task for the app's variant. The project needs an executable Gradle wrapper and `distributionSha256Sum`. The image writes caches, signing state and build output as the caller's UID/GID. Keep `.android-lab/` ignored and preserve it between runs.

## Emulator integration

Use an existing consumer Makefile when available. Otherwise read [integration settings](https://github.com/psyb0t/android-lab/blob/main/docs/integration.md) and the [canonical Makefile](https://github.com/psyb0t/android-lab/blob/main/Makefile) before setting up the controller. Emulator management differs from a Gradle run: it requires the host Docker socket, its group, matching image names, caller UID/GID and a workspace bind at the identical absolute host path. A `/work` bind alone is insufficient for sibling-container mounts. KVM must be available on the Docker host.

Do not assume installing this skill adds `make run`, `make screenshot`, or other targets to a consumer. Do not use a different workspace's emulator disk. Verify the selected workspace and Compose project before lifecycle operations, and preserve the user's requested running or stopped state.
