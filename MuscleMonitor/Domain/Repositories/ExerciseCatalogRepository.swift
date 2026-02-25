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

// ✅ Implémentation réelle avec tes clés techniques
final class ExerciseCatalogRepositoryLocal: ExerciseCatalogRepository {
    func allExercises() async -> [String] {
        return [
            "db_bench_press",
            "db_incline_press",
            "chest_fly_machine",
            "dips_weighted",
            "barbell_shoulder_press",
            "db_lateral_raises",
            "face_pulls",
            "deadlift",
            "lat_pulldown",
            "seated_row",
            "shrugs",
            "pullups",
            "triceps_pushdown",
            "biceps_curl",
            "squat",
            "leg_press",
            "hip_thrust",
            "leg_curl",
            "leg_extension",
            "calf_raise",
            "hip_abduction",
            "plank",
            "leg_raises",
            "dynamic_plank_taps",
            "hanging_leg_raises",
            "dynamic_plank",
            "side_crunch",
            "side_plank",
            "mountain_climbers",
            "hollow_body_hold",
            "scapular_pull_ups",
            "running",
            "rowing_machine",
            "stationary_bike",
            "elliptical_bike",
            "walking_lunges",
            "db_thrusters",
            "burpees"
        ]
    }
}
