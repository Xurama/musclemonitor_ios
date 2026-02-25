import Foundation
import Combine
import SwiftUI

@MainActor
final class WorkoutRunViewModel: ObservableObject {
    // MARK: - Propriétés
    @Published private(set) var workout: Workout
    private let sessionRepo: WorkoutSessionRepository
    private let startedAt = Date()
    
    // Chronos Globaux
    @Published private(set) var elapsed: Int = 0
    private var globalTimer: AnyCancellable?
    
    // Repos
    @Published private(set) var isResting: Bool = false
    @Published private(set) var restRemaining: Int = 0
    private var restEndsAt: Date? = nil
    private var restTimer: AnyCancellable?
    
    // Timer / Chrono d'Exercice
    @Published var activeExerciseSeconds: Int = 0
    @Published var isExerciseTimerRunning: Bool = false
    private var exerciseTimer: AnyCancellable?

    // État de la séance
    @Published private(set) var currentIndex: Int = 0
    @Published private var setsDone: [String: Int] = [:]
    @Published private var repsBySet: [String: [Int]] = [:]
    @Published private var weightBySet: [String: [Double]] = [:]
    
    // Persistance par exercice pour la navigation
    @Published private var finishedExercises: [String: Bool] = [:]
    @Published private var recordedTimesByExercise: [String: Int] = [:]
    @Published private var distancesByExercise: [String: String] = [:]
    @Published private(set) var lastSessionValue: String? = nil
    @Published private var lastSessionData: [String: WorkoutSession.ExerciseResult] = [:]
    
    @Published var showPRCelebration: Bool = false
    private var personalRecords: [String: Double] = [:]
    
    @Published private var warmupBySet: [String: [Bool]] = [:]
    
    // MARK: - Computed Vars
    var totalExercises: Int { workout.exercises.count }
    var currentPosition: Int { currentIndex + 1 }
    var currentExercise: Workout.Exercise? {
        guard currentIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentIndex]
    }
    
    var sessionProgress: Double {
        return Double(currentPosition) / Double(totalExercises)
    }

    // MARK: - Init
    init(workout: Workout, sessionRepo: WorkoutSessionRepository) {
        self.workout = workout
        self.sessionRepo = sessionRepo
        bootstrap()
        startGlobalTimer()
    }

    private func bootstrap() {
        for ex in workout.exercises {
            setsDone[ex.id] = 0
            repsBySet[ex.id] = Array(repeating: ex.targetReps, count: max(ex.sets, 1))
            weightBySet[ex.id] = Array(repeating: 0.0, count: max(ex.sets, 1))
            warmupBySet[ex.id] = Array(repeating: false, count: max(ex.sets, 1))
        }

        // ✅ default warmup (avant preload)
        applyDefaultWarmupForFirstExerciseIfNeeded()

        Task {
            await preloadLastValues()

            // ✅ si pas d’historique pour le 1er exo, on garde le défaut
            // (et si historique existe, preloadLastValues aura mis les vrais warmups)
            applyDefaultWarmupForFirstExerciseIfNeeded()

            await loadPersonalRecords()
            updateHistoryLabel()
            prepareActiveSecondsForCurrentExercise()
        }
    }


    // MARK: - Gestion du Chrono / Timer Exercice
    
    func isFinished(_ ex: Workout.Exercise) -> Bool {
        finishedExercises[ex.id] ?? false
    }

    func getRecordedTime(for ex: Workout.Exercise) -> Int {
        recordedTimesByExercise[ex.id] ?? 0
    }
    
    private func triggerPRAnimation() {
        print("showPRCelebration")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred() // Grosse vibration
        
        withAnimation(.spring()) {
            showPRCelebration = true
        }
        
        // Cache l'animation après 3 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showPRCelebration = false
            }
        }
    }
    
    func resetExerciseTimer(for exercise: Workout.Exercise) {
        stopExerciseTimer()
        activeExerciseSeconds = exercise.isCardio ? 0 : exercise.targetSeconds
        finishedExercises[exercise.id] = false
    }
    
    func toggleExerciseTimer(for exercise: Workout.Exercise) {
        if isExerciseTimerRunning {
            stopExerciseTimer()
            syncExerciseTimerToSets(for: exercise)
        } else {
            startExerciseTimer(for: exercise)
        }
    }

    private func startExerciseTimer(for exercise: Workout.Exercise) {
        isExerciseTimerRunning = true
        
        if !exercise.isCardio && activeExerciseSeconds <= 0 {
            activeExerciseSeconds = exercise.targetSeconds
        }

        exerciseTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if exercise.isCardio {
                    self.activeExerciseSeconds += 1
                } else {
                    // ✅ LOGIQUE GAINAGE / TEMPS
                    if self.activeExerciseSeconds > 0 {
                        self.activeExerciseSeconds -= 1
                        
                        // Petite vibration à l'objectif atteint
                        if self.activeExerciseSeconds == 0 {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                        }
                    } else {
                        // ✅ ON PASSE EN NÉGATIF (Overtime)
                        // On continue de décrémenter (-1, -2...) pour compter le bonus
                        self.activeExerciseSeconds -= 1
                    }
                }
            }
    }

    // ✅ CORRECTION DE LA SAUVEGARDE
    func stopAndSaveExercise(for exercise: Workout.Exercise) {
        stopExerciseTimer()
        
        let currentSetIndex = getSetsDone(for: exercise)
        let totalSecondsPerformed: Int
        
        if exercise.isCardio {
            totalSecondsPerformed = activeExerciseSeconds
        } else {
            if activeExerciseSeconds <= 0 {
                // Exemple : Objectif 30s, active est à -15s -> Total fait = 30 + 15 = 45s
                totalSecondsPerformed = exercise.targetSeconds + abs(activeExerciseSeconds)
            } else {
                // Exemple : Objectif 30s, arrêté à 10s restantes -> Total fait = 30 - 10 = 20s
                totalSecondsPerformed = exercise.targetSeconds - activeExerciseSeconds
            }
        }

        // 🔥 DETECTION DE RECORD (avec le temps réel effectué)
        let currentScore = Double(totalSecondsPerformed)
        if currentScore > (personalRecords[exercise.id] ?? 0) {
            personalRecords[exercise.id] = currentScore
            triggerPRAnimation()
        }

        setReps(totalSecondsPerformed, for: exercise, setIndex: currentSetIndex)
        recordedTimesByExercise[exercise.id] = totalSecondsPerformed
        toggleSetDone(exercise, setNumber: currentSetIndex + 1)
        
        // Reset du chrono pour la série suivante ou fin de l'exo
        if getSetsDone(for: exercise) < currentSetCount(exercise) {
            activeExerciseSeconds = exercise.targetSeconds
        } else {
            finishedExercises[exercise.id] = true
        }
    }

    // Il faut aussi corriger la sauvegarde pour prendre en compte l'overtime
    func syncExerciseTimerToSets(for exercise: Workout.Exercise) {
        let currentSetIndex = getSetsDone(for: exercise)
        let timeToRecord: Int
        
        if exercise.isCardio {
            timeToRecord = activeExerciseSeconds
        } else {
            // Si activeExerciseSeconds est à -10, et l'objectif était 60,
            // le record est 60 + 10 = 70 secondes.
            timeToRecord = exercise.targetSeconds + abs(min(0, activeExerciseSeconds))
        }
        
        setReps(timeToRecord, for: exercise, setIndex: currentSetIndex)
    }

    func stopExerciseTimer() {
        isExerciseTimerRunning = false
        exerciseTimer?.cancel()
    }

    // MARK: - Navigation
    
    func nextExercise(withRest: Bool = false) {
        // On arrête le chrono mais on ne force plus la synchronisation sauvage vers l'index 0
        if isExerciseTimerRunning { stopExerciseTimer() }
        
        guard currentIndex < workout.exercises.count - 1 else { return }
        currentIndex += 1
        
        prepareActiveSecondsForCurrentExercise()
        updateHistoryLabel()
        
        if withRest { startRestTimer(seconds: workout.exercises[currentIndex-1].restSec) }
        if let ex = currentExercise { onSetStarted(exercise: ex, setIndex: 1) }
    }

    func previousExercise() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        
        prepareActiveSecondsForCurrentExercise()
        updateHistoryLabel()
        
        if let ex = currentExercise { onSetStarted(exercise: ex, setIndex: max(1, getSetsDone(for: ex))) }
    }
    
    private func prepareActiveSecondsForCurrentExercise() {
        guard let ex = currentExercise else { return }
        if isFinished(ex) {
            activeExerciseSeconds = getRecordedTime(for: ex)
        } else {
            activeExerciseSeconds = ex.isCardio ? 0 : ex.targetSeconds
        }
    }

    // MARK: - Séries, Reps, Poids, Distance
    
    func getSetsDone(for ex: Workout.Exercise) -> Int {
        return setsDone[ex.id] ?? 0
    }

    func currentSetCount(_ ex: Workout.Exercise) -> Int {
        repsBySet[ex.id]?.count ?? ex.sets
    }

    func toggleSetDone(_ ex: Workout.Exercise, setNumber: Int) {
        let total = currentSetCount(ex)
        let prevDone = setsDone[ex.id] ?? 0
        var done = prevDone

        if setNumber <= done { done = setNumber - 1 }
        else { done = setNumber }

        done = min(max(done, 0), total)
        setsDone[ex.id] = done

        // Si on vient de valider une série
        if done > prevDone {
            // 🔥 VERIFICATION PR (Musculation)
            if !ex.isTimeBased {
                let currentWeight = weight(for: ex, setIndex: done - 1)
                checkAndTriggerPR(exerciseId: ex.id, value: currentWeight)
            }
            
            if done < total {
                startRestTimer(seconds: ex.restSec)
            } else if currentIndex < workout.exercises.count - 1 {
                nextExercise(withRest: true)
            }
        }
    }
    
    func checkAndTriggerPR(exerciseId: String, value: Double) {
        let previousRecord = personalRecords[exerciseId] ?? 0
        
        print("Vérification PR - Exercice: \(exerciseId), Valeur: \(value), Ancien Record: \(previousRecord)")
        
        if value > previousRecord && value > 0 {
            // ✅ Mise à jour du record local immédiate pour que la prochaine série
            // doive battre CETTE nouvelle valeur
            personalRecords[exerciseId] = value
            triggerPRAnimation()
        }
    }
    func getDistance(for ex: Workout.Exercise) -> String {
        distancesByExercise[ex.id] ?? ""
    }
    
    func setDistance(_ value: String, for ex: Workout.Exercise) {
        distancesByExercise[ex.id] = value
    }

    func reps(for ex: Workout.Exercise, setIndex: Int) -> Int {
        return repsBySet[ex.id]?[safe: setIndex] ?? ex.targetReps
    }

    func weight(for ex: Workout.Exercise, setIndex: Int) -> Double {
        return weightBySet[ex.id]?[safe: setIndex] ?? 0.0
    }

    func setReps(_ value: Int, for ex: Workout.Exercise, setIndex: Int) {
        // On s'assure d'avoir un tableau existant
        if repsBySet[ex.id] == nil {
            repsBySet[ex.id] = Array(repeating: ex.targetReps, count: currentSetCount(ex))
        }
        
        // On ne modifie QUE l'index concerné
        if repsBySet[ex.id]!.indices.contains(setIndex) {
            repsBySet[ex.id]![setIndex] = value
            // Pas besoin de objectWillChange.send() ici car @Published s'en occupe pour le dictionnaire
        }
    }

    func setWeight(_ value: Double, for ex: Workout.Exercise, setIndex: Int) {
        if weightBySet[ex.id] == nil {
            weightBySet[ex.id] = Array(repeating: 0.0, count: currentSetCount(ex))
        }
        
        if weightBySet[ex.id]!.indices.contains(setIndex) {
            weightBySet[ex.id]![setIndex] = value
        }
    }
    
    func applySameReps(_ value: Int, for ex: Workout.Exercise) {
        let n = currentSetCount(ex)
        repsBySet[ex.id] = Array(repeating: max(0, min(200, value)), count: n)
    }

    func applySameWeight(_ value: Double, for ex: Workout.Exercise) {
        let n = currentSetCount(ex)
        weightBySet[ex.id] = Array(repeating: max(0, min(1000, value)), count: n)
    }

    // MARK: - Timers Globaux & Repos
    
    private func startGlobalTimer() {
        globalTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.elapsed = Int(Date().timeIntervalSince(self.startedAt))
            }
    }

    private func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimer?.cancel()
        restRemaining = seconds
        restEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        isResting = true

        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let remain = Int((self.restEndsAt ?? Date()).timeIntervalSinceNow.rounded())
                self.restRemaining = max(0, remain)
                if remain <= 0 {
                    self.isResting = false
                    self.restTimer?.cancel()
                }
            }
    }

    func skipRest() {
        isResting = false
        restTimer?.cancel()
    }

    // MARK: - Persistance & Historique
    
    func removeSet(_ ex: Workout.Exercise, at index: Int) {
        guard repsBySet[ex.id]?.indices.contains(index) == true else { return }
        repsBySet[ex.id]?.remove(at: index)
        weightBySet[ex.id]?.remove(at: index)
        warmupBySet[ex.id]?.remove(at: index)
        let currentTotal = currentSetCount(ex)
        if let done = setsDone[ex.id], done > currentTotal { setsDone[ex.id] = currentTotal }
        objectWillChange.send()
    }
    
    func addSet(_ ex: Workout.Exercise) {
        let lastWeight = weightBySet[ex.id]?.last ?? 0.0
        repsBySet[ex.id, default: []].append(ex.targetReps)
        weightBySet[ex.id, default: []].append(lastWeight)
        warmupBySet[ex.id, default: []].append(false)
        objectWillChange.send()
    }
    
    func finishAndPersist() async {
        stopExerciseTimer()
        let endedAt = Date()
        
        let exercisesResults: [WorkoutSession.ExerciseResult] = workout.exercises.map { ex in
            let repsArr = repsBySet[ex.id] ?? []
            let weightArr = weightBySet[ex.id] ?? []
            let count = min(repsArr.count, weightArr.count)
            let sets: [WorkoutSession.SetResult] = (0..<count).map { i in
                .init(
                    reps: repsArr[i],
                    weight: weightArr[i],
                    isWarmup: warmupBySet[ex.id]?[safe: i] ?? false
                )
            }

            return .init(exerciseId: ex.id, name: ex.name, sets: sets, equipment: ex.equipment)
        }

        let session = WorkoutSession(
            workoutId: workout.id,
            title: workout.displayTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            exercises: exercisesResults
        )

        try? await sessionRepo.add(session)
        WorkoutLiveActivityManager.shared.end(success: true)
    }

    private func preloadLastValues() async {
        guard let last = await findLastSession() else {
            print("DEBUG: Aucune séance précédente trouvée")
            return
        }

        print("DEBUG: Séance précédente trouvée du \(last.endedAt)")

        var newWeights = weightBySet
        var newReps = repsBySet
        var newWarmups = warmupBySet
        var newLastSessionData = lastSessionData

        for ex in workout.exercises {
            if let prevEx = last.exercises.first(where: { $0.exerciseId == ex.id }) {
                newLastSessionData[ex.id] = prevEx

                let weights = prevEx.sets.map { $0.weight }
                let reps    = prevEx.sets.map { $0.reps }
                let warmups = prevEx.sets.map { $0.isWarmup }   // ✅ si tu le persistes

                newWeights[ex.id] = weights
                newReps[ex.id] = reps
                newWarmups[ex.id] = warmups

                // Compléter si nécessaire (poids/reps/warmup)
                let totalNeeded = max(ex.sets, 1)
                if weights.count < totalNeeded {
                    let extra = totalNeeded - weights.count
                    newWeights[ex.id]?.append(contentsOf: Array(repeating: weights.last ?? 0, count: extra))
                    newReps[ex.id]?.append(contentsOf: Array(repeating: reps.last ?? ex.targetReps, count: extra))
                    newWarmups[ex.id]?.append(contentsOf: Array(repeating: false, count: extra))
                }
            } else {
                // Pas de séance précédente pour cet exo => on s'assure que warmup a la bonne taille
                let totalNeeded = max(ex.sets, 1)
                if newWarmups[ex.id]?.count != totalNeeded {
                    newWarmups[ex.id] = Array(repeating: false, count: totalNeeded)
                }
            }
        }

        await MainActor.run {
            self.weightBySet = newWeights
            self.repsBySet = newReps
            self.warmupBySet = newWarmups
            self.lastSessionData = newLastSessionData
            self.objectWillChange.send()
            print("DEBUG: Données injectées dans le ViewModel")
        }
    }

    
    private func loadPersonalRecords() async {
        do {
            let allSessions = try await sessionRepo.list()
            for ex in workout.exercises {
                // On cherche la meilleure perf (poids max ou temps max selon l'exo)
                let best = allSessions.compactMap { session in
                    session.exercises.first(where: { $0.exerciseId == ex.id })?.sets.map {
                        ex.isTimeBased ? Double($0.reps) : $0.weight
                    }.max()
                }.max()
                personalRecords[ex.id] = best ?? 0
            }
        } catch { }
    }
    
    private func findLastSession() async -> WorkoutSession? {
        do {
            return try await sessionRepo.list()
                .filter({ $0.workoutId == workout.id })
                .sorted(by: { $0.endedAt > $1.endedAt })
                .first
        } catch { return nil }
    }
    
    private func updateHistoryLabel() {
        guard let ex = currentExercise else { return }
        Task {
            let last = await findLastSession()
            if let prevEx = last?.exercises.first(where: { $0.exerciseId == ex.id }),
               let firstSet = prevEx.sets.first {
                if ex.isTimeBased {
                    self.lastSessionValue = "Dernière fois : \(timeString(firstSet.reps))"
                } else {
                    self.lastSessionValue = "Dernière fois : \(firstSet.reps) reps @ \(firstSet.weight)kg"
                }
            } else {
                self.lastSessionValue = nil
            }
        }
    }

    // MARK: - Live Activity Hooks
    func onSetStarted(exercise: Workout.Exercise, setIndex: Int) {
        WorkoutLiveActivityManager.shared.update(
            workoutTitle: workout.displayTitle,
            exerciseName: exercise.name,
            setIndex: setIndex,
            totalSets: currentSetCount(exercise),
            nextReps: exercise.targetReps,
            nextWeight: weight(for: exercise, setIndex: setIndex - 1),
            progress: sessionProgress,
            isResting: false,
            restEndsAt: nil
        )
    }

    func onRestStarted(duration: TimeInterval, exercise: Workout.Exercise, nextSetIndex: Int) {
        WorkoutLiveActivityManager.shared.update(
            workoutTitle: workout.displayTitle,
            exerciseName: exercise.name,
            setIndex: nextSetIndex,
            totalSets: currentSetCount(exercise),
            nextReps: exercise.targetReps,
            nextWeight: weight(for: exercise, setIndex: nextSetIndex - 1),
            progress: sessionProgress,
            isResting: true,
            restEndsAt: Date().addingTimeInterval(duration)
        )
    }
    
    private func timeString(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%02d:%02d", m, r)
    }
    
    func addExercise(_ exercise: Workout.Exercise) {
            workout.exercises.append(exercise)
            // Initialisation des données pour le nouvel exo
            setsDone[exercise.id] = 0
            repsBySet[exercise.id] = Array(repeating: exercise.targetReps, count: exercise.sets)
            weightBySet[exercise.id] = Array(repeating: 0.0, count: exercise.sets)
            warmupBySet[exercise.id] = Array(repeating: false, count: max(exercise.sets, 1))
            objectWillChange.send()
        }
        
        func removeCurrentExercise() {
            guard workout.exercises.count > 1 else { return }
            let idToRemove = workout.exercises[currentIndex].id
            workout.exercises.remove(at: currentIndex)
            
            // Nettoyage des dictionnaires
            setsDone.removeValue(forKey: idToRemove)
            repsBySet.removeValue(forKey: idToRemove)
            weightBySet.removeValue(forKey: idToRemove)
            warmupBySet.removeValue(forKey: idToRemove)
            
            // Ajustement de l'index si on était sur le dernier
            if currentIndex >= workout.exercises.count {
                currentIndex = workout.exercises.count - 1
            }
            prepareActiveSecondsForCurrentExercise()
            objectWillChange.send()
        }

    func addExerciseAfterCurrent(_ exercise: Workout.Exercise) {
        // Stop any running timer to avoid leaks
        if isExerciseTimerRunning { stopExerciseTimer() }
        let insertIndex = min(currentIndex + 1, workout.exercises.count)
        workout.exercises.insert(exercise, at: insertIndex)

        // Initialize state for the new exercise
        setsDone[exercise.id] = 0
        repsBySet[exercise.id] = Array(repeating: exercise.targetReps, count: max(exercise.sets, 1))
        weightBySet[exercise.id] = Array(repeating: 0.0, count: max(exercise.sets, 1))
        warmupBySet[exercise.id] = Array(repeating: false, count: max(exercise.sets, 1))

        // Jump to the inserted exercise
        currentIndex = insertIndex
        prepareActiveSecondsForCurrentExercise()
        updateHistoryLabel()
        if let ex = currentExercise {
            onSetStarted(exercise: ex, setIndex: 1)
        }

        objectWillChange.send()
    }

    // MARK: - Logique de comparaison (Diff avec dernière séance)
    
    struct PerformanceDiff {
        let weightDiff: Double
        let repsDiff: Int
    }

    func getDiff(for exercise: Workout.Exercise, setIndex: Int) -> PerformanceDiff? {
        guard let lastEx = lastSessionData[exercise.id],
              lastEx.sets.indices.contains(setIndex) else { return nil }
        
        let lastSet = lastEx.sets[setIndex]
        let currentWeight = weight(for: exercise, setIndex: setIndex)
        let currentReps = reps(for: exercise, setIndex: setIndex)
        
        return PerformanceDiff(
            weightDiff: currentWeight - lastSet.weight,
            repsDiff: currentReps - lastSet.reps
        )
    }
    
    func bumpReps(_ delta: Int, for ex: Workout.Exercise, setIndex: Int) {
        let current = reps(for: ex, setIndex: setIndex)
        setReps(max(0, min(300, current + delta)), for: ex, setIndex: setIndex)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func bumpWeight(_ delta: Double, for ex: Workout.Exercise, setIndex: Int) {
        let current = weight(for: ex, setIndex: setIndex)
        let next = max(0, min(1000, current + delta))
        // arrondi au 0.5 si tu veux (optionnel)
        let rounded = (next * 2).rounded() / 2
        setWeight(rounded, for: ex, setIndex: setIndex)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func isWarmup(for ex: Workout.Exercise, setIndex: Int) -> Bool {
        warmupBySet[ex.id]?[safe: setIndex] ?? false
    }

    func toggleWarmup(for ex: Workout.Exercise, setIndex: Int) {
        if warmupBySet[ex.id] == nil {
            warmupBySet[ex.id] = Array(repeating: false, count: currentSetCount(ex))
        }
        guard warmupBySet[ex.id]!.indices.contains(setIndex) else { return }
        warmupBySet[ex.id]![setIndex].toggle()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        objectWillChange.send()
    }
    
    private func applyDefaultWarmupForFirstExerciseIfNeeded() {
        guard let first = workout.exercises.first else { return }
        let n = currentSetCount(first)
        if warmupBySet[first.id]?.count != n {
            warmupBySet[first.id] = Array(repeating: false, count: n)
        }
        if n > 0 { warmupBySet[first.id]?[0] = true }
        if n > 1 { warmupBySet[first.id]?[1] = true }
    }


}

// MARK: - Extensions
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


