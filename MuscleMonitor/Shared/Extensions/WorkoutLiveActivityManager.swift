//
//  WorkoutLiveActivityManager.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 23/09/2025.
//


import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()
    private init() {}

    private var activity: Activity<WorkoutLiveAttributes>?

    // Lance une activité (ex: à l’ouverture de WorkoutRunView)
    func start(workoutId: String,
               workoutTitle: String,
               firstExerciseName: String,
               totalSets: Int,
               nextReps: Int?,
               nextWeight: Double?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let info = ActivityAuthorizationInfo()
        print("LA enabled:", info.areActivitiesEnabled)
        
        let attributes = WorkoutLiveAttributes(workoutId: workoutId)

        let state = WorkoutLiveAttributes.ContentState(
            workoutTitle: workoutTitle,
            exerciseName: firstExerciseName,
            setIndex: 1,
            totalSets: max(1, totalSets),
            nextReps: nextReps,
            nextWeight: nextWeight,
            progress: 0,
            isResting: false,
            restEndsAt: nil
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            print("Started LA:", activity?.id ?? "-")
        } catch {
            print("LA start error:", error)
        }
    }

    // Met à jour pendant la séance (set commencé / repos / progression)
    func update(
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
        guard let activity else { return }
        let state = WorkoutLiveAttributes.ContentState(
            workoutTitle: workoutTitle,
            exerciseName: exerciseName,
            setIndex: max(1, setIndex),
            totalSets: max(1, totalSets),
            nextReps: nextReps,
            nextWeight: nextWeight,
            progress: max(0, min(1, progress)),
            isResting: isResting,
            restEndsAt: restEndsAt
        )
        Task { await activity.update(using: state) }
    }

    func end(success: Bool = true) {
        guard let activity else { return }
        Task {
            await activity.end(dismissalPolicy: success ? .immediate : .default)
            self.activity = nil
        }
    }
}
