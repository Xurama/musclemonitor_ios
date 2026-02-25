//
//  PreferencesRepositoryImpl.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//


import Foundation

final class PreferencesRepositoryImpl: PreferencesRepository {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load(for userId: String) -> UserPreferences? {
        let key = storageKey(userId)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserPreferences.self, from: data)
    }

    func save(_ prefs: UserPreferences, for userId: String) {
        let key = storageKey(userId)
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: key)
        }
    }

    private func storageKey(_ userId: String) -> String { "prefs.\(userId)" }
}
