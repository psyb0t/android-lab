#!/usr/bin/env python3
"""Resolve checksum-verified Google Android SDK artifacts for one API level."""

from __future__ import annotations

import argparse
import json
import logging
import logging.handlers
import sys
import urllib.request
import xml.etree.ElementTree as element_tree


GOOGLE_REPOSITORY = "https://dl.google.com/android/repository"
EMULATOR_REPOSITORY_URL = f"{GOOGLE_REPOSITORY}/repository2-1.xml"
SYSTEM_IMAGE_REPOSITORY_URL = f"{GOOGLE_REPOSITORY}/sys-img/google_apis/sys-img2-5.xml"
SUPPORTED_CHANNELS = frozenset({"channel-0", "channel-1", "channel-2"})
X86_64_ABI = "x86_64"
ANDROID_PLATFORM_PATH_PREFIX = "platforms;android-"
LOG_FILE = "/tmp/android-lab-resolve.log"
LOGGER = logging.getLogger(__name__)


class JSONFormatter(logging.Formatter):
    """Write stable structured diagnostics without affecting JSON stdout."""

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "file": record.filename,
            "func": record.funcName,
            "level": record.levelname,
            "line": record.lineno,
            "msg": record.getMessage(),
            "time": self.formatTime(record, "%Y-%m-%dT%H:%M:%SZ"),
        }
        if hasattr(record, "error"):
            payload["error"] = record.error
        return json.dumps(payload, sort_keys=True)


def configure_logging() -> None:
    formatter = JSONFormatter()
    stderr_handler = logging.StreamHandler()
    file_handler = logging.handlers.RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=2)
    for handler in (stderr_handler, file_handler):
        handler.setFormatter(formatter)
    logging.basicConfig(level=logging.INFO, handlers=[stderr_handler, file_handler])


def fetch_xml(url: str) -> element_tree.Element:
    request = urllib.request.Request(url, headers={"User-Agent": "android-lab/1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return element_tree.fromstring(response.read())


def package_by_path(root: element_tree.Element, package_path: str) -> element_tree.Element:
    packages = [
        package
        for package in root.findall("remotePackage")
        if package.attrib.get("path") == package_path and has_supported_channel(package)
    ]
    if not packages:
        raise ValueError(f"Google repository does not contain package {package_path}")

    return max(packages, key=package_revision_key)


def has_supported_channel(package: element_tree.Element) -> bool:
    channel = package.find("channelRef")
    return channel is not None and channel.attrib.get("ref") in SUPPORTED_CHANNELS


def package_revision_key(package: element_tree.Element) -> tuple[int, int, int]:
    revision = package.find("revision")
    if revision is None:
        raise ValueError(f"package {package.attrib.get('path')} has no revision")

    try:
        return tuple(
            int(revision.findtext(part) or "0")
            for part in ("major", "minor", "micro")
        )
    except ValueError as error:
        raise ValueError(f"Google repository returned a malformed revision for {package.attrib.get('path')}") from error


def official_linux_archive(package: element_tree.Element) -> tuple[str, str, str]:
    channel = package.find("channelRef")
    channel_name = channel.attrib.get("ref") if channel is not None else None
    if channel_name not in SUPPORTED_CHANNELS:
        raise ValueError(f"package {package.attrib.get('path')} is outside the supported Google channels")

    for archive in package.findall("archives/archive"):
        host_os = archive.findtext("host-os")
        if host_os not in (None, "linux"):
            continue
        complete = archive.find("complete")
        if complete is None:
            continue
        url = complete.findtext("url")
        checksum = complete.findtext("checksum")
        if url and checksum:
            return url, checksum, channel_name

    raise ValueError(f"package {package.attrib.get('path')} has no Linux archive")


def release_version(package: element_tree.Element) -> str:
    revision = package.find("revision")
    if revision is None:
        raise ValueError(f"package {package.attrib.get('path')} has no revision")
    version_parts = [revision.findtext(part) for part in ("major", "minor", "micro")]
    return ".".join(part for part in version_parts if part)


def artifact(url: str, checksum: str, version: str, channel: str) -> dict[str, str]:
    if len(checksum) != 40 or any(character not in "0123456789abcdef" for character in checksum):
        raise ValueError("Google repository returned a non-SHA-1 checksum")
    return {"channel": channel, "sha1": checksum, "url": url, "version": version}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", required=True, type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.api < 26:
        raise ValueError("API must be at least 26 for the x86_64 emulator")

    emulator_root = fetch_xml(EMULATOR_REPOSITORY_URL)
    system_image_root = fetch_xml(SYSTEM_IMAGE_REPOSITORY_URL)
    emulator = package_by_path(emulator_root, "emulator")
    platform_tools = package_by_path(emulator_root, "platform-tools")
    platform_path = f"{ANDROID_PLATFORM_PATH_PREFIX}{args.api}"
    build_tools_path = f"build-tools;{args.api}.0.0"
    system_image_path = f"system-images;android-{args.api};google_apis;{X86_64_ABI}"
    platform = package_by_path(emulator_root, platform_path)
    build_tools = package_by_path(emulator_root, build_tools_path)
    system_image = package_by_path(system_image_root, system_image_path)

    emulator_url, emulator_checksum, emulator_channel = official_linux_archive(emulator)
    platform_tools_url, platform_tools_checksum, platform_tools_channel = official_linux_archive(platform_tools)
    system_image_url, system_image_checksum, system_image_channel = official_linux_archive(system_image)
    result = {
        "api": args.api,
        "emulator": artifact(
            f"{GOOGLE_REPOSITORY}/{emulator_url}",
            emulator_checksum,
            release_version(emulator),
            emulator_channel,
        ),
        "platform_tools": artifact(
            f"{GOOGLE_REPOSITORY}/{platform_tools_url}",
            platform_tools_checksum,
            release_version(platform_tools),
            platform_tools_channel,
        ),
        "platform": artifact(
            f"{GOOGLE_REPOSITORY}/{official_linux_archive(platform)[0]}",
            official_linux_archive(platform)[1],
            release_version(platform),
            official_linux_archive(platform)[2],
        ),
        "build_tools": artifact(
            f"{GOOGLE_REPOSITORY}/{official_linux_archive(build_tools)[0]}",
            official_linux_archive(build_tools)[1],
            release_version(build_tools),
            official_linux_archive(build_tools)[2],
        ),
        "system_image": artifact(
            f"{GOOGLE_REPOSITORY}/sys-img/google_apis/{system_image_url}",
            system_image_checksum,
            release_version(system_image),
            system_image_channel,
        ),
    }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    configure_logging()
    try:
        raise SystemExit(main())
    except (OSError, ValueError, element_tree.ParseError) as error:
        LOGGER.error("Android artifact resolution failed", extra={"error": str(error)})
        raise SystemExit(1) from error
