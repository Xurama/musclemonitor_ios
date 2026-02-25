//
//  UserPreferencesView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct UserPreferencesView: View {
    let user: User
    private let repo: PreferencesRepository
    let onSaved: () -> Void

    @State private var weeklyGoal: Int = 3
    @State private var monthlyGoal: Int = 15
    @State private var firstWeekday: FirstWeekday = .monday
    @State private var weightUnit: WeightUnit = .kg

    init(user: User, repo: PreferencesRepository, onSaved: @escaping () -> Void) {
        self.user = user
        self.repo = repo
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("goals") {
                NumberFieldRow(
                    title: "Objectif hebdo (séances)",
                    value: $weeklyGoal,
                    range: 1...14
                )
                NumberFieldRow(
                    title: "Objectif mensuel (séances)",
                    value: $monthlyGoal,
                    range: 1...60
                )
            }

            Section("first_day_of_week") {
                Picker("first_day", selection: $firstWeekday) {
                    ForEach(FirstWeekday.allCases) { f in
                        Text(f.display).tag(f)
                    }
                }
                // 7 segments seraient serrés — laisse en style par défaut (menu/wheel selon contexte)
            }

            Section("units") {
                Picker("weight", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases) { u in
                        Text(u.display).tag(u)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("preferences")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("close") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            if let existing = repo.load(for: user.id) {
                weeklyGoal  = existing.weeklyGoal
                monthlyGoal = existing.monthlyGoal
                firstWeekday = existing.firstWeekday
                weightUnit   = existing.weightUnit
            }
        }
        // Bouton collé en bas, toujours visible
        .safeAreaInset(edge: .bottom) {
            Button {
                let prefs = UserPreferences(
                    weeklyGoal: weeklyGoal,
                    monthlyGoal: monthlyGoal,
                    firstWeekday: firstWeekday,
                    weightUnit: weightUnit
                )
                repo.save(prefs, for: user.id)
                onSaved()
            } label: {
                Text("save")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .background(.ultraThinMaterial) // léger fond pour lisibilité au-dessus du Form
        }
    }
}
