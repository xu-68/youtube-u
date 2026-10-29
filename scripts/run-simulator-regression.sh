#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "$0")/.." && pwd)
output_dir="${RUNNER_TEMP:-$project_dir/.theos}/marker-regression"
mkdir -p "$output_dir/MarkerRegression.app"
python3 "$project_dir/scripts/generate-simulator-regression.py" "$output_dir/main.mm"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator clang++ -fobjc-arc -std=c++17 \
    -target "$(uname -m)-apple-ios17.0-simulator" -isysroot "$sdk" \
    -I"$project_dir/Tweaks" -framework UIKit -framework Foundation -framework CoreGraphics \
    "$output_dir/main.mm" -o "$output_dir/MarkerRegression.app/MarkerRegression"
python3 - "$output_dir/MarkerRegression.app/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({'CFBundleIdentifier': 'local.uyou.marker-regression',
                  'CFBundleExecutable': 'MarkerRegression',
                  'CFBundleName': 'MarkerRegression', 'CFBundlePackageType': 'APPL',
                  'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0',
                  'MinimumOSVersion': '17.0', 'LSRequiresIPhoneOS': True,
                  'UIDeviceFamily': [1, 2]}, f)
PY
codesign --force --sign - "$output_dir/MarkerRegression.app"
xcrun simctl list devices available --json > "$output_dir/devices.json"
device=$(python3 - "$output_dir/devices.json" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))['devices']
phones = [d for group in devices.values() for d in group if 'iPhone' in d['name'] and d['isAvailable']]
if not phones:
    raise SystemExit('No available iPhone simulator runtime')
print(phones[0]['udid'])
PY
)
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$output_dir/MarkerRegression.app"
xcrun simctl launch --console "$device" local.uyou.marker-regression
container=$(xcrun simctl get_app_container "$device" local.uyou.marker-regression data)
test -f "$container/Documents/results.json"
cp "$container/Documents/results.json" "$output_dir/results.json"
python3 - "$output_dir/results.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
print(json.dumps(report, indent=2))
if report['failed'] or report['total'] < 18:
    raise SystemExit('Simulator regression failed')
PY
