//
//  PreferencesRepository.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//


public protocol PreferencesRepository {
    func load(for userId: String) -> UserPreferences?
    func save(_ prefs: UserPreferences, for userId: String)
}
