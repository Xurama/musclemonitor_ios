//
//  HomeViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 12/09/2025.
//

// HomeViewModel.swift

import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var isPresentingCreate = false
    @Published var isPresentingEdit   = false
    @Published var editingWorkout: Workout? = nil

    // Lancement
    @Published var toConfirmStart: Workout? = nil
    @Published var runTarget: Workout? = nil
    
    @Published var isPresentingManual = false
    @Published var defaultManualDate: Date = .now

    struct ManualSessionDraft: Equatable {
        var workout: Workout
        var day: Date              // jour choisi (sans tenir compte de l'heure)
        var startTime: Date          // uniquement l'heure/minute choisies
        var durationMin: Int
        var notes: String = ""
        var inputs: [ManualExerciseInput]
    }
    
    struct ManualExerciseInput: Equatable, Identifiable {
        var id: String { exerciseId }
        let exerciseId: String
        let name: String
        var reps: [Int]
        var weights: [Double]
    }

    // ➕ Ajouts
    private let workoutsRepo: WorkoutRepository
    private let sessionRepo: WorkoutSessionRepository
    private let prefsRepo: PreferencesRepository
    private let userId: String
    
    @Published var sessions: [WorkoutSession] = []
    @Published var weekCompleted: Int = 0
    @Published var weekTarget: Int = 4

    init(workoutsRepo: WorkoutRepository,
         sessionRepo: WorkoutSessionRepository, prefsRepo: PreferencesRepository, userId: String) {
        self.workoutsRepo = workoutsRepo
        self.sessionRepo  = sessionRepo
        self.prefsRepo = prefsRepo
        self.userId = userId
    }

    func load() async {
        // 1. Charger les préférences d'abord
        if let prefs = prefsRepo.load(for: userId) {
            self.weekTarget = prefs.weeklyGoal
        }
        
        // 2. Charger le reste
        await loadWorkouts()
        await loadSessions()
        computeWeekStats()
    }

    private func loadWorkouts() async {
        do { workouts = try await workoutsRepo.list() }
        catch { workouts = [] }
    }

    private func loadSessions() async {
        do { sessions = try await sessionRepo.list() }
        catch { sessions = [] }
    }

    private func weekBounds(for date: Date = .now) -> (start: Date, end: Date) {
        var cal = Calendar.current
        cal.locale = .current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return (start, end)
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func isInCurrentWeek(_ d: Date) -> Bool {
        let (s, e) = weekBounds()
        return (s...e).contains(d)
    }

    private func computeWeekStats() {
        weekCompleted = sessions.reduce(into: Set<Date>()) { acc, s in
            if isInCurrentWeek(s.endedAt) {
                acc.insert(Calendar.current.startOfDay(for: s.endedAt))
            }
        }.count
    }

    // Pour le calendrier : y a-t-il une séance ce jour-là ?
    func hasSession(on date: Date) -> Bool {
        sessions.contains { isSameDay($0.endedAt, date) }
    }

    // Actions existantes
    func requestStart(_ w: Workout) { toConfirmStart = w }
    func requestEdit(_ w: Workout)  { editingWorkout = w; isPresentingEdit = true }
    func requestDelete(_ w: Workout){ toConfirmDelete = w }
    @Published var toConfirmDelete: Workout? = nil

    func confirmDelete() {
        guard let w = toConfirmDelete else { return }
        Task { @MainActor in
            do {
                try await workoutsRepo.delete(id: w.id)
                toConfirmDelete = nil
                await loadWorkouts()
            } catch {
                toConfirmDelete = nil
            }
        }
    }
    
    func didCreate(_ new: Workout) {
        isPresentingCreate = false
        Task { @MainActor in
            do {
                try await workoutsRepo.add(new)     // ⬅️ on SAUVE
                await loadWorkouts()                // puis on recharge
            } catch {
                print("[MM][Workouts] add ERROR:", error)
            }
        }
    }

    func didEdit(_ edited: Workout) {
        isPresentingEdit = false
        editingWorkout = nil
        Task { @MainActor in
            do {
                try await workoutsRepo.update(edited) // ⬅️ on MET À JOUR
                await loadWorkouts()                  // puis on recharge
            } catch {
                print("[MM][Workouts] update ERROR:", error)
            }
        }
    }
    
    func didAddManual(_ draft: ManualSessionDraft) {
        // 1) startedAt = jour + heure de début
        let cal = Calendar.current
        let dcDay  = cal.dateComponents([.year, .month, .day], from: draft.day)
        var dcTime = cal.dateComponents([.hour, .minute, .second], from: draft.startTime)
        dcTime.year = dcDay.year; dcTime.month = dcDay.month; dcTime.day = dcDay.day
        let startedAt = cal.date(from: dcTime) ?? Date()

        // 2) bornes/validation + endedAt
        let duration = max(5, min(24*60, draft.durationMin))
        let endedAt  = startedAt.addingTimeInterval(TimeInterval(duration * 60))

        // 3) construire les ExerciseResult à partir des inputs
        let exResults: [WorkoutSession.ExerciseResult] = draft.inputs.map { input in
            let count = min(input.reps.count, input.weights.count)
            let sets = (0..<count).map { i in
                WorkoutSession.SetResult(
                    reps: max(0, input.reps[i]),
                    weight: max(0, input.weights[i])
                )
            }
            
            // On va chercher l'équipement défini dans le workout d'origine pour cet exercice
            let originalEquipment = draft.workout.exercises.first(where: { $0.id == input.exerciseId })?.equipment
            
            // ✅ On ajoute le paramètre 'equipment' manquant
            return .init(
                exerciseId: input.exerciseId,
                name: input.name,
                sets: sets,
                equipment: originalEquipment
            )
        }

        let session = WorkoutSession(
            workoutId: draft.workout.id,
            title: draft.workout.displayTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            exercises: exResults
        )

        Task { @MainActor in
            do {
                try await sessionRepo.add(session)
                isPresentingManual = false
                await loadSessions()
                computeWeekStats()
            } catch {
                print("[MM][Sessions] manual add ERROR:", error)
            }
        }
    }
}
