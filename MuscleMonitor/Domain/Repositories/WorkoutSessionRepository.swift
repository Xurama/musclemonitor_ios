//
//  WorkoutSessionRepository.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 23/09/2025.
//


import Foundation

public protocol WorkoutSessionRepository {
    func add(_ session: WorkoutSession) async throws
    func list() async throws -> [WorkoutSession]
    func delete(id: String) async throws
    func clearAll() async throws
}
