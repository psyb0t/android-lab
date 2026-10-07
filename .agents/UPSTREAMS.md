# Android lab skill sources

The lab's skill guidance was informed by the following Apache-2.0 upstream sources. These are attribution and research references, not required runtime checkouts. The skills work from the repository and locally built image without installing those source trees.

| Source | Revision | License | Used for |
| --- | --- | --- | --- |
| https://github.com/android/skills | `ea05a53683d1fb1fc701c3ad91f494d25d4fc7c6` | Apache-2.0 | Android testing and device-work guidance |
| https://github.com/Kotlin/kotlin-agent-skills | `08d7ad0d74a9a5a548287b2bd4926180fab56cac` | Apache-2.0 | Kotlin and Gradle migration guidance |

The adapters preserve Android lab isolation. They do not allow a skill to use
host ADB state, USB devices, host networking, or an unspecified serial.
