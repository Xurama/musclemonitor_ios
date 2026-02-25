//
//  WorkoutsView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct WorkoutsHomeView: View {
    @ObservedObject var session: SessionViewModel
    let workoutsRepo: WorkoutRepository
    let exercisesRepo: ExerciseCatalogRepository
    let sessionRepo: WorkoutSessionRepository
    let calorieRepo: CalorieRepository
    let prefsRepo: PreferencesRepository
    
    @EnvironmentObject private var tabRouter: TabRouter   // NEW

    var body: some View {
        TabView(selection: $tabRouter.selected) {         // NEW
            HomeTabView(workoutsRepo: workoutsRepo, exercisesRepo: exercisesRepo, sessionRepo: sessionRepo, prefsRepo: prefsRepo, userId: session.user?.id ?? "guest")
                .tabItem { Label("home", systemImage: "house.fill") }
                .tag(AppTab.home)                          // NEW

            StatsTabView(
                sessionRepo: sessionRepo,
                exercisesRepo: exercisesRepo,
                calorieRepo: calorieRepo,
                prefsRepo: prefsRepo,
                userId: session.user?.id ?? "guest"
            )
                .tabItem { Label("stats", systemImage: "chart.bar.fill") } // .fill pour la cohérence
                .tag(AppTab.stats)
            
            CalendarTabView(sessionRepo: sessionRepo)
                .tabItem { Label("calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)                      // NEW

            CaloriesTabView(repo: calorieRepo)
                .tabItem { Label("calories", systemImage: "flame.fill") }
                .tag(AppTab.calories)                      // NEW

            if let user = session.user {
                SettingsTabView(user: user, repo: PreferencesRepositoryImpl())
                    .tabItem { Label("settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)                  // NEW
            }
        }
        .fullScreenCover(isPresented: $session.isRunPresented) {
            if let vm = session.runVM {
                WorkoutRunView(vm: vm)
                    .environmentObject(session)
            }
        }
    }
}

