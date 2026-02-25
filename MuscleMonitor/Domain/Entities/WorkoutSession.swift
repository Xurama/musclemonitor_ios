//
//  WorkoutSession.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 23/09/2025.
//


import Foundation

public struct WorkoutSession: Identifiable, Codable, Sendable, Equatable {
    public struct SetResult: Codable, Sendable, Equatable {
        public var reps: Int
        public var weight: Double
        public var isWarmup: Bool

        public init(reps: Int, weight: Double, isWarmup: Bool = false) {
            self.reps = reps
            self.weight = weight
            self.isWarmup = isWarmup
        }

        private enum CodingKeys: String, CodingKey {
            case reps, weight, isWarmup
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            reps = try c.decode(Int.self, forKey: .reps)
            weight = try c.decode(Double.self, forKey: .weight)
            isWarmup = try c.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        }
    }

    public struct ExerciseResult: Identifiable, Codable, Sendable, Equatable {
        public var id: String { exerciseId }
        public var exerciseId: String
        public var name: String
        public var sets: [SetResult]
        public let equipment: Workout.Equipment?
        public init(exerciseId: String, name: String, sets: [SetResult], equipment: Workout.Equipment?) {
            self.exerciseId = exerciseId
            self.name = name
            self.sets = sets
            self.equipment = equipment
        }
    }

    public var id: String
    public var workoutId: String
    public var title: String
    public var startedAt: Date
    public var endedAt: Date
    public var durationSec: Int { max(0, Int(endedAt.timeIntervalSince(startedAt))) }
    public var exercises: [ExerciseResult]

    public init(
        id: String = UUID().uuidString,
        workoutId: String,
        title: String,
        startedAt: Date,
        endedAt: Date,
        exercises: [ExerciseResult]
    ) {
        self.id = id; self.workoutId = workoutId; self.title = title
        self.startedAt = startedAt; self.endedAt = endedAt; self.exercises = exercises
    }
}
