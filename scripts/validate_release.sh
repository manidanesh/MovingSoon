#!/bin/bash
# Local and CI validation. This never signs, uploads, archives or publishes the app.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
require_key=0
run_tests=1
for argument in "$@"; do
    case "$argument" in
        --require-census-key) require_key=1 ;;
        --skip-tests) run_tests=0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done
build_dir="${MOVINGSOON_BUILD_DIR:-$repo_dir/build/validation}"
mkdir -p "$build_dir"
if [[ "$require_key" == 1 ]]; then
    python3 scripts/check_release_bundle.py --provision-census-key --require-census-key
fi
xcodebuild -version
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/check_catalog_links.py
xcodebuild build -project movingsoon.app.xcodeproj -scheme movingsoon.app -configuration Release \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$build_dir/DerivedData" \
    CODE_SIGNING_ALLOWED=NO | tee "$build_dir/release-build.log"
# macOS's Bash 3.2 treats an empty array expansion as unbound under set -u.
# Keep this array nonempty even when Census configuration is optional.
bundle_options=(--app-bundle "$build_dir/DerivedData/Build/Products/Release-iphonesimulator/movingsoon.app.app")
if [[ "$require_key" == 1 ]]; then
    bundle_options+=(--require-census-key)
fi
python3 scripts/check_release_bundle.py "${bundle_options[@]}"
if [[ "$run_tests" == 1 ]]; then
    simulator_id="${MOVINGSOON_SIMULATOR_UDID:-$(python3 scripts/select_simulator.py)}"
    result_path="$build_dir/Tests-$(date -u +%Y%m%dT%H%M%SZ)-$$.xcresult"
    xcodebuild test -project movingsoon.app.xcodeproj -scheme movingsoon.app -configuration Debug \
        -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir/DerivedData" \
        -resultBundlePath "$result_path" CODE_SIGNING_ALLOWED=NO | tee "$build_dir/tests.log"
fi
printf 'Validation finished. Logs and test results: %s\n' "$build_dir"
