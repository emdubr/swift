#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash Tests/run-codec-tests.sh
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc 'FIELD iOS/Services/PMTilesStyle.swift' Tests/PMTilesStyleTests.swift -o "$tmp/pmtiles-test"
"$tmp/pmtiles-test"
swiftc 'FIELD iOS/Services/FieldHandoff.swift' Tests/FieldHandoffTests.swift -o "$tmp/handoff-test"
"$tmp/handoff-test"
swiftc 'FIELD iOS/Services/GPXService.swift' Tests/GPXTests.swift -o "$tmp/gpx-test"
"$tmp/gpx-test"
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc 'FIELD iOS/Models/FieldModels.swift' \
    'FIELD iOS/Services/RouteEngine.swift' \
    'FIELD iOS/Services/TrailNetworkService.swift' \
    Tests/TrailNetworkTests.swift -o "$tmp/trail-test"
  "$tmp/trail-test"
fi
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc 'FIELD iOS/Models/FieldModels.swift' \
    'FIELD iOS/Services/RouteEngine.swift' \
    'FIELD iOS/Services/TrailNetworkService.swift' \
    'FIELD iOS/Services/TrackRecorder.swift' \
    Tests/TrackRecorderTests.swift -o "$tmp/track-test"
  "$tmp/track-test"
fi
python3 Tests/check-project.py
