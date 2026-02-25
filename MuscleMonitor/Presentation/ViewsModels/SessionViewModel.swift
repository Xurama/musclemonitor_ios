//
//  SessionViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var user: User? = nil
    private let auth: AuthRepository
    
    @Published var hasActiveWorkout: Bool = false
    @Published var runVM: WorkoutRunViewModel? = nil
    @Published var isRunPresented: Bool = false

    init(auth: AuthRepository) {
        self.auth = auth
        self.user = auth.currentUser()
    }

    func startRun(workout: Workout, repo: WorkoutSessionRepository) {
        self.runVM = WorkoutRunViewModel(workout: workout, sessionRepo: repo)
        self.hasActiveWorkout = true
        self.isRunPresented = true
    }

    func endRun() {
        self.isRunPresented = false
        self.hasActiveWorkout = false
        self.runVM = nil
    }

    func logout() {
        Task {
            await auth.logout()
            user = nil
        }
    }

    func setAuthenticated(_ user: User) { self.user = user }
}
