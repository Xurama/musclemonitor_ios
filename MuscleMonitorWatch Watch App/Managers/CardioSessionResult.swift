import Foundation

/// Résultat complet d'une séance cardio, envoyé vers l'iPhone via WatchConnectivity
struct CardioSessionResult: Codable {
    let activityType: CardioActivityType
    let startedAt: Date
    let endedAt: Date
    let distanceMeters: Double
    let activeCalories: Double
    let heartRateSamples: [HeartRateSample]
    let routeCoordinates: [GPSCoordinate]

    var durationSec: Int { max(0, Int(endedAt.timeIntervalSince(startedAt))) }
    var distanceKm: Double { distanceMeters / 1000 }

    struct HeartRateSample: Codable {
        let bpm: Double
        let date: Date
    }

    struct GPSCoordinate: Codable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let timestamp: Date
    }
}

extension Notification.Name {
    static let cardioSessionDidEnd = Notification.Name("cardioSessionDidEnd")
}
