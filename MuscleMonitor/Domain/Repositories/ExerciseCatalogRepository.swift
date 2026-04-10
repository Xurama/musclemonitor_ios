//
//  ExerciseCatalogRepository.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 12/09/2025.
//


import Foundation

// ✅ Garde le protocole pour définir le "contrat"
public protocol ExerciseCatalogRepository {
    func allExercises() async -> [String]
}

// ✅ Dérive automatiquement de muscleMapping — source unique de vérité
final class ExerciseCatalogRepositoryLocal: ExerciseCatalogRepository {
    func allExercises() async -> [String] {
        return Array(Workout.Exercise.muscleMapping.keys).sorted()
    }
}
