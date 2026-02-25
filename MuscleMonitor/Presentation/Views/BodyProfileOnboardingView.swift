//
//  BodyProfileOnboardingView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//


// BodyProfileOnboardingView.swift

import SwiftUI

struct BodyProfileOnboardingView: View {
    let user: User
    let repo: PreferencesRepository
    let onDone: () -> Void

    @State private var weightKg: Double? = nil
    @State private var heightCm: Double? = nil
    @State private var unit: WeightUnit = .kg
    @State private var objective: CalorieObjective = .maintain

    var body: some View {
        Form {
            Section("measures") {
                HStack {
                    Text("weight")
                    Spacer()
                    TextField("kg", value: $weightKg, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Picker("", selection: $unit) {
                        ForEach(WeightUnit.allCases) { Text($0.display).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                }

                HStack {
                    Text("height")
                    Spacer()
                    TextField("cm", value: $heightCm, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("cm").foregroundStyle(.secondary)
                }
            }

            Section("calories_goal") {
                Picker("goal", selection: $objective) {
                    ForEach(CalorieObjective.allCases) { Text($0.display).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button(action: saveAndContinue) {
                    Text("next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            } footer: {
                Text("change_settings")
            }
        }
        .navigationTitle("your_profile")
        .onAppear {
            // Pré-remplir depuis d'anciennes prefs si elles existent déjà
            if let existing = repo.load(for: user.id) {
                weightKg  = existing.bodyWeightKg
                heightCm  = existing.heightCm
                unit      = existing.weightUnit
                objective = existing.objective
            }
        }
    }

    private var canContinue: Bool { weightKg != nil && weightKg! > 0 && heightCm != nil && heightCm! > 0 }

    private func saveAndContinue() {
        var prefs = repo.load(for: user.id) ?? UserPreferences()
        prefs.bodyWeightKg = weightKg
        prefs.heightCm     = heightCm
        prefs.weightUnit   = unit
        prefs.objective    = objective
        repo.save(prefs, for: user.id)
        onDone()
    }
}
