#!/usr/bin/env python3
"""Check shipping metadata/configuration without logging credentials."""
import argparse
import os
from pathlib import Path
import plistlib
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-bundle", type=Path)
    parser.add_argument("--require-census-key", action="store_true")
    parser.add_argument("--provision-census-key", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    key_path = repo / "movingsoon.app" / "CensusAPIKey.plist"
    if args.provision_census_key and not key_path.exists():
        key = os.environ.get("CENSUS_API_KEY", "").strip()
        if key:
            descriptor = os.open(key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "wb") as destination:
                plistlib.dump({"CensusAPIKey": key}, destination)
            print("Provisioned the ignored Census configuration resource from the environment.")
    if args.app_bundle:
        with (args.app_bundle / "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        if info.get("CFBundleDisplayName") != "MovingSoon":
            raise ValueError("App display name must be MovingSoon.")
        if info.get("MinimumOSVersion") != "17.0":
            raise ValueError("App deployment target must remain iOS 17.0.")
        if info.get("CFBundleIdentifier") != "app.movingsoon":
            raise ValueError("Unexpected app bundle identifier.")
        key_path = args.app_bundle / "CensusAPIKey.plist"
    if args.require_census_key:
        if not key_path.is_file():
            raise ValueError("Census configuration missing. Provide the ignored movingsoon.app/CensusAPIKey.plist or set CENSUS_API_KEY when running validate_release.sh --require-census-key. Key values are never printed.")
        with key_path.open("rb") as source:
            key = plistlib.load(source).get("CensusAPIKey")
        if not isinstance(key, str) or not key.strip():
            raise ValueError("Census configuration has no nonempty CensusAPIKey string.")
        print("Census configuration is present. Live service authentication still requires a separate check.")
    print("Release configuration checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"Release configuration check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
