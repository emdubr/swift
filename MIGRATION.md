# Web → Native migration matrix

| Web area | Native status | Native implementation |
|---|---|---|
| Home / field status | Ported | `DashboardView` |
| Readiness checklist | Ported | `ReadinessView` |
| Terrain map | Ported base | MapKit + route/waypoints/user location; offline topo packs pending |
| Navigation / compass | Ported | CoreLocation + `FieldNavigationView` |
| Route planner | Partially ported | Native editor, analysis, GPX and persistence; trail graph/snap pending |
| Return to Trail | Ported base | nearest route-polyline intercept + bearing |
| Return to Base | Ported base | base waypoint/route-start bearing |
| Waypoints | Ported | local native model/storage |
| Track recorder | Ported | live CoreLocation breadcrumb recorder |
| Trip plan / check-ins | UI/state ported | scheduler/background delivery pending |
| Mission mode / group expedition | UI/state ported | live mesh positions pending |
| Field guide | Ported | bundled offline Swift content |
| Weather intelligence | State/UI ported | WeatherKit/provider pending |
| Comms / mesh | Native BLE layer started | scan/connect + local queue; Meshtastic protocol pending |
| LoRa chat | UI/queue ported | send confirmation waits for transport adapter |
| Mesh map | UI ported | live node coordinates wait for protocol adapter |
| Sensors | Ported for iPhone | GPS/heading/barometer/battery; TAP sensors pending |
| Field log / scratchpad / marks | Ported | local persistence |
| System / preflight / recovery | Ported base | native permissions/state + JSON snapshots |
| Power | Ported base | iPhone battery + low power state |
| Lost mode | Ported | native decision-support page |
| Emergency / SOS | Ported safely | call shortcut + local SOS packet; no false sent state |
| Offline POI search | Ported base | local waypoint/POI index |
| Offline PMTiles | Storage/import ported | package management is native; tile rendering still needs a native renderer such as MapLibre |
| Public trail routing / elevation services | Pending | route service adapters |
| PWA/browser-only diagnostics | Replaced | native system/preflight equivalents |
