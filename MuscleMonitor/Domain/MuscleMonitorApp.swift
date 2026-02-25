//
//  MuscleMonitorApp.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

@main
struct MuscleMonitorApp: App {
    // Repositories (mock pour l’instant)
    private let authRepo: AuthRepository
    private let workoutsRepo: WorkoutRepository
    private let exercisesRepo: ExerciseCatalogRepository
    private let sessionRepo: WorkoutSessionRepository
    private let calorieRepo: CalorieRepository

    @StateObject private var session: SessionViewModel
    @StateObject private var tabRouter = TabRouter()


    init() {
        let auth = AuthRepositoryFake()
        let storedId = UserDefaults.standard.string(forKey: "userId") ?? {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            return newId
        }()
        let workouts = WorkoutRepositoryLocal(userId: storedId)
        let exercises = ExerciseCatalogRepositoryLocal()
        let sessionRepo = WorkoutSessionRepositoryLocal()
        let calorieRepo = CalorieRepositoryLocal()

        self.authRepo = auth
        self.workoutsRepo = workouts
        self.exercisesRepo = exercises
        self.sessionRepo = sessionRepo
        self.calorieRepo = calorieRepo

        _session = StateObject(wrappedValue: SessionViewModel(auth: auth))
        
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                session: session,
                authRepo: authRepo,
                workoutsRepo: workoutsRepo,
                exercisesRepo: exercisesRepo,
                sessionRepo: sessionRepo,
                calorieRepo: calorieRepo
            )
            .environmentObject(session)
            .environmentObject(tabRouter) 
        }
    }
}

