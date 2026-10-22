import Foundation
import CoreLocation
import Observation

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    /// Colombo city centre. Used when the location is unavailable or outside Sri Lanka.
    static let demoLocation = CLLocation(latitude: 6.9271, longitude: 79.8612)
    private static let serviceRadius: CLLocationDistance = 60_000

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var deviceLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    /// The device location when it's within the supported area, otherwise Colombo.
    var effectiveLocation: CLLocation {
        if let deviceLocation, deviceLocation.distance(from: Self.demoLocation) <= Self.serviceRadius {
            return deviceLocation
        }
        return Self.demoLocation
    }

    var isUsingDemoLocation: Bool { effectiveLocation === Self.demoLocation }

    var statusText: String {
        switch authorization {
        case .denied, .restricted:
            return "Location is off. Showing stores near Colombo."
        case .notDetermined:
            return "Showing stores near Colombo."
        default:
            return isUsingDemoLocation ? "You're outside the service area. Showing stores near Colombo." : "Using your current location."
        }
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func distance(to branch: StoreBranch) -> CLLocationDistance {
        effectiveLocation.distance(from: CLLocation(latitude: branch.coordinate.latitude, longitude: branch.coordinate.longitude))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.deviceLocation = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

enum DistanceFormatter {
    static func string(_ meters: CLLocationDistance) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
}
