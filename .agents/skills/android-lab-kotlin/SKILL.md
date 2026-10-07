---
name: android-lab-kotlin
description: "Use when editing Kotlin, Java, or Gradle build logic in an Android project that consumes Android Lab. Run builds through its Docker tooling and preserve the app's existing architecture."
metadata:
  author: psyb0t
  version: "1.0"
---

# Kotlin in Android lab

Build through the lab before using an emulator:

```bash
make gradle ANDROID_PROJECT=<project> GRADLE_TASK=<one-qualified-task>
make app-build ANDROID_PROJECT=<project>
make app-test ANDROID_PROJECT=<project>
make app-lint ANDROID_PROJECT=<project>
```

The wrapper rejects projects outside this workspace and Gradle wrappers without
a distribution checksum. Do not run Gradle from the host.

Run from the app's checkout, not a parent directory. Use `ANDROID_PROJECT=.` when the Gradle project is at its root. If the required image is missing, follow [the local image build instructions](https://github.com/psyb0t/android-lab#build-the-images-locally); do not silently pull another image. Consult the official Kotlin and Android Gradle Plugin migration documentation before a requested language or AGP migration. Do not depend on ignored research clones being installed.

Keep the existing app's UI and architecture choices. Dikciz starts from Fossify
Views and ViewBinding, so a Kotlin change does not authorize a Compose, Hilt,
KMP, or large architecture conversion.
