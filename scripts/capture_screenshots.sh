#!/bin/bash
# Capture genuine app screens using Debug-only fictional data in an isolated device.
set -euo pipefail
device_id="${1:?Pass the UDID of an isolated MovingSoon QA simulator}"
app_bundle="${2:?Pass the built Debug simulator .app path}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${3:-$repo_dir/AppStoreScreenshots/ReleaseCandidate-2026-10-22}"
device_name="$(xcrun simctl list devices -j | python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"]; print(next((d["name"] for group in devices.values() for d in group if d["udid"]==sys.argv[1]), ""))' "$device_id")"
if [[ "$device_name" != "MovingSoon "* ]]; then
    printf 'Use a dedicated simulator named MovingSoon QA (or another MovingSoon-prefixed name). Existing personal devices are not changed.\n' >&2
    exit 2
fi
mkdir -p "$output_dir"
xcrun simctl install "$device_id" "$app_bundle"
xcrun simctl ui "$device_id" content_size large
sleep 2
for entry in 'dashboard:01_dashboard' 'reminders:02_reminders' 'accounts:03_accounts_dates' 'task:04_task_details' 'services:05_review_services' 'library:06_moves_backups'; do
    mode="${entry%%:*}"
    filename="${entry#*:}"
    xcrun simctl terminate "$device_id" app.movingsoon >/dev/null 2>&1 || true
    SIMCTL_CHILD_SEED_SCREENSHOT_DATA=1 SIMCTL_CHILD_SCREENSHOT_SCREEN="$mode" \
        xcrun simctl launch "$device_id" app.movingsoon
    # Let the system's sheet/status-bar transition finish before saving an asset.
    sleep 4
    xcrun simctl io "$device_id" screenshot "$output_dir/$filename.png"
done
