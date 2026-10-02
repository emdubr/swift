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
python3 Tests/check-project.py
