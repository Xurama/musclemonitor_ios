//
//  StatsViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 07/01/2026.
//


import Foundation
import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {
    private let sessionRepo: WorkoutSessionRepository
    private let exercisesRepo: ExerciseCatalogRepository?
    private let calorieRepo: CalorieRepository
    private let prefsRepo: PreferencesRepository
    private let userId: String
    
    @Published private(set) var allSessions: [WorkoutSession] = []
    @Published var selectedRange: StatsRange = .m3
    @Published var muscleRange: StatsRange = .m3
    @Published private var catalogNameToGroup: [String: String] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published private(set) var userWeight: Double = 75.0
    
    var filteredExercises: [ExerciseAggregate] {
        let results = perExerciseForRange
        if searchText.isEmpty { return results }
        return results.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var currentProgressionMetrics: ProgressionMetrics { fetchProgressionMetrics(for: selectedRange) }
    var currentHeatmapData: [Date: DayActivity] { advancedActivityData() }
    
    init(sessionRepo: WorkoutSessionRepository, exercisesRepo: ExerciseCatalogRepository? = nil, calorieRepo: CalorieRepository, prefsRepo: PreferencesRepository, userId: String) {
        self.sessionRepo = sessionRepo
        self.exercisesRepo = exercisesRepo
        self.calorieRepo = calorieRepo
        self.prefsRepo = prefsRepo
        self.userId = userId
    }
    
    // 1. Filtrer les sessions selon la période sélectionnée
        var filteredSessionsForRange: [WorkoutSession] {
            let lb = selectedRange.lowerBound() ?? .distantPast
            return allSessions.filter { $0.endedAt >= lb }
        }

        // 2. Nombre de séances filtrées
        var sessionCountForRange: Int {
            filteredSessionsForRange.count
        }

        // 3. Volume Total filtré
        var totalVolumeForRange: Double {
            filteredSessionsForRange.reduce(0) { $0 + sessionVolume($1) }
        }

        // 4. Intensité Moyenne filtrée (kg/rep)
        var averageIntensityForRange: Double {
            let sessions = filteredSessionsForRange
            let totalW = sessions.reduce(0) { acc, s in
                acc + s.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.weight } }
            }
            let totalR = sessions.reduce(0) { acc, s in
                acc + s.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + Double($1.reps) } }
            }
            return totalR > 0 ? totalW / totalR : 0
        }
    
    func load() async {
        isLoading = true
        
        if let prefs = prefsRepo.load(for: userId) {
            self.userWeight = prefs.bodyWeightKg ?? 75.0
        }
        
        do {
            let sessions = try await sessionRepo.list()
            self.allSessions = sessions.sorted { $0.startedAt < $1.startedAt }
        } catch { print("[Stats] load error: \(error)") }
        
        if let repo = exercisesRepo {
            let names = await repo.allExercises()
            var map: [String: String] = [:]
            for raw in names { map[normalize(raw)] = muscleGroup(for: raw) }
            self.catalogNameToGroup = map
        }
        isLoading = false
    }
    
    // Récupère tous les noms de workouts uniques utilisés par l'utilisateur
    var uniqueWorkoutNames: [String] {
        let names = allSessions.map { $0.title }
        return Array(Set(names)).sorted()
    }

    // Génère une couleur unique par nom de workout
    func color(for workoutName: String) -> Color {
         let colors: [Color] = [.orange, .blue, .green, .purple, .pink, .yellow, .cyan]
         let index = uniqueWorkoutNames.firstIndex(of: workoutName) ?? 0
         return colors[index % colors.count] // Alterne les couleurs si on dépasse la liste
     }

    private func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    func muscleGroup(for name: String) -> String {
        // 1. On tente le mapping direct (Clé technique)
        if let groups = Workout.Exercise.muscleMapping[name] {
            return categoryFromTags(groups)
        }
        
        // 2. Si ça échoue, on normalise le nom pour un matching plus souple
        let n = normalize(name)
        
        // On fait le pont entre les noms français affichés et les tags
        // Tu peux enrichir cette liste selon tes logs
        var tags: Set<MuscleTag> = []
        
        if n.contains("couché") || n.contains("incliné") || n.contains("bench") || n.contains("fly") { tags = [.pectoraux] }
        else if n.contains("tirage") || n.contains("dos") || n.contains("row") || n.contains("deadlift") || n.contains("terre") || n.contains("shrug") { tags = [.dos] }
        else if n.contains("squat") || n.contains("presse") || n.contains("leg") || n.contains("fente") || n.contains("mollet") || n.contains("thrust") { tags = [.quadriceps] } // Classé en Jambes
        else if n.contains("shoulder") || n.contains("élevation") || n.contains("épaule") || n.contains("face pull") { tags = [.epaules] }
        else if n.contains("curl") || n.contains("biceps") { tags = [.biceps] }
        else if n.contains("triceps") || n.contains("dips") { tags = [.triceps] }
        else if n.contains("planche") || n.contains("gainage") || n.contains("jambes") || n.contains("abs") || n.contains("crunch") { tags = [.abdominaux] }
        else if n.contains("running") || n.contains("tapis") || n.contains("bike") || n.contains("velo") || n.contains("cardio") { tags = [.cardio] }

        if !tags.isEmpty {
            return categoryFromTags(tags)
        }

        return "Autres"
    }

    // Helper pour transformer un Set de MuscleTag en String de catégorie pour le graphique
    private func categoryFromTags(_ groups: Set<MuscleTag>) -> String {
        if groups.contains(.cardio) { return "Cardio" }
        if groups.contains(.pectoraux) { return "Pectoraux" }
        if groups.contains(.dos) { return "Dos" }
        if groups.contains(.epaules) { return "Épaules" }
        if groups.contains(.biceps) { return "Biceps" }
        if groups.contains(.triceps) { return "Triceps" }
        if groups.contains(.abdominaux) { return "Abdos" }
        
        // Regroupement Jambes
        if groups.contains(.quadriceps) || groups.contains(.ischio) ||
           groups.contains(.fessiers) || groups.contains(.mollets) {
            return "Jambes"
        }
        
        return "Autres"
    }
    
    func advancedActivityData() -> [Date: DayActivity] {
        var heatmap: [Date: DayActivity] = [:]
        let groupedByDate = Dictionary(grouping: allSessions) { Calendar.current.startOfDay(for: $0.endedAt) }
        
        for (date, sessions) in groupedByDate {
            // On prend le titre du premier workout de la journée comme référence
            let mainWorkoutTitle = sessions.first?.title ?? "Inconnu"
            
            heatmap[date] = DayActivity(
                volume: sessions.reduce(0) { $0 + sessionVolume($1) },
                dominantMuscle: mainWorkoutTitle, // On utilise l'étiquette attendue par la struct
                hasPR: checkDayHasPR(sessions: sessions) // Appel de la fonction définie ci-dessous
            )
        }
        return heatmap
    }
    
    func sessionVolume(_ s: WorkoutSession) -> Double {
        s.exercises.reduce(0) { acc, ex in
            // ✅ On DOIT appeler cette fonction qui gère le temps/60
            acc + calculateExerciseVolume(ex)
        }
    }


    var avgSessionsPerWeek: Double {
        guard let first = allSessions.first?.startedAt, let last = allSessions.last?.startedAt else { return 0 }
        let weeks = max(1.0, last.timeIntervalSince(first) / (86400 * 7))
        return Double(allSessions.count) / weeks
    }

    var consecutiveWeeksStreak: Int {
        let cal = Calendar.current
        let weeks = Set(allSessions.map { cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.endedAt) })
        var streak = 0
        var cursor = Date()
        while weeks.contains(cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: cursor)) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    func fetchCorrelationData() async -> [CorrelationData] {
        var results: [CorrelationData] = []
        let cal = Calendar.current
        let entries = (try? await calorieRepo.loadAll()) ?? []
        for i in (0..<7).reversed() {
            let date = cal.date(byAdding: .day, value: -i, to: Date())!
            let dayKcal = entries.filter { cal.isDate($0.date, inSameDayAs: date) && $0.kind == .intake }.reduce(0) { $0 + Double($1.totalKcal) }
            let dayVol = allSessions.filter { cal.isDate($0.endedAt, inSameDayAs: date) }.reduce(0) { $0 + sessionVolume($1) }
            let fmt = DateFormatter(); fmt.dateFormat = "E"
            results.append(CorrelationData(day: fmt.string(from: date), calories: dayKcal, volume: dayVol))
        }
        return results
    }

    var perExerciseForRange: [ExerciseAggregate] {
        let lb = selectedRange.lowerBound() ?? .distantPast
        let filtered = allSessions.filter { $0.endedAt >= lb }
        var acc: [String: (vol: Double, maxW: Double, bestRM: Double, isCardio: Bool)] = [:]
        
        for s in filtered {
            for ex in s.exercises {
                let key = ex.name
                if key.isEmpty { continue }
                
                // 1. Détection via le mapping
                let muscleGroups = Workout.Exercise.muscleMapping[key] ?? []
                let isCardio = muscleGroups.contains(.cardio)
                
                // 2. Calcul du volume via la fonction dédiée
                let exVol = calculateExerciseVolume(ex)
                
                // 3. Calcul du poids max
                let exMax = ex.sets.map { $0.weight }.max() ?? 0
                
                // 4. Calcul de la valeur de performance (RM ou Temps)
                // On décompose ici pour éviter l'erreur de compilation
                var performanceValue: Double = 0
                if isCardio {
                    // Pour le cardio, on prend le temps maximum fait sur une série
                    performanceValue = ex.sets.map { Double($0.reps) }.max() ?? 0
                } else {
                    // Pour la muscu, calcul du 1RM (Epley formula)
                    let rmValues = ex.sets.map { set in
                        set.weight * (1 + Double(set.reps) / 30.0)
                    }
                    performanceValue = rmValues.max() ?? 0
                }
                
                // 5. Agrégation
                let cur = acc[key] ?? (vol: 0, maxW: 0, bestRM: 0, isCardio: isCardio)
                acc[key] = (
                    vol: cur.vol + exVol,
                    maxW: max(cur.maxW, exMax),
                    bestRM: max(cur.bestRM, performanceValue),
                    isCardio: isCardio
                )
            }
        }
        
        return acc.map {
            ExerciseAggregate(
                id: $0.key,
                name: $0.key,
                totalVolume: $0.value.vol,
                maxWeight: $0.value.maxW,
                oneRM: $0.value.bestRM
            )
        }.sorted { $0.totalVolume > $1.totalVolume }
    }

    func fetchProgressionMetrics(for range: StatsRange) -> ProgressionMetrics {
        let cal = Calendar.current
        let now = Date()
        guard let currentStart = range.lowerBound(from: now) else { return ProgressionMetrics(currentWeekVolume: 0, last4WeeksAvgVolume: 0, volumeEvolution: 0, averageIntensity: 0, intensityEvolution: 0) }
        let duration = now.timeIntervalSince(currentStart)
        let comparisonStart = currentStart.addingTimeInterval(-duration)
        let currentSessions = allSessions.filter { $0.endedAt >= currentStart }
        let pastSessions = allSessions.filter { $0.endedAt >= comparisonStart && $0.endedAt < currentStart }
        let currentVol = currentSessions.reduce(0) { $0 + sessionVolume($1) }
        let pastVol = pastSessions.reduce(0) { $0 + sessionVolume($1) }
        let volEvo = pastVol > 0 ? ((currentVol - pastVol) / pastVol) * 100 : 0
        func getIntensity(for sessions: [WorkoutSession]) -> Double {
            let totalW = sessions.reduce(0) { acc, s in acc + s.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.weight } } }
            let totalR = sessions.reduce(0) { acc, s in acc + s.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } } }
            return totalR > 0 ? Double(totalW) / Double(totalR) : 0
        }
        let currentIntense = getIntensity(for: currentSessions)
        let pastIntense = getIntensity(for: pastSessions)
        let intenseEvo = pastIntense > 0 ? ((currentIntense - pastIntense) / pastIntense) * 100 : 0
        return ProgressionMetrics(currentWeekVolume: currentVol, last4WeeksAvgVolume: pastVol, volumeEvolution: volEvo, averageIntensity: currentIntense, intensityEvolution: intenseEvo)
    }

    // MARK: - Correction de la distribution musculaire
    var muscleDistributionData: [MuscleDistribution] {
        let lb = selectedRange.lowerBound() ?? .distantPast
        let filteredSessions = allSessions.filter { $0.endedAt >= lb }
        
        var volumeMap: [String: Double] = [:]
        var setsMap: [String: Int] = [:]
        
        for session in filteredSessions {
            for exercise in session.exercises {
                // ✅ Utilise la fonction de mapping définie plus haut
                let group = muscleGroup(for: exercise.name)
                
                // ✅ Calcule le volume correctement
                let vol = calculateExerciseVolume(exercise)
                
                volumeMap[group, default: 0] += vol
                setsMap[group, default: 0] += exercise.sets.count
            }
        }
        
        return volumeMap.map {
            MuscleDistribution(group: $0.key, volume: $0.value, sets: setsMap[$0.key] ?? 0)
        }
        .sorted { $0.sets > $1.sets }
    }
    
    private func checkDayHasPR(sessions: [WorkoutSession]) -> Bool {
        guard let firstSessionDate = sessions.first?.endedAt else { return false }
        
        // 1. On récupère toutes les séances passées une seule fois
        let pastSessions = allSessions.filter { $0.endedAt < firstSessionDate }
        
        for session in sessions {
            for exercise in session.exercises {
                let name = exercise.name.lowercased()
                
                // Calcul du RM actuel
                let currentRM = exercise.sets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max() ?? 0
                if currentRM <= 0 { continue }
                
                // 2. Recherche du record passé de façon décomposée pour le compilateur
                let pastExercises = pastSessions.flatMap { $0.exercises }.filter { $0.name.lowercased() == name }
                let pastSets = pastExercises.flatMap { $0.sets }
                let previousMaxRM = pastSets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max() ?? 0
                
                if currentRM > previousMaxRM {
                    return true // Record battu !
                }
            }
        }
        return false
    }
    
    func calculateExerciseVolume(_ exercise: WorkoutSession.ExerciseResult) -> Double {
        let group = muscleGroup(for: exercise.name)
        
        if group == "Cardio" {
            let totalSeconds = exercise.sets.reduce(0) { $0 + Double($1.reps) }
            // Si totalSeconds est 0 (ex: séance pas finie), le volume sera 0.
            // On divise par 60 pour avoir des points de "minutes"
            return totalSeconds / 60.0
        } else {
            let multiplier = (exercise.equipment == .halteres) ? 2.0 : 1.0
            return exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) } * multiplier
        }
    }
    
    struct ProgressionAdvice {
        let message: String
        let isWarning: Bool
    }

    func predict1RM(for exerciseName: String) -> (target: Double, weeks: Int, advice: ProgressionAdvice?)? {
        let relevantSessions = allSessions.filter { s in
            s.exercises.contains(where: { $0.name.lowercased() == exerciseName.lowercased() })
        }
        
        // Il faut au moins 4 séances pour dégager une tendance
        guard relevantSessions.count >= 4 else { return nil }
        
        // Extraction des 1RM historiques
        let rms = relevantSessions.compactMap { s in
            s.exercises.first(where: { $0.name.lowercased() == exerciseName.lowercased() })?
                .sets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max()
        }
        
        // 1. Calcul de la Moyenne Mobile Pondérée (WMA)
        // On donne plus de poids aux séances récentes
        var totalWeight: Double = 0
        var weightedSum: Double = 0
        
        for (index, rm) in rms.enumerated() {
            let weight = Double(index + 1) // La séance 1 a un poids de 1, la séance 10 a un poids de 10
            weightedSum += rm * weight
            totalWeight += weight
        }
        
        let weightedAvg = weightedSum / totalWeight
        
        // 2. Détection de la Fatigue (Deload)
        // On regarde si les 3 derniers 1RM sont en baisse constante
        var advice: ProgressionAdvice? = nil
        if rms.count >= 3 {
            let last3 = rms.suffix(3).map { $0 }
            if last3[2] < last3[1] && last3[1] < last3[0] {
                advice = ProgressionAdvice(
                    message: "Baisse de régime détectée. Une semaine de Deload (récupération active) est conseillée.",
                    isWarning: true
                )
            } else if last3[2] > last3[0] {
                advice = ProgressionAdvice(
                    message: "Excellente forme ! Continue sur cette lancée.",
                    isWarning: false
                )
            }
        }
        
        // 3. Prédiction (Target)
        // On projette un gain réaliste basé sur la moyenne pondérée (+2% à +3%)
        let prediction = weightedAvg * 1.025
        
        return (target: prediction, weeks: 3, advice: advice)
    }
    
    // MARK: - Helper Models
    struct ProgressionMetrics { let currentWeekVolume, last4WeeksAvgVolume, volumeEvolution, averageIntensity, intensityEvolution: Double }
    struct MuscleDistribution: Identifiable { let id = UUID(); let group: String; let volume: Double; let sets: Int }
    struct DayActivity { let volume: Double; let dominantMuscle: String?; let hasPR: Bool }
    struct ExerciseAggregate: Identifiable { let id, name: String; let totalVolume, maxWeight, oneRM: Double }
    struct CorrelationData: Identifiable { let id = UUID(); let day: String; let calories, volume: Double }
    
    // MARK: - Goals & Suggestions
    struct GoalProgress {
        let title: String
        let progress: Double // 0...1
        let detail: String
    }

    enum OverloadSuggestionKind { case addWeight(Double), addReps(Int), none }
    struct OverloadSuggestion { let kind: OverloadSuggestionKind; let reason: String }

    // Ajoutez ces modèles en haut ou dans les Helper Models de StatsViewModel
    struct ForceStandard {
            let level: String
            let color: Color
            let multiplier: Double
        }

        struct StagnationReport {
            let isStagnating: Bool
            let message: String
            let suggestion: String
        }

        // MARK: - Logique Niveaux de Force
        func getForceLevel(for exerciseName: String, oneRM: Double) -> ForceStandard? {
            var sex: BiologicalSex = .male
            var age: Int = 25
            
            if let prefs = prefsRepo.load(for: userId) {
                sex = prefs.sex
                age = prefs.age
            }
            
            let rawRatio = oneRM / userWeight
            // 3. Appliquer l'ajustement de Sexe (les standards féminins sont ~30% plus bas)
            // On multiplie le ratio de l'utilisateur pour le comparer aux grilles masculines "étalons"
            let sexAdjustedRatio = (sex == .female) ? (rawRatio / 0.7) : rawRatio
            
            // 4. Appliquer l'ajustement d'Âge (Correction de 1% par an après 40 ans)
            let ageCorrection = (age > 40) ? Double(age - 40) * 0.01 : 0.0
            let finalRatio = sexAdjustedRatio + ageCorrection
            
            let n = normalize(exerciseName)
            
            // 1. Jambes (Squat, Presse, Leg Extension/Curl)
            if n.contains("squat") || n.contains("presse") || n.contains("leg") {
                return [
                    ForceStandard(level: "Débutant", color: .gray, multiplier: 0.75),
                    ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 1.25),
                    ForceStandard(level: "Avancé", color: .orange, multiplier: 1.75),
                    ForceStandard(level: "Elite", color: .purple, multiplier: 2.25)
                ].last(where: { finalRatio >= $0.multiplier })
            }
            // 2. Poussé (Bench, Incliné, Chest Fly, Dips)
            else if n.contains("couché") || n.contains("incliné") || n.contains("chest") || n.contains("dips") {
                return [
                    ForceStandard(level: "Débutant", color: .gray, multiplier: 0.5),
                    ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 0.8),
                    ForceStandard(level: "Avancé", color: .orange, multiplier: 1.1),
                    ForceStandard(level: "Elite", color: .purple, multiplier: 1.4)
                ].last(where: { finalRatio >= $0.multiplier })
            }
            // 3. Tirage / Dos (Terre, Tirages, Traction, Shrugs)
            else if n.contains("terre") || n.contains("tirage") || n.contains("traction") || n.contains("shrugs") {
                return [
                    ForceStandard(level: "Débutant", color: .gray, multiplier: 0.6),
                    ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 1.0),
                    ForceStandard(level: "Avancé", color: .orange, multiplier: 1.4),
                    ForceStandard(level: "Elite", color: .purple, multiplier: 1.8)
                ].last(where: { finalRatio >= $0.multiplier })
            }
            // 4. Isolation & Épaules (Curl, Triceps, Elévations, Shoulder Press)
            else {
                return [
                    ForceStandard(level: "Débutant", color: .gray, multiplier: 0.1),
                    ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 0.25),
                    ForceStandard(level: "Avancé", color: .orange, multiplier: 0.4),
                    ForceStandard(level: "Elite", color: .purple, multiplier: 0.55)
                ].last(where: { finalRatio >= $0.multiplier })
            }
        }

        // MARK: - Logique Stagnation
        func checkStagnation(for exerciseName: String) -> StagnationReport {
            let relevant = allSessions.filter { s in
                s.exercises.contains(where: { normalize($0.name) == normalize(exerciseName) })
            }.suffix(5)
            
            guard relevant.count >= 5 else { return StagnationReport(isStagnating: false, message: "", suggestion: "") }
            
            let rms = relevant.compactMap { s in
                s.exercises.first(where: { normalize($0.name) == normalize(exerciseName) })?
                    .sets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max()
            }
            
            // Si le record actuel n'est pas supérieur à celui d'il y a 4 séances
            if (rms.last ?? 0) <= (rms.first ?? 0) {
                return StagnationReport(
                    isStagnating: true,
                    message: "Stagnation détectée sur les 5 dernières séances.",
                    suggestion: "Variez vos plages de répétitions ou essayez une variante d'exercice pour relancer la progression."
                )
            }
            return StagnationReport(isStagnating: false, message: "", suggestion: "")
        }

    struct ForceProgress {
        let currentLevel: String
        let nextLevel: String?
        let progress: Double // de 0.0 à 1.0
        let currentRM: Double
        let weightToNextLevel: Double?
    }

    // Modifiez getForceLevel pour qu'il soit plus accessible ou créez cette méthode :
    func getForceProgress(for exerciseName: String, oneRM: Double) -> ForceProgress? {
        // Récupération des données utilisateur (Poids, Sexe, Âge) comme précédemment
        var sex: BiologicalSex = .male
        var age: Int = 25
        if let prefs = prefsRepo.load(for: userId) {
            sex = prefs.sex
            age = prefs.age
        }

        let n = normalize(exerciseName)
        
        // Définition des paliers selon la catégorie
        let standards: [ForceStandard]
        if n.contains("squat") || n.contains("presse") || n.contains("leg") {
            standards = [
                ForceStandard(level: "Débutant", color: .gray, multiplier: 0.75),
                ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 1.25),
                ForceStandard(level: "Avancé", color: .orange, multiplier: 1.75),
                ForceStandard(level: "Elite", color: .purple, multiplier: 2.25)
            ]
        } else if n.contains("couché") || n.contains("incliné") || n.contains("chest") || n.contains("bench") {
            standards = [
                ForceStandard(level: "Débutant", color: .gray, multiplier: 0.5),
                ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 0.85),
                ForceStandard(level: "Avancé", color: .orange, multiplier: 1.2),
                ForceStandard(level: "Elite", color: .purple, multiplier: 1.5)
            ]
        } else if n.contains("terre") || n.contains("soulevé") || n.contains("deadlift") || n.contains("row") {
            standards = [
                ForceStandard(level: "Débutant", color: .gray, multiplier: 0.8),
                ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 1.3),
                ForceStandard(level: "Avancé", color: .orange, multiplier: 1.8),
                ForceStandard(level: "Elite", color: .purple, multiplier: 2.3)
            ]
        } else {
            standards = [
                ForceStandard(level: "Débutant", color: .gray, multiplier: 0.15),
                ForceStandard(level: "Intermédiaire", color: .blue, multiplier: 0.3),
                ForceStandard(level: "Avancé", color: .orange, multiplier: 0.45),
                ForceStandard(level: "Elite", color: .purple, multiplier: 0.6)
            ]
        }

        // Calcul du ratio ajusté (Sexe et Âge)
        let rawRatio = oneRM / userWeight
        let sexAdjustedRatio = (sex == .female) ? (rawRatio / 0.7) : rawRatio
        let ageCorrection = (age > 40) ? Double(age - 40) * 0.01 : 0.0
        let userFinalRatio = sexAdjustedRatio + ageCorrection

        // Trouver le niveau actuel et le suivant
        guard let currentIndex = standards.lastIndex(where: { userFinalRatio >= $0.multiplier }) else {
            // En dessous de débutant
            let first = standards[0]
            let p = min(1.0, userFinalRatio / first.multiplier)
            return ForceProgress(currentLevel: "Novice", nextLevel: first.level, progress: p, currentRM: oneRM, weightToNextLevel: (first.multiplier * userWeight) - oneRM)
        }

        let current = standards[currentIndex]
        
        if currentIndex < standards.count - 1 {
            let next = standards[currentIndex + 1]
            let range = next.multiplier - current.multiplier
            let step = userFinalRatio - current.multiplier
            let p = min(1.0, step / range)
            let weightNeeded = (next.multiplier - userFinalRatio) * userWeight
            
            return ForceProgress(currentLevel: current.level, nextLevel: next.level, progress: p, currentRM: oneRM, weightToNextLevel: weightNeeded)
        } else {
            // Niveau Elite atteint
            return ForceProgress(currentLevel: current.level, nextLevel: nil, progress: 1.0, currentRM: oneRM, weightToNextLevel: nil)
        }
    }


    // MARK: - Goals API
    func goal(for exerciseName: String) -> ExerciseGoal? {
        guard var prefs = prefsRepo.load(for: userId) else { return nil }
        return prefs.exerciseGoals?[normalize(exerciseName)]
    }

    func saveGoal(_ goal: ExerciseGoal?, for exerciseName: String) {
        var prefs = prefsRepo.load(for: userId) ?? UserPreferences()
        var map = prefs.exerciseGoals ?? [:]
        let key = normalize(exerciseName)
        if let goal { map[key] = goal } else { map.removeValue(forKey: key) }
        prefs.exerciseGoals = map
        prefsRepo.save(prefs, for: userId)
        objectWillChange.send()
    }

    func goalProgress(for exerciseName: String) -> GoalProgress? {
        guard let g = goal(for: exerciseName) else { return nil }
        // compute current best metric
        let rms = allSessions.compactMap { s in
            s.exercises.first(where: { normalize($0.name) == normalize(exerciseName) })?
                .sets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max()
        }
        let bestRM = rms.max() ?? 0
        switch g.kind {
        case .oneRM:
            let target = g.targetOneRM ?? 0
            guard target > 0 else { return nil }
            let p = min(1.0, bestRM / target)
            let detail = String(format: "%.1f / %.1f kg", bestRM, target)
            return GoalProgress(title: "Objectif 1RM", progress: p, detail: detail)
        case .repScheme:
            let sets = g.targetSets ?? 0
            let reps = g.targetReps ?? 0
            let w    = g.targetWeight ?? 0
            // simple heuristic: take last session's ability at that weight
            let last = allSessions.last { s in
                s.exercises.contains { normalize($0.name) == normalize(exerciseName) }
            }
            let achievedSets = last?.exercises.first(where: { normalize($0.name) == normalize(exerciseName) })?.sets.filter { $0.weight >= w && $0.reps >= reps }.count ?? 0
            let p = sets > 0 ? min(1.0, Double(achievedSets) / Double(sets)) : 0
            let detail = "\(achievedSets)/\(sets) × \(reps) @ \(Int(w))kg"
            return GoalProgress(title: "Objectif \(sets)×\(reps) @ \(Int(w))kg", progress: p, detail: detail)
        }
    }

    // MARK: - Overload / Deload suggestions
    func overloadSuggestion(for exerciseName: String) -> OverloadSuggestion {
        let key = normalize(exerciseName)
        let stableThreshold = (prefsRepo.load(for: userId)?.overloadStableSessionsCount) ?? 3
        let relevant = allSessions.filter { s in
            s.exercises.contains { normalize($0.name) == key }
        }.suffix(stableThreshold)

        // If not enough data
        guard relevant.count == stableThreshold else {
            return OverloadSuggestion(kind: .none, reason: "Pas assez de séances récentes.")
        }

        // Evaluate stability: reps and weight variance small across last N sessions
        var weights: [Double] = []
        var totalReps: [Int] = []
        for s in relevant {
            if let ex = s.exercises.first(where: { normalize($0.name) == key }) {
                let wAvg = ex.sets.map { $0.weight }.average
                let rSum = ex.sets.map { $0.reps }.reduce(0, +)
                weights.append(wAvg)
                totalReps.append(rSum)
            }
        }
        let wVar = weights.variance
        let rVar = totalReps.map(Double.init).variance

        // Deload if last 3 RM strictly decreasing (reuse existing logic idea)
        let rms = relevant.compactMap { s in
            s.exercises.first(where: { normalize($0.name) == key })?.sets.map { $0.weight * (1 + Double($0.reps)/30.0) }.max()
        }
        if rms.count >= 3, rms[2] < rms[1], rms[1] < rms[0] {
            return OverloadSuggestion(kind: .none, reason: "Fatigue détectée. Deload conseillé.")
        }

        // If stable (low variance), propose small overload
        if wVar < 1.0 && rVar < 10.0 { // heuristic thresholds
            // choose add weight by default
            return OverloadSuggestion(kind: .addWeight(2.5), reason: "Stabilité détectée sur \(stableThreshold) séances.")
        }

        return OverloadSuggestion(kind: .none, reason: "Poursuivez la progression actuelle.")
    }
    
}
// Helper extensions for average and variance calculations
private extension Array where Element == Double {
    var average: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
    var variance: Double {
        let m = average
        return isEmpty ? 0 : reduce(0) { $0 + pow($1 - m, 2) } / Double(count)
    }
}

private extension Array where Element == Int {
    var average: Double { isEmpty ? 0 : Double(reduce(0, +)) / Double(count) }
    var variance: Double {
        let m = average
        return isEmpty ? 0 : map(Double.init).reduce(0) { $0 + pow($1 - m, 2) } / Double(count)
    }
}

