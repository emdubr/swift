# FIELD / OS Native iPhone — 0.8 implementation status

## Integrated in source

- Existing native GPS/navigation, route editor, offline local GeoJSON trail graph / A* and snapping, route metrics/ETA/profile, route deviation, terrain-risk screening and bailout ranking; Return to Trail/Base; waypoints, GPX, tracks; mission/trip/readiness, offline guide/POIs, sensors, notifications and WeatherKit on-demand fetch.
- **MapLibre Native Swift Package** linked in the `.xcodeproj` with on-device PMTiles v3 validation, raster/vector local-only style generation, Map screen switcher and route/waypoint annotations. Both raster and vector rendering paths are written; map coverage and visual quality require simulator/physical iPhone testing. Basic vector layer styles will not reproduce every map publisher's full topographic style. A PMTiles archive is not automatically downloaded.
- **Meshtastic:** PhoneAPI BLE service filter/characteristics, config handshake, packet FIFO, direct/broadcast text send, incoming plaintext/position/NodeDB and routing/queue statuses, newly added bounded device/environment telemetry decoding. Not a full Meshtastic admin/PKI implementation.
- **TAP V2:** generic configurable 128-bit BLE GATT scan/connect/read-only notifications, shown only as raw data. Cannot decode custom sensors without real TAP V2 firmware GATT and payload specification. Existing Meshtastic-compatible radios work through Meshtastic adapter if their actual firmware advertises that protocol.
- **Satellite:** manual text sharing to an external app/communicator, including source/age of GPS fix. There is no automated satellite transport or proof of delivery.

## Independently validated in this environment

- `bash Tests/run-all-tests.sh` compiles/runs Foundation-only codec, PMTiles header/style, message persistence migration and manual handoff tests, fuzzes 10,000 random codec frames, validates each Swift file's project references and MapLibre package linkage.
- Swift syntax parsing, Info.plist and pbxproj validation, ZIP integrity and physical archive presence are checked before release.

## Not yet independently validated / externally blocked

- Xcode simulator compilation + runtime, resolution of MapLibre binary and live PMTiles tile display, layout and gestures; physical-device testing of CoreLocation, WeatherKit entitlement, permission/background behavior, energy efficiency and BLE. Linux Swift parsing alone **cannot** validate iOS frameworks or package binary compatibility.
- Meshtastic advanced channel/admin management, PKI and complete protocol coverage; actual RF/delivery confirmations require radio hardware.
- TAP V2 custom payload format (hardware firmware documentation required) and satellite modem transport (specific vendor APIs/credentials/compatible relay hardware required).
- True predownload of a specific hiking region, complete contours/hillshade on arbitrary third-party vector data, terrain maps for every map publisher, independently checked trail safety.

The web repository `emdubr/field-os` remains unchanged. This is a checkpoint, not a statement that field hardware or emergency delivery is verified.
