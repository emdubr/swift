#!/usr/bin/env bash
# Compile a standalone SwiftUI application, independent of FIELD/OS and MapLibre.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT='build/RunnerProbe.app'
mkdir -p "$OUT"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
ARCH="$(uname -m)"
xcrun swiftc -parse-as-library -sdk "$SDK" \
  -target "${ARCH}-apple-ios17.0-simulator" \
  -framework SwiftUI \
  Tests/RunnerProbe.swift \
  -o "$OUT/RunnerProbe"
python3 - <<'PY'
from pathlib import Path
import plistlib
out=Path('build/RunnerProbe.app')
plist={
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleDisplayName': 'FIELD CI Runner Probe',
    'CFBundleExecutable': 'RunnerProbe',
    'CFBundleIdentifier': 'com.fieldos.runnerprobe',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleName': 'RunnerProbe',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.0',
    'CFBundleVersion': '1',
    'LSRequiresIPhoneOS': True,
    'MinimumOSVersion': '17.0',
    'CFBundleSupportedPlatforms': ['iPhoneSimulator'],
}
with (out / 'Info.plist').open('wb') as f:
    plistlib.dump(plist,f)
PY
test -s "$OUT/RunnerProbe"
echo "Independent SwiftUI baseline prepared for $ARCH iOS Simulator"
