#!/usr/bin/env python3

"""Convert a UIAutomator XML hierarchy into compact automation JSON."""

from __future__ import annotations

import argparse
from datetime import UTC, datetime
import json
import logging
from logging.handlers import RotatingFileHandler
import os
import re
import sys
from pathlib import Path
from xml.etree import ElementTree

BOUNDS_PATTERN = re.compile(
    r"^\[(?P<left>-?\d+),(?P<top>-?\d+)\]\[(?P<right>-?\d+),(?P<bottom>-?\d+)\]$"
)
SCHEMA_VERSION = 1
INTERACTION_ATTRIBUTES = {
    "checkable": "checkable",
    "clickable": "clickable",
    "focusable": "focusable",
    "long-clickable": "longClickable",
    "password": "password",
    "scrollable": "scrollable",
}
STATE_ATTRIBUTES = {
    "checked": "checked",
    "enabled": "enabled",
    "focused": "focused",
    "selected": "selected",
}

logger = logging.getLogger(__name__)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, object] = {
            "time": datetime.now(UTC).isoformat(timespec="milliseconds"),
            "level": record.levelname,
            "file": record.filename,
            "line": record.lineno,
            "func": record.funcName,
            "msg": record.getMessage(),
        }
        for field in ("element_count", "error"):
            if hasattr(record, field):
                payload[field] = getattr(record, field)
        return json.dumps(payload, separators=(",", ":"))


def configure_logging() -> None:
    formatter = JsonFormatter()
    handlers: list[logging.Handler] = [
        logging.StreamHandler(),
        RotatingFileHandler(
            "/tmp/android-lab-uiautomator-to-json.log",
            maxBytes=1_000_000,
            backupCount=1,
        ),
    ]
    for handler in handlers:
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    logger.propagate = False
    logger.setLevel(logging.DEBUG if os.environ.get("DEBUG") == "1" else logging.INFO)


def parse_bool(value: str | None) -> bool:
    return value == "true"


def parse_bounds(value: str | None) -> dict[str, int] | None:
    if value is None:
        return None

    match = BOUNDS_PATTERN.fullmatch(value)
    if match is None:
        return None

    return {name: int(number) for name, number in match.groupdict().items()}


def make_element(node: ElementTree.Element, index: int) -> dict[str, object]:
    bounds = parse_bounds(node.get("bounds"))
    interactions = [
        name
        for attribute, name in INTERACTION_ATTRIBUTES.items()
        if parse_bool(node.get(attribute))
    ]
    state = [
        name
        for attribute, name in STATE_ATTRIBUTES.items()
        if parse_bool(node.get(attribute))
    ]
    element: dict[str, object] = {
        "index": index,
        "className": node.get("class", ""),
        "resourceId": node.get("resource-id", ""),
        "text": node.get("text", ""),
        "contentDesc": node.get("content-desc", ""),
        "interactions": interactions,
        "state": state,
        "visibleToUser": parse_bool(node.get("visible-to-user", "true")),
    }
    if bounds is not None:
        element["bounds"] = bounds
        element["center"] = {
            "x": (bounds["left"] + bounds["right"]) // 2,
            "y": (bounds["top"] + bounds["bottom"]) // 2,
        }

    return element


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a UIAutomator XML hierarchy into automation JSON."
    )
    parser.add_argument("xml_path", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        root = ElementTree.parse(arguments.xml_path).getroot()
    except (OSError, ElementTree.ParseError) as error:
        logger.error("could not read UIAutomator XML", extra={"error": str(error)})
        return 1

    elements = [
        make_element(node, index)
        for index, node in enumerate(root.iter("node"))
    ]
    logger.debug("converted UIAutomator XML", extra={"element_count": len(elements)})
    json.dump(
        {"schemaVersion": SCHEMA_VERSION, "elements": elements},
        sys.stdout,
        separators=(",", ":"),
    )
    sys.stdout.write("\n")
    logger.info("UIAutomator layout conversion completed")
    return 0


if __name__ == "__main__":
    configure_logging()
    raise SystemExit(main())
