//
//  ConfigureExerciseRow.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 30/09/2025.
//

import SwiftUI

struct ConfigureExerciseRow: View {
    @State var exercise: Workout.Exercise
    let onChange: (Workout.Exercise) -> Void

    @State private var showEdit = false

    var body: some View {
        Button {
            showEdit = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(exercise.name))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        SummaryBadge(text: effortSummary(exercise))
                        SummaryDot()
                        SummaryBadge(text: "Repos \(exercise.restSec)s")
                        if let eq = exercise.equipment {
                            SummaryDot()
                            SummaryBadge(text: eq.display)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            EditExerciseSheet(exercise: exercise) { updated in
                exercise = updated
                onChange(updated)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func effortSummary(_ ex: Workout.Exercise) -> String {
        if ex.isCardio {
            let s = ex.targetSeconds
            let h = s / 3600
            let m = (s % 3600) / 60
            if h > 0 {
                return "\(h)h \(m)min"
            } else {
                return "\(m) min"
            }
        }
        
        switch ex.effort {
        case .reps(let r): return "\(ex.sets)×\(r)"
        case .time(let s): return "\(ex.sets)×\(s)s"
        }
    }
}

private struct SummaryBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}

private struct SummaryDot: View {
    var body: some View {
        Circle().fill(Color(.tertiaryLabel)).frame(width: 4, height: 4)
    }
}


private struct EditExerciseSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var exercise: Workout.Exercise
    let onSave: (Workout.Exercise) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("general") {
                    HStack {
                        Text("name")
                        Spacer()
                        Text(LocalizedStringKey(exercise.name))
                            .foregroundStyle(.secondary)
                    }
                    Picker("equipment", selection: Binding<Workout.Equipment?>(
                        get: { exercise.equipment },
                        set: { exercise.equipment = $0 }
                    )) {
                        Text("none").tag(Optional<Workout.Equipment>.none)
                        ForEach(Workout.Equipment.allCases) { eq in
                            Text(eq.display).tag(Optional(eq))
                        }
                    }
                }
                
                // Dans EditExerciseSheet
                Section("settings") {
                    if exercise.isCardio {
                        // --- MODE CARDIO : Affichage simplifié ---
                        VStack(alignment: .leading, spacing: 10) {
                            Text("duration").font(.subheadline).foregroundColor(.secondary)
                            
                            HStack {
                                Picker("Heures", selection: Binding(
                                    get: { exercise.targetSeconds / 3600 },
                                    set: { exercise.effort = .time(seconds: ($0 * 3600) + (exercise.targetSeconds % 3600)) }
                                )) {
                                    ForEach(0..<5) { h in Text("\(h) h").tag(h) }
                                }
                                .pickerStyle(.wheel)
                                
                                Picker("Minutes", selection: Binding(
                                    get: { (exercise.targetSeconds % 3600) / 60 },
                                    set: { exercise.effort = .time(seconds: (exercise.targetSeconds / 3600 * 3600) + ($0 * 60)) }
                                )) {
                                    ForEach(0..<60) { m in Text("\(m) min").tag(m) }
                                }
                                .pickerStyle(.wheel)
                            }
                            .frame(height: 120)
                        }
                        
                        // On force les valeurs internes pour le cardio
                        // (1 seule série, pas de repos) pour ne pas fausser les calculs
                        .onAppear {
                            exercise.sets = 1
                            exercise.restSec = 0
                        }
                        
                    } else {
                        // --- MODE MUSCULATION : Affichage complet ---
                        Stepper("Séries : \(exercise.sets)", value: $exercise.sets, in: 1...10)
                        Stepper("Repos : \(exercise.restSec)s", value: $exercise.restSec, in: 0...300, step: 15)
                        
                        Picker("type_of_effort", selection: Binding(
                            get: {
                                switch exercise.effort { case .reps: return 0; case .time: return 1 }
                            },
                            set: { idx in
                                if idx == 0 {
                                    let r = exercise.targetReps == 0 ? 10 : exercise.targetReps
                                    exercise.effort = .reps(r)
                                } else {
                                    let s = exercise.targetSeconds == 0 ? 60 : exercise.targetSeconds
                                    exercise.effort = .time(seconds: s)
                                }
                            }
                        )) {
                            Text("reps").tag(0)
                            Text("time").tag(1)
                        }
                        
                        // Affichage dynamique reps ou temps (gainage)
                        switch exercise.effort {
                        case .reps(let r):
                            Stepper("Répétitions : \(r)", value: Binding(
                                get: { r },
                                set: { exercise.effort = .reps($0) }
                            ), in: 1...100)
                        case .time(let s):
                            Stepper("Durée : \(s)s", value: Binding(
                                get: { s },
                                set: { exercise.effort = .time(seconds: $0) }
                            ), in: 5...600, step: 5)
                        }
                    }
                }
            }
            .navigationTitle("edit_exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { onSave(exercise); dismiss() }
                }
            }
        }
    }
}
