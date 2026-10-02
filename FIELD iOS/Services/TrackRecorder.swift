import CoreLocation
import Foundation

@MainActor
final class TrackRecorder: ObservableObject {
    enum State: String { case stopped = "STOPPED", recording = "RECORDING", paused = "PAUSED" }
    private static let maxPoints = 100_000

    @Published private(set) var state: State = .stopped
    @Published private(set) var startedAt: Date?
    @Published private(set) var points: [RoutePoint] = []
    @Published private(set) var maxSpeedMPS: Double = 0
    // Updated only when a GPS fix is accepted; UI redraws are O(1).
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var ascentMeters: Double = 0

    func start() {
        points = []
        startedAt = .now
        maxSpeedMPS = 0
        distanceMeters = 0
        ascentMeters = 0
        state = .recording
    }
    func pause() { if state == .recording { state = .paused } }
    func resume() { if state == .paused { state = .recording } }
    func stop() { state = .stopped }
    func reset() {
        state = .stopped
        startedAt = nil
        points = []
        maxSpeedMPS = 0
        distanceMeters = 0
        ascentMeters = 0
    }

    private func segmentAscent(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        guard let ea = a.elevation, let eb = b.elevation else { return 0 }
        return max(0, eb - ea)
    }

    func ingest(_ location: CLLocation) {
        guard state == .recording,
              CLLocationCoordinate2DIsValid(location.coordinate),
              location.horizontalAccuracy.isFinite, location.horizontalAccuracy >= 0 else { return }
        let incoming = RoutePoint(location: location)
        if let last = points.last {
            if let timestamp = last.timestamp, location.timestamp <= timestamp { return }
            let segment = RouteEngine.distanceMeters(last, incoming)
            guard segment.isFinite, segment >= 3 else { return }
            distanceMeters += segment
            ascentMeters += segmentAscent(last, incoming)
        }
        points.append(incoming)
        if location.speed.isFinite, location.speed >= 0 {
            maxSpeedMPS = max(maxSpeedMPS, location.speed)
        }
        // Maintain metrics for retained points if a very long session exceeds the cap.
        if points.count > Self.maxPoints {
            let overflow = points.count - Self.maxPoints
            for index in 0..<overflow {
                distanceMeters -= RouteEngine.distanceMeters(points[index], points[index + 1])
                ascentMeters -= segmentAscent(points[index], points[index + 1])
            }
            points.removeFirst(overflow)
            distanceMeters = max(0, distanceMeters)
            ascentMeters = max(0, ascentMeters)
        }
    }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    func route(name: String = "Recorded Track") -> FieldRoute {
        FieldRoute(name: name, points: points, terrain: .maintained,
                   createdAt: startedAt ?? .now, updatedAt: .now)
    }
}
