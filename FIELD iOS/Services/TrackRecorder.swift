import CoreLocation
import Foundation

@MainActor
final class TrackRecorder: ObservableObject {
    enum State: String { case stopped = "STOPPED", recording = "RECORDING", paused = "PAUSED" }

    @Published private(set) var state: State = .stopped
    @Published private(set) var startedAt: Date?
    @Published private(set) var points: [RoutePoint] = []
    @Published private(set) var maxSpeedMPS: Double = 0

    func start() {
        points = []
        startedAt = .now
        maxSpeedMPS = 0
        state = .recording
    }
    func pause() { if state == .recording { state = .paused } }
    func resume() { if state == .paused { state = .recording } }
    func stop() { state = .stopped }
    func reset() { state = .stopped; startedAt = nil; points = []; maxSpeedMPS = 0 }

    func ingest(_ location: CLLocation) {
        guard state == .recording, location.horizontalAccuracy >= 0 else { return }
        if let last = points.last {
            let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            if location.distance(from: lastLocation) < 3 { return }
        }
        points.append(RoutePoint(location: location))
        if location.speed >= 0 { maxSpeedMPS = max(maxSpeedMPS, location.speed) }
        if points.count > 100_000 { points.removeFirst(points.count - 100_000) }
    }

    var distanceMeters: Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + RouteEngine.distanceMeters($1.0, $1.1) }
    }

    var ascentMeters: Double {
        zip(points, points.dropFirst()).reduce(0) { result, pair in
            guard let a = pair.0.elevation, let b = pair.1.elevation else { return result }
            return result + max(0, b - a)
        }
    }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    func route(name: String = "Recorded Track") -> FieldRoute {
        FieldRoute(name: name, points: points, terrain: .maintained, createdAt: startedAt ?? .now, updatedAt: .now)
    }
}
