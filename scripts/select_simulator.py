#!/usr/bin/env python3
"""Choose an installed iPhone simulator without relying on a particular model name."""
import json
import re
import subprocess
import sys


def select_device(data):
    candidates = []
    for runtime, devices in data.get("devices", {}).items():
        match = re.search(r"\.iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$", runtime)
        if not match:
            continue
        version = tuple(int(part or 0) for part in match.groups())
        if version < (17, 0, 0):
            continue
        for device in devices:
            if device.get("isAvailable") and device.get("name", "").startswith("iPhone") and device.get("udid"):
                candidates.append((version, device.get("state") == "Booted", device["name"], device["udid"]))
    if not candidates:
        raise ValueError("No available iPhone simulator running iOS 17 or later. Install a runtime in Xcode Settings > Components.")
    return max(candidates)[-1]


def main():
    try:
        result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                                check=True, capture_output=True, text=True)
        print(select_device(json.loads(result.stdout)))
    except (subprocess.CalledProcessError, ValueError, OSError) as error:
        print(f"Simulator selection failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
