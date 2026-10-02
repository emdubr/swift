import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLHeading?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.headingFilter = 2
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestAuthorization() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        start()
    }

    func start() {
        guard CLLocationManager.locationServicesEnabled() else {
            lastError = "Location services are disabled."
            return
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func setHighAccuracy(_ enabled: Bool) {
        manager.desiredAccuracy = enabled ? kCLLocationAccuracyBest : kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = enabled ? 3 : 10
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways { start() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let candidate = locations.last, candidate.horizontalAccuracy >= 0 {
            location = candidate
            lastError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}

extension LocationService {
    var headingDegrees: Double? {
        guard let heading else { return nil }
        let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        return value >= 0 ? value : nil
    }
    var speedMPH: Double? {
        guard let speed = location?.speed, speed >= 0 else { return nil }
        return speed * 2.236936
    }
}
