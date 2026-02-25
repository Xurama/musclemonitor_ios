//
//  SettingsTabView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//


import SwiftUI

struct SettingsTabView: View {
    let user: User
    let repo: PreferencesRepository
    
    @EnvironmentObject private var tabRouter: TabRouter
    
    @State private var weeklyGoal: Int
    @State private var monthlyGoal: Int
    @State private var firstWeekday: FirstWeekday
    @State private var weightUnit: WeightUnit
    @State private var weightKg: Double?
    @State private var heightCm: Double?
    @State private var objective: CalorieObjective
    @State private var sex: BiologicalSex
    @State private var birthDate: Date
    
    @State private var showSavedToast = false
    
    // 👇 Custom init pour pré-remplir les @State avec les prefs déjà stockées
    init(user: User, repo: PreferencesRepository) {
        self.user = user
        self.repo = repo
        
        if let existing = repo.load(for: user.id) {
            _weeklyGoal  = State(initialValue: existing.weeklyGoal)
            _monthlyGoal = State(initialValue: existing.monthlyGoal)
            _firstWeekday = State(initialValue: existing.firstWeekday)
            _weightUnit   = State(initialValue: existing.weightUnit)
            _weightKg     = State(initialValue: existing.bodyWeightKg)
            _heightCm     = State(initialValue: existing.heightCm)
            _objective    = State(initialValue: existing.objective)
            _sex          = State(initialValue: existing.sex)
            _birthDate    = State(initialValue: existing.birthDate)
        } else {
            // fallback si aucun prefs n'existe encore
            _weeklyGoal  = State(initialValue: 3)
            _monthlyGoal = State(initialValue: 15)
            _firstWeekday = State(initialValue: .monday)
            _weightUnit   = State(initialValue: .kg)
            _weightKg     = State(initialValue: nil)
            _heightCm     = State(initialValue: nil)
            _objective    = State(initialValue: .maintain)
            _sex          = State(initialValue: .male)
            _birthDate    = State(initialValue: Date())
        }
    }
    
    var body: some View {
        NavigationStack {
            // ✅ La ZStack doit envelopper le Form ET le Toast
            ZStack(alignment: .top) {
                Form {
                    Section("objectives_sessions") {
                        NumberFieldRow(title: "objective_weekly", value: $weeklyGoal, range: 1...14)
                        NumberFieldRow(title: "objective_monthly", value: $monthlyGoal, range: 1...60)
                    }
                    
                    Section("weeks_and_units") {
                        Picker("first_day", selection: $firstWeekday) {
                            ForEach(FirstWeekday.allCases) { Text($0.display).tag($0) }
                        }
                        Picker("weight_unit", selection: $weightUnit) {
                            ForEach(WeightUnit.allCases) { Text($0.display).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    
                    Section("body_profile") {
                        Picker("biological_Sex", selection: $sex) {
                            ForEach(BiologicalSex.allCases) { Text($0.display).tag($0) }
                        }.pickerStyle(.segmented)
                        
                        DatePicker("date_of_birth", selection: $birthDate, displayedComponents: .date)
                        
                        HStack {
                            Text("weight")
                            Spacer()
                            TextField(weightUnit == .kg ? "kg" : "lb", value: $weightKg, format: .number.precision(.fractionLength(1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text(weightUnit.display).foregroundStyle(.secondary)
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
                        
                        Picker("calories_goal", selection: $objective) {
                            ForEach(CalorieObjective.allCases) { Text($0.display).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                }
                .navigationTitle("settings")
                
                // ✅ Le Toast est bien à l'intérieur de la ZStack, après le Form
                if showSavedToast {
                    ToastView(message: "saved_confirm")
                        .padding(.top, 10)
                        .zIndex(1)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Text("save")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private func save() {
        var prefs = repo.load(for: user.id) ?? UserPreferences()
        prefs.weeklyGoal  = weeklyGoal
        prefs.monthlyGoal = monthlyGoal
        prefs.firstWeekday = firstWeekday
        prefs.weightUnit   = weightUnit
        prefs.bodyWeightKg = weightKg
        prefs.heightCm     = heightCm
        prefs.objective    = objective
        prefs.sex          = sex
        prefs.birthDate    = birthDate
        repo.save(prefs, for: user.id)
        
        // 1) Fermer le clavier
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        
        // 3) Animation du Toast et Redirection
        withAnimation(.spring()) {
            showSavedToast = true
        }
        
        // Le toaster reste 1.5 seconde, puis on change d'onglet
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSavedToast = false
            }
            // Petit délai supplémentaire pour laisser l'animation de sortie se faire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tabRouter.selected = .home
            }
        }
    }
    
    struct ToastView: View {
        let message: String
        
        var body: some View {
            Text(LocalizedStringKey(message))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
}
