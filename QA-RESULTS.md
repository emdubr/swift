# Native 0.8 quality gates

Run `Tests/run-all-tests.sh`. It validates:

- Swift-only Meshtastic protobuf text/position/NodeDB/telemetry/routing/queue decoding and direct/broadcast packet encoding, legacy message persistence migration and 10,000 malformed/random frames.
- PMTiles v3 header field/bounds/version/zoom/type validation; vector/raster local-style JSON generation with `pmtiles://file://` source URLs and custom layer names.
- Manual check-in/SOS formatting, recent/stale/unknown position distinctions; no automatic-transmission claims.
- 48 Swift files individually referenced in `.xcodeproj`, MapLibre SPM reference and 0.8 Info.plist versions.

Local structural validation should also run Swift per-file `swiftc -frontend -parse`, `plutil -lint` for both Xcode project and Info.plist, and `unzip -t` for delivery ZIP.

Apple SDK simulator compilation and real iPhone/TAP V2/satellite hardware acceptance testing cannot be performed in this Linux environment. The included separate-repo GitHub Actions job is configured for macOS `xcodebuild`, but it has not run here.
