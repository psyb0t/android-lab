# Third-party software

Android Lab's own shell scripts are licensed under WTFPL. The image installs separate programs with their own licenses, including Docker CLI/Compose, OpenJDK, Android platform tools, Python, pytest, noVNC, websockify, Bash and the distribution's packages. Their licenses remain their own; the lab license does not relicense them.

Google SDK platforms, build tools, the emulator and Google APIs system images are downloaded only during the user's local build. Read and accept the [Android SDK License Agreement](https://developer.android.com/studio/terms) before building. Its sections 3.4 and 3.5 distinguish restricted SDK redistribution from components governed by open-source licenses. These SDK-equipped images are local build artifacts, not published registry images.

Artifact URLs and SHA-1 values come from Google's HTTPS repository metadata. The build verifies those checksums before extracting the archives. SHA-1 here is the upstream download-integrity format, not a claim of a modern signature scheme.

Dikciz and its Fossify source belong in the separate launcher repository and retain their GPLv3 license. No launcher source or APK is included in the Android Lab tooling image.
