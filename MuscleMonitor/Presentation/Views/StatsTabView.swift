//
//  StatsTabView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI
import Charts

// MARK: - Time Range
enum StatsRange: String, CaseIterable, Identifiable {
    case m1 = "1M", m3 = "3M", m6 = "6M", m9 = "9M", y1 = "1Y", all = "All"
    var id: String { rawValue }
    
    func lowerBound(from now: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch self {
        case .m1: return cal.date(byAdding: .month, value: -1, to: now)
        case .m3: return cal.date(byAdding: .month, value: -3, to: now)
        case .m6: return cal.date(byAdding: .month, value: -6, to: now)
        case .m9: return cal.date(byAdding: .month, value: -9, to: now)
        case .y1: return cal.date(byAdding: .year,  value: -1, to: now)
        case .all: return nil
        }
    }
}

// MARK: - Subtabs
enum StatsSubtab: String, CaseIterable, Identifiable {
    case global = "Dashboard"
    case exercises = "Exercices"
    var id: String { rawValue }
}

// MARK: - StatsTabView
struct StatsTabView: View {
    @StateObject private var vm: StatsViewModel
    @State private var subtab: StatsSubtab = .global
    
    init(sessionRepo: WorkoutSessionRepository, exercisesRepo: ExerciseCatalogRepository? = nil, calorieRepo: CalorieRepository, prefsRepo: PreferencesRepository, userId: String) {
        _vm = StateObject(wrappedValue: StatsViewModel(sessionRepo: sessionRepo, exercisesRepo: exercisesRepo, calorieRepo: calorieRepo, prefsRepo: prefsRepo, userId: userId))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if vm.isLoading {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("performance_analysis").foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            Picker("tab", selection: $subtab) {
                                ForEach(StatsSubtab.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented).padding(.horizontal)

                            if subtab == .global {
                                GlobalDashboardView(vm: vm)
                            } else {
                                SearchBar(text: $vm.searchText).padding(.horizontal)
                                ExercisesListView(vm: vm)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("statistics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !vm.isLoading {
                        // Utilisation du nouveau nom pour éviter le conflit
                        ShareLink(item: renderStatsImage(), preview: SharePreview("my_progress", image: renderStatsImage())) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { await vm.load() }
        }
    }
    
    @MainActor private func renderStatsImage() -> Image {
        // Changé en StatsShareCardView
        let renderer = ImageRenderer(content: StatsShareCardView(vm: vm))
        renderer.scale = 3.0
        return Image(uiImage: renderer.uiImage ?? UIImage())
    }
}

// MARK: - Nouvelle Vue de Partage Stats (Différente de ShareCardView)
struct StatsShareCardView: View {
    @ObservedObject var vm: StatsViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 60)).foregroundStyle(.orange)
                Text("musclemonitor")
                    .font(.headline).bold()
                Text("period_progress")
                    .font(.title).bold()
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(Int(vm.currentProgressionMetrics.currentWeekVolume)) kg").font(.title2).bold()
                    Text("tonnage").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(vm.allSessions.count)").font(.title2).bold()
                    Text("sessions").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 15))

            Text("#WorkHard #MuscleMonitor")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 400, height: 500) // Format carré pour partage rapide
        .background(Color.white)
    }
}

// MARK: - Exercise Detail View (Ajouté ici pour corriger l'erreur de scope)
struct ExerciseDetailView: View {
    let name: String
    let sessions: [WorkoutSession]
    @EnvironmentObject var vm: StatsViewModel
    
    @State private var showGoalEditor: Bool = false
    
    // MARK: - Propriétés calculées
    
    /// Détecte si l'exercice est du cardio via le mapping global
    private var isCardioExercise: Bool {
        Workout.Exercise.muscleMapping[name]?.contains(.cardio) ?? false
    }
    
    /// Prépare les données pour le graphique (Valeur = Poids ou Secondes)
    private var chartData: [(date: Date, value: Double)] {
        sessions
            .filter { $0.exercises.contains(where: { $0.name == name }) }
            .compactMap { s in
                guard let ex = s.exercises.first(where: { $0.name == name }) else { return nil }
                
                if isCardioExercise {
                    // Pour le cardio : on prend le meilleur temps (reps) de la séance
                    let bestTime = ex.sets.map { Double($0.reps) }.max() ?? 0
                    return (date: s.endedAt, value: bestTime)
                } else {
                    // Pour la muscu : calcul du 1RM estimé
                    let rm = ex.sets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max() ?? 0
                    return (date: s.endedAt, value: rm)
                }
            }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // --- SECTION 1 : GRAPHIQUE ---
                VStack(alignment: .leading, spacing: 15) {
                    Text(isCardioExercise ? "evolution_endurance" : "strength_progression")
                        .font(.headline)
                    
                    Chart(chartData, id: \.date) { item in
                        LineMark(x: .value("date", item.date), y: .value("value", item.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(isCardioExercise ? .red : .blue)
                        
                        PointMark(x: .value("date", item.date), y: .value("value", item.value))
                            .foregroundStyle(isCardioExercise ? .red : .blue)
                    }
                    .frame(height: 220)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    // Affiche "10min" sur l'axe au lieu de "600"
                                    Text(isCardioExercise ? formatDuration(Int(doubleValue)) : "\(Int(doubleValue))kg")
                                }
                            }
                        }
                    }
                }
                
                // --- SECTION 1.5 : OBJECTIF & SUGGESTIONS ---
                goalAndSuggestionsBlock

                // --- SECTION 2 : ANALYSES SPÉCIFIQUES ---
                if isCardioExercise {
                    // Statistiques cumulées pour le cardio
                    cardioStatsOverview
                } else {
                    // Outils de musculation
                    VStack(spacing: 20) {
                        if let pred = vm.predict1RM(for: name) {
                            analysisIABlock(pred: pred)
                        }
                        
                        let stagnation = vm.checkStagnation(for: name)
                        if stagnation.isStagnating {
                            stagnationBlock(report: stagnation)
                        }
                        
                        if let lastEntry = chartData.last {
                            if let level = vm.getForceLevel(for: name, oneRM: lastEntry.value),
                               let progress = vm.getForceProgress(for: name, oneRM: lastEntry.value) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("relative_strength_level").font(.headline)
                                    StrengthProgressBar(progress: progress, color: level.color)
                                }
                            }
                        }
                    }
                }
                
                // --- SECTION 3 : HISTORIQUE ---
                historyBlock
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey(name))
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sous-composants
    
    private var goalAndSuggestionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("objectif_en_cours").font(.headline)
                Spacer()
                Button(action: { showGoalEditor = true }) {
                    Label("edit", systemImage: "pencil")
                        .font(.caption)
                }
            }

            if let gp = vm.goalProgress(for: name) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(gp.title).font(.subheadline).foregroundStyle(.secondary)
                    ProgressView(value: gp.progress)
                    Text(gp.detail).font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                Text("aucun_objectif")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let suggestion = vm.overloadSuggestion(for: name)
            switch suggestion.kind {
            case .addWeight(let delta):
                suggestionCard(text: "+\(String(format: "%.1f", delta)) kg", reason: suggestion.reason, color: .blue)
            case .addReps(let r):
                suggestionCard(text: "+\(r) reps", reason: suggestion.reason, color: .blue)
            case .none:
                suggestionCard(text: "—", reason: suggestion.reason, color: .gray)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet(exerciseName: name, vm: vm)
        }
    }
    
    private func suggestionCard(text: String, reason: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.up.right.circle.fill").foregroundStyle(color)
                Text("surcharge_progressive").bold()
            }
            Text(text).font(.title3).bold().foregroundStyle(color)
            Text(reason).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var cardioStatsOverview: some View {
        let totalSeconds = chartData.reduce(0) { $0 + $1.value }
        let avgSeconds = chartData.isEmpty ? 0 : totalSeconds / Double(chartData.count)
        
        return HStack(spacing: 15) {
            MetricCard(title: "temps_total", value: formatDuration(Int(totalSeconds)), icon: "timer", color: .red)
            MetricCard(title: "moyenne_session", value: formatDuration(Int(avgSeconds)), icon: "chart.bar.fill", color: .orange)
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("history").font(.headline)
            
            ForEach(sessions.reversed().filter { $0.exercises.contains(where: { $0.name == name }) }.prefix(15)) { s in
                if let ex = s.exercises.first(where: { $0.name == name }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(s.endedAt, style: .date).font(.subheadline).bold()
                            Text(s.title).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            if isCardioExercise {
                                // Additionne le temps de toutes les séries de cardio
                                let totalTime = ex.sets.map { $0.reps }.reduce(0, +)
                                Text(formatDuration(totalTime)).bold()
                            } else {
                                let maxW = ex.sets.map { $0.weight }.max() ?? 0
                                Text("\(Int(maxW)) kg").bold()
                                Text("\(ex.sets.count) séries").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers de formatage
    
    private func analysisIABlock(pred: (target: Double, weeks: Int, advice: StatsViewModel.ProgressionAdvice?)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ai_analysis", systemImage: "brain.head.profile").font(.headline)
                Spacer()
                Text("three_week_horizon").font(.caption2).padding(4)
                    .background(Color.purple.opacity(0.2)).cornerRadius(4)
            }
            .foregroundColor(.purple)
            
            Text("estimated_target \(String(format: "%.1f", pred.target)) kg").bold()

            if let advice = pred.advice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: advice.isWarning ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .foregroundColor(advice.isWarning ? .orange : .green)
                    Text(advice.message).font(.caption)
                }
                .padding(10)
                .background(advice.isWarning ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }

    private func stagnationBlock(report: StatsViewModel.StagnationReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("stagnation_point", systemImage: "exclamationmark.octagon.fill")
                .foregroundColor(.orange).bold()
            Text(report.message).font(.subheadline)
            Text(report.suggestion).font(.caption).foregroundColor(.secondary)
        }
        .padding().background(Color.orange.opacity(0.1)).cornerRadius(12)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins == 0 && seconds > 0 { return "\(seconds)s" }
        return "\(mins) min"
    }
}
// MARK: - Global Dashboard
struct GlobalDashboardView: View {
    @ObservedObject var vm: StatsViewModel
    @State private var correlation: [StatsViewModel.CorrelationData] = []

    var body: some View {
        VStack(spacing: 28) {
            Picker("period", selection: $vm.selectedRange) {
                ForEach(StatsRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            MuscleDistributionChart(vm: vm)
                .padding(.horizontal)

            BaseMetricsGrid(vm: vm)

            SurchargeProgressiveSection(vm: vm)

            IntensitySection(vm: vm)
            
            HeatmapSection(vm: vm)

            CorrelationSection(correlation: correlation)
        }
        .task { correlation = await vm.fetchCorrelationData() }
    }
}

// MARK: - Components

struct BaseMetricsGrid: View {
    @ObservedObject var vm: StatsViewModel
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Utilisation des propriétés filtrées
            MetricCard(title: "Séances", value: "\(vm.sessionCountForRange)", icon: "flame.fill", color: .orange)
            MetricCard(title: "Volume Total", value: "\(Int(vm.totalVolumeForRange)) kg", icon: "scalemass.fill", color: .green)
        }.padding(.horizontal)
    }
}

struct ExercisesListView: View {
    @ObservedObject var vm: StatsViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(vm.filteredExercises) { agg in
                NavigationLink(destination: ExerciseDetailView(name: agg.name, sessions: vm.allSessions).environmentObject(vm)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                // Icône : Cœur pour le cardio, Haltère pour le reste
                                Image(systemName: isCardio(agg.name) ? "heart.fill" : "dumbbell.fill")
                                    .font(.caption2)
                                    .foregroundColor(isCardio(agg.name) ? .red : .blue)
                                
                                Text(LocalizedStringKey(agg.name))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            // Affichage du volume ou de la charge de travail
                            Text(isCardio(agg.name) ? "Charge: \(Int(agg.totalVolume)) pts" : "Volume: \(Int(agg.totalVolume)) kg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if isCardio(agg.name) {
                                // ✅ Affiche "31 min" au lieu de "1870 kg"
                                Text(formatDuration(Int(agg.oneRM)))
                                    .bold()
                                    .foregroundColor(.blue)
                                Text("temps_max").font(.caption2).foregroundColor(.secondary)
                            } else {
                                Text("\(Int(agg.oneRM))kg")
                                    .bold()
                                    .foregroundColor(.blue)
                                Text("estimated_one_rm").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
            }
        }.padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func isCardio(_ name: String) -> Bool {
        return Workout.Exercise.muscleMapping[name]?.contains(.cardio) ?? false
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins == 0 && seconds > 0 {
            return "\(seconds)s"
        }
        return "\(mins) min"
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("search_exercise", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.headline)
                Spacer()
            }
            Text(value).font(.title3).bold()
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground)).cornerRadius(16)
    }
}

struct IntensitySection: View {
    @ObservedObject var vm: StatsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("evolution_intensity").font(.headline)
            Chart {
                ForEach(vm.filteredSessionsForRange) { session in
                    let totalW = session.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.weight } }
                    let totalR = session.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
                    let intensity = totalR > 0 ? Double(totalW) / Double(totalR) : 0
                    
                    if intensity > 0 {
                        LineMark(
                            x: .value("date", session.endedAt),
                            y: .value("intensity", intensity)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.green)
                    }
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct MuscleDistributionChart: View {
    @ObservedObject var vm: StatsViewModel
    @State private var useSets = true
    
    var body: some View {
        let data = vm.muscleDistributionData
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(useSets ? "sets_per_muscle" : "volume_per_muscle")
                        .font(.headline)
                    Text("selected_period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { withAnimation { useSets.toggle() } } label: {
                    Label("edit", systemImage: "arrow.2.squarepath")
                        .font(.caption)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if !data.isEmpty {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("value", useSets ? Double(item.sets) : item.volume),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("group", item.group))
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartLegend(position: .trailing, alignment: .center, spacing: 16)
            }
        }
        .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(16)
    }
}
struct GoalEditorSheet: View {
    let exerciseName: String
    @ObservedObject var vm: StatsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Int = 0 // 0 = 1RM, 1 = rep scheme
    @State private var oneRM: Double = 100
    @State private var sets: Int = 3
    @State private var reps: Int = 8
    @State private var weight: Double = 60

    var body: some View {
        NavigationStack {
            Form {
                Picker("type", selection: $mode) {
                    Text("1RM cible").tag(0)
                    Text("Schéma de reps").tag(1)
                }
                .pickerStyle(.segmented)

                if mode == 0 {
                    HStack {
                        Text("1RM")
                        Spacer()
                        TextField("kg", value: $oneRM, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } else {
                    Stepper("Séries : \(sets)", value: $sets, in: 1...10)
                    Stepper("Répétitions : \(reps)", value: $reps, in: 1...30)
                    HStack {
                        Text("Poids")
                        Spacer()
                        TextField("kg", value: $weight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Button(role: .destructive) {
                    vm.saveGoal(nil, for: exerciseName)
                    dismiss()
                } label: {
                    Text("Supprimer l'objectif")
                }
            }
            .navigationTitle("Objectif")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        if mode == 0 {
                            vm.saveGoal(ExerciseGoal(oneRM: oneRM), for: exerciseName)
                        } else {
                            vm.saveGoal(ExerciseGoal(sets: sets, reps: reps, weight: weight), for: exerciseName)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let g = vm.goal(for: exerciseName) {
                    switch g.kind {
                    case .oneRM:
                        mode = 0
                        oneRM = g.targetOneRM ?? 100
                    case .repScheme:
                        mode = 1
                        sets = g.targetSets ?? 3
                        reps = g.targetReps ?? 8
                        weight = g.targetWeight ?? 60
                    }
                }
            }
        }
    }
}

