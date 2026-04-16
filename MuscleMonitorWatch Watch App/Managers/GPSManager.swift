import Foundation
import CoreLocation
import Combine

/// Suit le GPS en temps réel pour la course et le vélo.
/// Automatiquement inactif pour la natation (piscine).
@MainActor
final class GPSManager: NSObject, ObservableObject {

    // MARK: - State publié
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentSpeedMs: Double = 0
    @Published private(set) var currentAltitude: Double = 0
    @Published private(set) var totalDistanceMeters: Double = 0

    var paceSecPerKm: Double {
        guard currentSpeedMs > 0.2 else { return 0 }
        return 1000 / currentSpeedMs
    }

    var paceFormatted: String {
        let s = paceSecPerKm
        guard s > 0 else { return "--:--" }
        return String(format: "%d:%02d /km", Int(s) / 60, Int(s) % 60)
    }

    // MARK: - Privé
    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var isTracking = false
    private(set) var routePoints: [CardioSessionResult.GPSCoordinate] = []

    // MARK: - Init
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter  = 5
        manager.activityType    = .fitness
        manager.allowsBackgroundLocationUpdates = true
    }

    // MARK: - API publique
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking(for activityType: CardioActivityType) {
        guard activityType.isOutdoor,
              CLLocationManager.locationServicesEnabled() else { return }
        routePoints = []
        lastLocation = nil
        totalDistanceMeters = 0
        isTracking = true
        manager.startUpdatingLocation()
    }

    func pauseTracking() {
        manager.stopUpdatingLocation()
    }

    func resumeTracking() {
        guard isTracking else { return }
        manager.startUpdatingLocation()
    }

    /// Arrête le tracking et retourne les points collectés
    func stopTracking() -> [CardioSessionResult.GPSCoordinate] {
        manager.stopUpdatingLocation()
        isTracking = false
        return routePoints
    }

    // MARK: - Privé
    private func process(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 50 else { return }

        currentSpeedMs   = max(0, location.speed)
        currentAltitude  = location.altitude

        routePoints.append(.init(
            latitude:  location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude:  location.altitude,
            timestamp: location.timestamp
        ))

        if let prev = lastLocation {
            let delta = location.distance(from: prev)
            if delta < 200 { totalDistanceMeters += delta }
        }
        lastLocation = location
    }
}

// MARK: - CLLocationManagerDelegate
extension GPSManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationStatus = manager.authorizationStatus }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in locations.forEach { self.process($0) } }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[GPSManager] error:", error)
    }
}
