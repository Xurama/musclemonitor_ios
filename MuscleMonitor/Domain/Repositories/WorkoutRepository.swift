//
//  WorkoutRepository.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 12/09/2025.
//


public protocol WorkoutRepository {
    func list() async throws -> [Workout]
    func add(_ workout: Workout) async throws
    func update(_ workout: Workout) async throws
    func delete(id: String) async throws
}
