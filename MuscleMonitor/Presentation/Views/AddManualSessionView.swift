//
//  AddManualSessionView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 01/10/2025.
//


// AddManualSessionView.swift

import SwiftUI

struct AddManualSessionView: View {
    let workouts: [Workout]
    let defaultDate: Date
    let onCancel: () -> Void
    let onSave: (HomeViewModel.ManualSessionDraft) -> Void

    @State private var selectedWorkoutIndex: Int = 0
    @State private var day: Date
    @State private var startTime: Date = Calendar.current
        .date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
    @State private var durationMinText: String = "60"
    @State private var notes: String = ""

    // inputs par exercice (reps/poids par set)
    @State private var inputs: [HomeViewModel.ManualExerciseInput] = []

    init(workouts: [Workout], defaultDate: Date, onCancel: @escaping () -> Void, onSave: @escaping (HomeViewModel.ManualSessionDraft) -> Void) {
        self.workouts = workouts
        self.defaultDate = defaultDate
        self.onCancel = onCancel
        self.onSave = onSave
        _day = State(initialValue: Calendar.current.startOfDay(for: defaultDate))
    }

    var body: some View {
        Form {
            Section("Workout") {
                Picker("model", selection: $selectedWorkoutIndex) {
                    ForEach(workouts.indices, id: \.self) { i in
                        Text(workouts[i].displayTitle).tag(i)
                    }
                }
                .onChange(of: selectedWorkoutIndex) { _ in
                    rebuildInputsFromSelected()
                }
                .onAppear {
                    rebuildInputsFromSelected()
                }
            }

            Section("when") {
                DatePicker("day", selection: $day, displayedComponents: .date)
                DatePicker("start_time", selection: $startTime, displayedComponents: .hourAndMinute)
            }

            Section("duration") {
                HStack {
                    Text("total")
                    Spacer()
                    TextField("60", text: $durationMinText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // === Détails par exercice : Reps / Poids ===
            // === Détails par exercice : Reps / Poids ===
            if !inputs.isEmpty {
                Section("details_by_exercise") {
                    ForEach(inputs.indices, id: \.self) { exIdx in
                        // En-tête (menu copier coller)
                        ExerciseHeader(name: inputs[exIdx].name,
                                       reps: $inputs[exIdx].reps,
                                       weights: $inputs[exIdx].weights)

                        // Chaque set devient une vraie "row" du Form -> swipe par ligne uniquement
                        ForEach(inputs[exIdx].reps.indices, id: \.self) { setIdx in
                            ManualSetRow(
                                setIndex: setIdx,
                                reps: $inputs[exIdx].reps[setIdx],
                                weight: $inputs[exIdx].weights[setIdx]
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    inputs[exIdx].reps.remove(at: setIdx)
                                    inputs[exIdx].weights.remove(at: setIdx)
                                } label: {
                                    Label("delete", systemImage: "trash")
                                }
                                .labelStyle(.iconOnly)  
                            }
                        }

                        // Bouton + : ajoute une rangée de plus
                        Button {
                            inputs[exIdx].reps.append(inputs[exIdx].reps.first ?? 10)
                            inputs[exIdx].weights.append(0)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("add_a_set")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("add_a_session")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("save") {
                    guard workouts.indices.contains(selectedWorkoutIndex),
                          let mins = Int(durationMinText.trimmingCharacters(in: .whitespaces)),
                          mins > 0 else { return }
                    onSave(.init(
                        workout: workouts[selectedWorkoutIndex],
                        day: day,
                        startTime: startTime,
                        durationMin: mins,
                        notes: notes,
                        inputs: inputs
                    ))
                }
            }
        }
    }

    // reconstruit les inputs (reps/poids) à partir du workout choisi
    private func rebuildInputsFromSelected() {
        guard workouts.indices.contains(selectedWorkoutIndex) else { return }
        let w = workouts[selectedWorkoutIndex]
        inputs = w.exercises.map { ex in
            HomeViewModel.ManualExerciseInput(
                exerciseId: ex.id,
                name: ex.name,
                reps: Array(repeating: max(0, ex.targetReps), count: max(0, ex.sets)),
                weights: Array(repeating: 0, count: max(0, ex.sets))
            )
        }
    }
}

// Sous-vue d'édition d’un exercice (liste de sets)
private struct ExerciseEditor: View {
    @Binding var exInput: HomeViewModel.ManualExerciseInput

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exInput.name).font(.headline)
                Spacer()
                Menu {
                    Button("copy_reps_from_set") {
                        if let first = exInput.reps.first {
                            for i in exInput.reps.indices { exInput.reps[i] = first }
                        }
                    }
                    Button("copy_weight_from_set") {
                        if let first = exInput.weights.first {
                            for i in exInput.weights.indices { exInput.weights[i] = first }
                        }
                    }
                } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                }
            }

            ForEach(Array(exInput.reps.indices), id: \.self) { setIdx in
                HStack(spacing: 12) {
                    Text("Set \(setIdx + 1)").frame(width: 64, alignment: .leading)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Text("Reps").foregroundStyle(.secondary)
                        TextField("", text: Binding(
                            get: { String(exInput.reps[setIdx]) },
                            set: { new in
                                let t = new.trimmingCharacters(in: .whitespaces)
                                if let v = Int(t) {
                                    exInput.reps[setIdx] = max(0, min(200, v))
                                }
                            }
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
                                let v = exInput.weights[setIdx]
                                return v == 0 ? "" : (v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v))
                            },
                            set: { new in
                                let t = new.trimmingCharacters(in: .whitespaces)
                                if t.isEmpty { exInput.weights[setIdx] = 0; return }
                                let normalized = t.replacingOccurrences(of: ",", with: ".")
                                if let v = Double(normalized) {
                                    exInput.weights[setIdx] = max(0, min(1000, v))
                                }
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
                .swipeActions {
                    Button(role: .destructive) {
                        // supprime le set et garde les 2 tableaux en phase
                        exInput.reps.remove(at: setIdx)
                        exInput.weights.remove(at: setIdx)
                    } label: {
                        Label("delete", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                }

                if setIdx < exInput.reps.count - 1 {
                    Divider()
                }
            }

            Button {
                exInput.reps.append(exInput.reps.first ?? 10)   // ou une valeur par défaut
                exInput.weights.append(0)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("add_a_set")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 6)
        }
        .padding(.vertical, 4)
    }
}

private struct ExerciseHeader: View {
    let name: String
    @Binding var reps: [Int]
    @Binding var weights: [Double]

    var body: some View {
        HStack {
            Text(name).font(.headline)
            Spacer()
            Menu {
                Button("copy_reps_from_set") {
                    if let first = reps.first {
                        for i in reps.indices { reps[i] = first }
                    }
                }
                Button("copy_weight_from_set") {
                    if let first = weights.first {
                        for i in weights.indices { weights[i] = first }
                    }
                }
            } label: {
                Image(systemName: "rectangle.on.rectangle.angled")
            }
        }
    }
}

private struct ManualSetRow: View {
    let setIndex: Int
    @Binding var reps: Int
    @Binding var weight: Double

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(setIndex + 1)").frame(width: 64, alignment: .leading)

            Spacer(minLength: 0)

            // Reps
            HStack(spacing: 6) {
                Text("Reps").foregroundStyle(.secondary)
                TextField("", text: Binding(
                    get: { String(reps) },
                    set: { new in
                        if let v = Int(new.trimmingCharacters(in: .whitespaces)) {
                            reps = max(0, min(200, v))
                        }
                    }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .textFieldStyle(.roundedBorder)
            }

            // Poids
            HStack(spacing: 6) {
                Text("weight").foregroundStyle(.secondary)
                TextField("", text: Binding(
                    get: {
                        if weight == 0 { return "" }
                        return weight.truncatingRemainder(dividingBy: 1) == 0
                            ? String(Int(weight))
                            : String(weight)
                    },
                    set: { new in
                        let t = new.trimmingCharacters(in: .whitespaces)
                        if t.isEmpty { weight = 0; return }
                        let normalized = t.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(normalized) {
                            weight = max(0, min(1000, v))
                        }
                    }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
                Text("kg").foregroundStyle(.secondary)
            }
        }
    }
}
