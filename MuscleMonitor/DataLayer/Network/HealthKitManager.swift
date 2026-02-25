//
//  HealthKitManager.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 29/12/2025.
//


import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    // Types de données à lire
    private let typesToRead: Set = [
        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned)!
    ]

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            return true
        } catch {
            print("Erreur d'autorisation HealthKit: \(error.localizedDescription)")
            return false
        }
    }

    func fetchEnergy(for date: Date) async -> (active: Double, basal: Double) {
        let active = await fetchSum(for: .activeEnergyBurned, date: date)
        let basal  = await fetchSum(for: .basalEnergyBurned, date: date)
        return (active, basal)
    }

    private func fetchSum(for identifier: HKQuantityTypeIdentifier, date: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
}
