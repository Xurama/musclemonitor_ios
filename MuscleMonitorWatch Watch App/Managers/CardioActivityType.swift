import Foundation
import HealthKit
import SwiftUI

enum CardioActivityType: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    case running
    case cycling
    case swimming

    var displayName: String {
        switch self {
        case .running:  return "Course"
        case .cycling:  return "Vélo"
        case .swimming: return "Natation"
        }
    }

    var systemImage: String {
        switch self {
        case .running:  return "figure.run"
        case .cycling:  return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        }
    }

    var subtitle: String {
        switch self {
        case .running:  return "GPS · Allure · FC"
        case .cycling:  return "GPS · Vitesse · FC"
        case .swimming: return "Longueurs · FC"
        }
    }

    var color: Color {
        switch self {
        case .running:  return .orange
        case .cycling:  return .green
        case .swimming: return .blue
        }
    }

    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .running:  return .running
        case .cycling:  return .cycling
        case .swimming: return .swimming
        }
    }

    /// Natation = piscine, pas de GPS
    var isOutdoor: Bool {
        switch self {
        case .running, .cycling: return true
        case .swimming:          return false
        }
    }

    var locationType: HKWorkoutSessionLocationType {
        isOutdoor ? .outdoor : .indoor
    }

    var distanceQuantityType: HKQuantityType {
        switch self {
        case .running:  return HKQuantityType(.distanceWalkingRunning)
        case .cycling:  return HKQuantityType(.distanceCycling)
        case .swimming: return HKQuantityType(.distanceSwimming)
        }
    }
}
