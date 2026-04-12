import Foundation
import CoreLocation

final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private let userDefaults: UserDefaults

    private let visitsKey = "locationVisits"

    @Published var isTracking = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Log every 100m movement
    }

    // MARK: - Permission

    func requestPermission() {
        // iOS requires requesting "When In Use" first, then "Always"
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    // MARK: - Tracking

    func startTracking() {
        // Only enable background updates if "Always" authorization is granted
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
        }
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        isTracking = true
        print("[dAIry] Location tracking started (background: \(locationManager.authorizationStatus == .authorizedAlways))")
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
    }

    // MARK: - Fetch visits for a CollectionWindow

    func visits(for window: CollectionWindow) -> [LocationVisit] {
        let allVisits = loadVisits()
        return allVisits.filter { $0.timestamp >= window.start && $0.timestamp < window.end }
    }

    // MARK: - Clear old data

    func clearVisits(before date: Date) {
        var visits = loadVisits()
        visits.removeAll { $0.timestamp < date }
        saveVisits(visits)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var visits = loadVisits()
        for location in locations {
            let visit = LocationVisit(
                coordinate: location.coordinate,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy
            )
            visits.append(visit)
            print("[dAIry] Location logged: \(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
        }
        saveVisits(visits)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("[dAIry] Location authorization changed: \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse:
            // Step 2: Now request "Always" upgrade
            locationManager.requestAlwaysAuthorization()
            startTracking()
        case .authorizedAlways:
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            startTracking()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[dAIry] Location error: \(error)")
    }

    // MARK: - Persistence (UserDefaults)

    private func loadVisits() -> [LocationVisit] {
        guard let data = userDefaults.data(forKey: visitsKey),
              let visits = try? JSONDecoder().decode([LocationVisit].self, from: data) else {
            return []
        }
        return visits
    }

    private func saveVisits(_ visits: [LocationVisit]) {
        if let data = try? JSONEncoder().encode(visits) {
            userDefaults.set(data, forKey: visitsKey)
        }
    }
}
