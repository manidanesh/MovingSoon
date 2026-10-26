#!/usr/bin/env python3
"""Select the newest complete installed Xcode 26+ without changing xcode-select.

Prints its Contents/Developer directory for a process-local DEVELOPER_DIR. CI can
write that value to GITHUB_ENV; this script never changes host-wide settings.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import plistlib
import re
import sys

MINIMUM_VERSION = (26, 0, 0)


def parse_version(value: object) -> tuple[int, int, int]:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value):
        raise ValueError(f"Invalid Xcode version: {value!r}")
    parts = tuple(int(part) for part in value.split("."))
    return (parts + (0, 0, 0))[:3]


def select_xcode(applications: Path = Path("/Applications")) -> Path:
    candidates: list[tuple[tuple[int, int, int], str, Path]] = []
    inspected: list[str] = []
    for app in sorted(applications.glob("Xcode*.app")):
        try:
            with (app / "Contents/Info.plist").open("rb") as source:
                info = plistlib.load(source)
            if not isinstance(info, dict):
                raise ValueError("Xcode Info.plist must contain a dictionary")
            raw_version = info.get("CFBundleShortVersionString")
            version = parse_version(raw_version)
            developer = app / "Contents/Developer"
            if not (developer / "usr/bin/xcodebuild").is_file():
                inspected.append(f"{app.name}: incomplete developer tools")
                continue
            inspected.append(f"{app.name}: {raw_version}")
            if version >= MINIMUM_VERSION:
                candidates.append((version, str(app), developer))
        except (OSError, ValueError, plistlib.InvalidFileException) as error:
            inspected.append(f"{app.name}: unreadable version metadata ({type(error).__name__})")
    if not candidates:
        details = "; ".join(inspected) if inspected else "no Xcode*.app installations found"
        raise ValueError(
            f"Xcode 26 or later is required, but no complete compatible installation was found in {applications}. "
            f"Install a compatible Xcode or choose a CI runner image that includes it. Inspected: {details}."
        )
    return max(candidates, key=lambda candidate: (candidate[0], candidate[1]))[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--applications-dir", type=Path, default=Path("/Applications"))
    args = parser.parse_args()
    try:
        print(select_xcode(args.applications_dir))
        return 0
    except ValueError as error:
        print(f"Xcode selection failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
