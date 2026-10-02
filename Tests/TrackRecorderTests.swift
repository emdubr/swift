import Foundation
import CoreLocation

@main
@MainActor
struct TrackRecorderTests {
    private static func fix(_ latitude: Double, _ longitude: Double, _ altitude: Double,
                            _ seconds: TimeInterval, accuracy: CLLocationAccuracy = 3) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                   altitude: altitude, horizontalAccuracy: accuracy, verticalAccuracy: 3,
                   course: -1, speed: 2, timestamp: Date(timeIntervalSince1970: 1000 + seconds))
    }

    static func main() {
        let recorder = TrackRecorder()
        let a = fix(44.0, -73.0, 100, 0)
        let b = fix(44.001, -73.0, 115, 10)
        let c = fix(44.002, -73.0, 111, 20)
        recorder.start()
        recorder.ingest(a)
        recorder.ingest(a)
        recorder.ingest(fix(44.01, -73.0, 200, 5, accuracy: -1))
        assert(recorder.points.count == 1)
        recorder.ingest(b)
        let distanceAB = a.distance(from: b)
        assert(abs(recorder.distanceMeters - distanceAB) < 0.5)
        assert(abs(recorder.ascentMeters - 15) < 0.001)
        recorder.pause()
        recorder.ingest(c)
        assert(recorder.points.count == 2)
        recorder.resume()
        recorder.ingest(fix(44.1, -73, 0, 9)) // Out-of-order fix must not add a false jump.
        assert(recorder.points.count == 2)
        recorder.ingest(c)
        assert(recorder.points.count == 3)
        assert(abs(recorder.distanceMeters - (distanceAB + b.distance(from: c))) < 0.5)
        assert(abs(recorder.ascentMeters - 15) < 0.001)
        assert(recorder.route().points.count == recorder.points.count)
        recorder.stop()
        recorder.ingest(fix(44.003, -73, 200, 30))
        assert(recorder.points.count == 3)
        recorder.start()
        assert(recorder.points.isEmpty && recorder.distanceMeters == 0 && recorder.ascentMeters == 0)
        recorder.reset()
        assert(recorder.state == .stopped && recorder.startedAt == nil)
        print("PASS: incremental track distance/ascent, duplicate and bad fix filtering, pause/resume, restart/reset")
    }
}
