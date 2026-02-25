//
//  EditSessionView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 01/10/2025.
//


//
//  EditSessionView.swift
//  MuscleMonitor
//

import SwiftUI

struct EditSessionView: View {
    let original: WorkoutSession
    let onCancel: () -> Void
    let onSave: (WorkoutSession) -> Void

    // État éditable
    @State private var day: Date
    @State private var startTime: Date
    @State private var durationMinText: String
    @State private var inputs: [ExerciseInput]

    init(original: WorkoutSession, onCancel: @escaping () -> Void, onSave: @escaping (WorkoutSession) -> Void) {
        self.original = original
        self.onCancel = onCancel
        self.onSave = onSave

        // Pré-remplissage
        let cal = Calendar.current
        _day = State(initialValue: cal.startOfDay(for: original.endedAt))
        _startTime = State(initialValue: original.startedAt)
        let durationMin = max(1, Int(original.endedAt.timeIntervalSince(original.startedAt) / 60))
        _durationMinText = State(initialValue: "\(durationMin)")
        _inputs = State(initialValue: original.exercises.map {
            ExerciseInput(
                exerciseId: $0.exerciseId,
                name: $0.name,
                reps: $0.sets.map { $0.reps },
                weights: $0.sets.map { $0.weight },
                equipment: $0.equipment
            )
        })
    }

    var body: some View {
        Form {
            Section("when") {
                DatePicker("day", selection: $day, displayedComponents: .date)
                DatePicker("start_time", selection: $startTime, displayedComponents: .hourAndMinute)
            }

            Section("duration") {
                HStack {
                    Text("total")
                    Spacer()
                    TextField("", text: $durationMinText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            Section("exercises") {
                ForEach(inputs.indices, id: \.self) { idx in
                    EditExerciseRow(exInput: $inputs[idx])
                }
            }
        }
        .navigationTitle("edit_session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("save") {
                    guard let mins = Int(durationMinText.trimmingCharacters(in: .whitespaces)),
                          mins > 0 else { return }

                    // Reconstruire endedAt (jour + heure)
                    var cal = Calendar.current
                    let dcDay = cal.dateComponents([.year,.month,.day], from: day)
                    var dcTime = cal.dateComponents([.hour,.minute,.second], from: startTime)
                    dcTime.year = dcDay.year; dcTime.month = dcDay.month; dcTime.day = dcDay.day
                    let newEnded = cal.date(from: dcTime) ?? original.endedAt
                    let newStarted = newEnded.addingTimeInterval(TimeInterval(-mins * 60))

                    // Reconstruire les résultats d’exercices
                    let exResults: [WorkoutSession.ExerciseResult] = inputs.map { inp in
                        let count = min(inp.reps.count, inp.weights.count)
                        let sets = (0..<count).map { i in
                            WorkoutSession.SetResult(
                                reps: max(0, min(200, inp.reps[i])),
                                weight: max(0, min(1000, inp.weights[i]))
                            )
                        }
                        // ✅ Ajout de l'argument 'equipment' manquant
                        return .init(
                            exerciseId: inp.exerciseId,
                            name: inp.name,
                            sets: sets,
                            equipment: inp.equipment
                        )
                    }

                    // ⚠️ Conserver l'ID pour que CalendarViewModel puisse faire delete+add
                    let updated = WorkoutSession(
                        id: original.id,
                        workoutId: original.workoutId,
                        title: original.title,
                        startedAt: newStarted,
                        endedAt: newEnded,
                        exercises: exResults
                    )

                    onSave(updated)
                }
            }
        }
    }

    // MARK: - Types internes
    struct ExerciseInput: Identifiable, Equatable {
        var id: String { exerciseId }
        let exerciseId: String
        let name: String
        var reps: [Int]
        var weights: [Double]
        let equipment: Workout.Equipment?
    }
}

private struct EditExerciseRow: View {
    @Binding var exInput: EditSessionView.ExerciseInput

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exInput.name).font(.headline)
                Spacer()
                Menu {
                    Button("copy_reps_from_set") {
                        if let f = exInput.reps.first {
                            for i in exInput.reps.indices { exInput.reps[i] = f }
                        }
                    }
                    Button("copy_weight_from_set") {
                        if let f = exInput.weights.first {
                            for i in exInput.weights.indices { exInput.weights[i] = f }
                        }
                    }
                } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                }
            }

            ForEach(exInput.reps.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Text("Set \(i+1)").frame(width: 64, alignment: .leading)

                    HStack(spacing: 6) {
                        Text("Reps").foregroundStyle(.secondary)
                        TextField("", text: Binding(
                            get: { String(exInput.reps[i]) },
                            set: { t in if let v = Int(t.trimmingCharacters(in: .whitespaces)) {
                                exInput.reps[i] = max(0, min(200, v))
                            }}
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 6) {
                        Text("weight").foregroundStyle(.secondary)
                        TextField("", text: Binding(
                            get: {
                                let v = exInput.weights[i]
                                return v == 0 ? "" : (v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v))
                            },
                            set: { t in
                                if t.isEmpty { exInput.weights[i] = 0; return }
                                let n = t.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                                if let v = Double(n) { exInput.weights[i] = max(0, min(1000, v)) }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)

                if i < exInput.reps.count - 1 { Divider() }
            }
        }
        .padding(.vertical, 4)
    }
}
