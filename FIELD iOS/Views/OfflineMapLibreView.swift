import CoreLocation
import MapLibre
import SwiftUI

// Real on-device MapLibre PMTiles rendering. Local style JSON contains only file:// sources.
// The map is created once and route/waypoint annotations are updated without camera resets.
struct OfflineCameraCommand: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let zoom: Double
}

struct OfflineMapLibreView: UIViewRepresentable {
    let styleURL: URL
    let initialCenter: CLLocationCoordinate2D
    let initialZoom: Double
    let route: FieldRoute?
    let waypoints: [Waypoint]
    let command: OfflineCameraCommand?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let view = MLNMapView(frame: .zero, styleURL: styleURL)
        view.delegate = context.coordinator
        view.setCenter(initialCenter, zoomLevel: initialZoom, animated: false)
        view.showsUserLocation = true
        view.logoView.isHidden = false // Preserve required attribution.
        context.coordinator.latestRoute = route
        context.coordinator.latestWaypoints = waypoints
        return view
    }

    func updateUIView(_ view: MLNMapView, context: Context) {
        let c = context.coordinator
        c.latestRoute = route
        c.latestWaypoints = waypoints
        if view.styleURL != styleURL {
            c.mapReady = false
            c.removeOwned(from: view)
            view.styleURL = styleURL
        } else if c.mapReady { c.updateAnnotations(on: view) }
        if let command, c.lastCommandID != command.id {
            c.lastCommandID = command.id
            view.setCenter(command.coordinate, zoomLevel: command.zoom, animated: true)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var mapReady = false
        var latestRoute: FieldRoute?
        var latestWaypoints: [Waypoint] = []
        var owned: [MLNAnnotation] = []
        var lastCommandID: UUID?
        private var latestGeometryID: String?

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            mapReady = true
            latestGeometryID = nil
            updateAnnotations(on: mapView)
        }
        func removeOwned(from mapView: MLNMapView) {
            if !owned.isEmpty { mapView.removeAnnotations(owned) }
            owned = []
            latestGeometryID = nil
        }
        func updateAnnotations(on mapView: MLNMapView) {
            // Stable content signature means gestures and camera motions do not redraw overlays.
            let routeID = latestRoute.map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970):\($0.points.count)" } ?? "none"
            let wpID = latestWaypoints.map { "\($0.id):\($0.point.latitude):\($0.point.longitude)" }.joined(separator: "|")
            let key = routeID + "|" + wpID
            guard latestGeometryID != key else { return }
            removeOwned(from: mapView)
            var new: [MLNAnnotation] = []
            if let route = latestRoute, route.points.count > 1 {
                var coordinates = route.points.map(\.coordinate)
                let polyline = MLNPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                polyline.title = route.name
                new.append(polyline)
            }
            for waypoint in latestWaypoints {
                let pin = MLNPointAnnotation()
                pin.coordinate = waypoint.point.coordinate
                pin.title = waypoint.name
                pin.subtitle = waypoint.kind.rawValue
                new.append(pin)
            }
            if !new.isEmpty { mapView.addAnnotations(new) }
            owned = new
            latestGeometryID = key
        }
        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            UIColor(red: 0.95, green: 0.67, blue: 0.2, alpha: 1)
        }
        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat { 4 }
    }
}
