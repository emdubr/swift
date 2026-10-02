# FIELD / OS — independent native iPhone project (0.8)

This project is completely separate from `emdubr/field-os`. No Swift sources were pushed into the web repo.

**Windows/iPhone quick start:** The GitHub `FIELD-iOS-simulator` artifact cannot run on Windows or be installed on your phone. Use the [free unsigned iPhone IPA workflow](https://github.com/emdubr/swift/actions/workflows/ios-device-ipa.yml) and follow [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md). The IPA uses a standard public GitHub macOS runner; sign it locally on Windows with your own free Apple ID using Sideloadly. Never upload your Apple ID or signing credentials to GitHub.


## New in 0.8

- **Local PMTiles rendering integration:** added MapLibre Native 6.28+ through Swift Package Manager, `pmtiles://file://` style generation for imported PMTiles v3 raster/vector archives, live UI toggle between local MapLibre and Apple MapKit, user location and route/waypoint annotations. Selected local packs contain no online tile URLs in the generated style. The style generator offers common OSM vector source layers and a manual layer-ID override. Vector styling is basic; it is not equivalent to all publisher-defined cartography. Actual map rendering has not been verified against the Apple SDK or on-device.
- **Meshtastic telemetry:** decode real `TELEMETRY_APP` DeviceMetrics and EnvironmentMetrics with sanity checks, and show radio battery, channel utilization, temperature and pressure for decoded nodes. Fixed routing error field matching current Meshtastic protobuf. Existing bounded incoming text/position, NodeDB, BLE PhoneAPI handshake, direct/broadcast encoding and explicit delivery states remain.
- **Hardware diagnostics:** configurable receive-only GATT bridge. Enter the exact custom service and notification-characteristic UUIDs published by TAP V2 firmware, scan, connect, and inspect bounded raw bytes/timestamps. No custom sensor fields are decoded or transmitted until a real firmware protocol is supplied. This is separate from the Meshtastic PhoneAPI BLE connection.
- **Manual satellite/external-app handoff:** shareable check-in or SOS text with timestamped WGS84 coordinates, accuracy and stale-fix warning. Uses the iPhone share sheet; does **not** trigger a satellite modem or Apple satellite Emergency SOS and makes **no delivery guarantee**. Call local emergency services/use an independent verified communicator in an emergency.
- Extended CLI regression tests: PMTiles malformed headers/style JSON, manual SOS/check-in, Meshtastic telemetry/routing and 10,000 malformed-frame stress tests; Swift source/Xcode project audit.

## Running on iPhone

1. On a Mac or cloud Mac, open `FIELD iOS.xcodeproj` with Xcode. The project fetches `MapLibre` from `https://github.com/maplibre/maplibre-gl-native-distribution` (version 6.28+); an internet connection is needed once to resolve the package. iOS 17+ is targeted.
2. For a simulator CI build, the supplied `.github/workflows/ios-build.yml` runs Foundation tests, resolves the MapLibre dependency and runs an unsigned simulator build when **this separate project** is placed in its own GitHub repository.
3. Choose your developer signing team for an actual iPhone. Enable your own WeatherKit entitlement if you want real Apple Weather. Test Core Location, background battery performance, BLE real radio firmware, and PMTiles basemaps on the target phone.
4. In Offline Maps, import an appropriately licensed regional PMTiles file. Select it and open Map. **Verify actual coverage and route correctness while fully offline** before relying on it. MapLibre does not itself download regional packs through this implementation.

Run `bash Tests/run-all-tests.sh` on a machine with Swift and Python 3 to test the Foundation-only components. `STATUS.md` describes remaining external integration and actual-device validation limits.

**Safety:** FIELD/OS is field-planning assistance, not an emergency service. Mesh routing acknowledgement is not proof of human receipt; manual share is not proof of satellite transmission. Independently verify route, terrain, communication and weather before travel. The user is responsible for honoring imported map-data licenses and attribution requirements.

## Free GitHub cloud build (Windows supported)

Open https://github.com/emdubr/swift/actions/workflows/ios-build.yml, select **Run workflow**, choose **main**, and run it. Changes to app code on main and pull requests also trigger a build.

The workflow runs the Foundation regression tests and compiles the complete iOS app with Xcode on a standard macOS runner. No Apple account, signing secrets, or local Mac is needed. Standard hosted runner execution is free for this public repository. No repository visibility or billing settings are changed. Builds cancel older runs on the same branch and time out after 25 minutes.

After a successful run, download **FIELD-iOS-simulator** from the run's Artifacts section. The contained app runs in an Apple iOS Simulator on a Mac; it cannot be installed on an iPhone or run directly on Windows. Diagnostics and artifacts expire after three days. TestFlight and device signing are separate setup steps; this workflow does not publish to the App Store.

### Route editing and cloud preview

The native route planner supports 30 levels of undo/redo, guarded GPX/JSON imports, and export of real `.gpx` files using the iOS Files picker. GPX parser regression cases run with the Foundation test suite.

Cloud builds restore cached Swift packages when possible. For a screenshot, manually run the **iOS cloud build** workflow on `main`. Its optional simulator launch saves `FIELD-iOS-ui-preview-and-diagnostics`: a screenshot if native startup works, or useful launch diagnostics if it fails. Routine pushes skip simulator boots, and a simulator screenshot cannot validate device hardware or offline maps.
