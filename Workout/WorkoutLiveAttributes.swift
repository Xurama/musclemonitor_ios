//
//  WorkoutAttributes.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 19/09/2025.
//

import Foundation
import ActivityKit

public struct WorkoutLiveAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        // État qui évolue
        public var workoutTitle: String               // "Push Day"
        public var exerciseName: String               // "Développé couché"
        public var setIndex: Int                      // set courant (1-based)
        public var totalSets: Int                     // total sets
        public var nextReps: Int?                     // prochaine série: reps
        public var nextWeight: Double?                // prochaine série: poids (kg)
        public var progress: Double                   // progression globale 0...1
        public var isResting: Bool                    // en repos ?
        public var restEndsAt: Date?                  // fin du repos (si en repos)

        public init(
            workoutTitle: String,
            exerciseName: String,
            setIndex: Int,
            totalSets: Int,
            nextReps: Int?,
            nextWeight: Double?,
            progress: Double,
            isResting: Bool,
            restEndsAt: Date?
        ) {
            self.workoutTitle = workoutTitle
            self.exerciseName = exerciseName
            self.setIndex = setIndex
            self.totalSets = totalSets
            self.nextReps = nextReps
            self.nextWeight = nextWeight
            self.progress = progress
            self.isResting = isResting
            self.restEndsAt = restEndsAt
        }
    }

    // Attributs fixes (identité de la session)
    public var workoutId: String

    public init(workoutId: String) {
        self.workoutId = workoutId
    }
}

