#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"; rm -f Tests/_fieldmessage_actual.swift' EXIT
swiftc 'FIELD iOS/Services/MeshtasticCodec.swift' Tests/CodecTests.swift -o "$tmp/codec-tests"
python3 - <<'PY'
from pathlib import Path
s=Path('FIELD iOS/Models/FieldModels.swift').read_text()
Path('Tests/_fieldmessage_actual.swift').write_text('import Foundation\n'+s[s.index('enum MessageStatus: String, Codable {'):s.index('struct MeshNode:')])
PY
swiftc Tests/_fieldmessage_actual.swift Tests/MessageMigrationTests.swift -o "$tmp/message-tests"
"$tmp/message-tests"
"$tmp/codec-tests"
