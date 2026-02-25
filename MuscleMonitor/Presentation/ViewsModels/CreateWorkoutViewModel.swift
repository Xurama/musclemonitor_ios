//
//  CreateWorkoutViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 12/09/2025.
//

import SwiftUI


public enum MuscleTag: String, CaseIterable, Identifiable, Codable, Hashable {
    case dos, biceps, pectoraux, abdominaux, fessiers, quadriceps, ischio, epaules, triceps, mollets, cardio
    
    public var id: String { rawValue }

    // On utilise LocalizedStringKey pour que SwiftUI cherche dans le String Catalog
    public var displayName: String {
        // NSLocalizedString va chercher la version traduite de la clé "dos", "biceps", etc.
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

@MainActor
final class CreateWorkoutViewModel: ObservableObject {
    // Étapes du flow
    enum Step { case tags, select, configure }

    // State
    @Published var step: Step = .tags
    @Published var workoutName: String = ""
    @Published var allExercises: [String] = []
    @Published var selectedTags: Set<MuscleTag> = []
    
    var isEditing: Bool { editingId != nil }

    // Exercices filtrés dynamiquement selon les tags sélectionnés
    var filteredExercises: [String] {
        guard !selectedTags.isEmpty else { return allExercises }
        return allExercises.filter { name in
            // Utilise la nouvelle constante
            guard let tags = exerciseMapping[name] else { return false }
            return !tags.isDisjoint(with: selectedTags)
        }
    }
    
    private let exerciseMapping: [String: Set<MuscleTag>] = [
        // Pectoraux / Poussé
        "db_bench_press": [.pectoraux, .triceps, .epaules],
        "db_incline_press": [.pectoraux, .triceps, .epaules],
        "chest_fly_machine": [.pectoraux],
        "dips_weighted": [.pectoraux, .triceps],
        
        // Épaules
        "barbell_shoulder_press": [.epaules, .triceps],
        "db_lateral_raises": [.epaules],
        "face_pulls": [.epaules],
        
        // Dos / Tirage
        "deadlift": [.dos, .ischio, .fessiers],
        "lat_pulldown": [.dos, .biceps],
        "seated_row": [.dos, .biceps],
        "shrugs": [.dos],
        "weighted_pullups": [.dos, .biceps],
        "scapular_pull_ups": [.dos, .biceps],
        
        // Bras
        "triceps_pushdown": [.triceps],
        "biceps_curl": [.biceps],
        
        // Jambes
        "squat": [.quadriceps, .fessiers, .ischio],
        "leg_press": [.quadriceps, .fessiers, .ischio],
        "hip_thrust": [.fessiers],
        "leg_curl": [.ischio],
        "leg_extension": [.quadriceps],
        "calf_raise": [.mollets],
        "walking_lunges": [.quadriceps, .fessiers, .ischio],
        "hip_abduction": [.fessiers],
        
        // Abdos / Gainage
        "plank": [.abdominaux],
        "leg_raises": [.abdominaux],
        "dynamic_plank_taps": [.abdominaux],
        "hanging_leg_raises": [.abdominaux],
        "dynamic_plank": [.abdominaux],
        "side_crunch": [.abdominaux],
        "hollow_body_hold": [.abdominaux],
        "side_plank": [.abdominaux],
        "mountain_climbers": [.abdominaux],
        
        // Cardio
        "running": [.cardio],
        "rowing_machine": [.cardio, .dos, .quadriceps, .ischio],
        "stationary_bike": [.cardio, .quadriceps],
        "elliptical_bike": [.cardio, .quadriceps, .ischio],
        
        // Hyrox
        "burpees": [.pectoraux, .quadriceps, .epaules, .abdominaux],
        "db_thrusters": [.quadriceps, .fessiers, .epaules, .triceps]
    ]
    
    private let timeBasedNames: Set<String> = [
        "plank",
        "dynamic_plank",
        "hollow_body_hold",
        "running",
        "rowing_machine",
        "stationary_bike",
        "elliptical_bike",
        "side_plank",
        "mountain_climbers"
        // Tu peux en ajouter d'autres si besoin
    ]

    // Sélection exercices
    @Published var selectedNames: Set<String> = []
    @Published var selectedOrder: [String] = []
    @Published var configs: [String: Workout.Exercise] = [:]

    // Édition: conserver id/date d'origine pour permettre update par id
    private var editingId: String? = nil
    private var originalDate: Date? = nil

    // Repo
    private let catalogRepo: ExerciseCatalogRepository
    init(catalogRepo: ExerciseCatalogRepository) { self.catalogRepo = catalogRepo }

    convenience init(catalogRepo: ExerciseCatalogRepository, prefilled workout: Workout) {
        self.init(catalogRepo: catalogRepo)
        // Prefill state from workout
        self.workoutName = workout.name ?? ""
        self.selectedNames = Set(workout.exercises.map { $0.name })
        self.selectedOrder = workout.exercises.map { $0.name }
        self.configs = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.name, $0) })
        self.step = .configure
        // Conserver id et date d'origine pour que update remplace l'élément
        self.editingId = workout.id
        self.originalDate = workout.date
    }

    // Charger le catalogue
    func loadCatalog() { Task { 
        self.allExercises = Array(exerciseMapping.keys).sorted()
        print("[CreateWorkoutVM] loaded catalog: \(allExercises.count) keys")
    } }

    // Toggle sélection (ajoute/supprime + config par défaut)
    func toggleSelection(_ name: String) {
        if selectedNames.contains(name) {
            selectedNames.remove(name)
            selectedOrder.removeAll { $0 == name }
            configs[name] = nil
        } else {
            selectedNames.insert(name)
            selectedOrder.append(name)

            // config par défaut
            if configs[name] == nil {
                // On récupère le tag qui a servi à filtrer cet exercice
                // (ou on définit un mapping statique SEULEMENT ICI à la création)
                let detectedTag = exerciseMapping[name]?.first ?? .dos

                configs[name] = Workout.Exercise(
                    name: name,
                    muscleGroup: detectedTag, // ⬅️ Assigné à la création
                    sets: 3,
                    effort: timeBasedNames.contains(name) ? .time(seconds: 60) : .reps(10),
                    restSec: 90
                )
            }
        }
    }

    func goToConfigure() { step = .configure }

    // Filtrer par tags puis passer à la sélection
    func goToSelect() {
        step = .select
    }

    // Helpers
    var orderedExercises: [Workout.Exercise] {
        selectedOrder.compactMap { configs[$0] }
    }

    func reorder(fromOffsets: IndexSet, toOffset: Int) {
        selectedOrder.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func update(_ exercise: Workout.Exercise) {
        configs[exercise.name] = exercise
    }

    func buildWorkout(date: Date = .now) -> Workout {
        let id = editingId ?? UUID().uuidString
        let finalDate = originalDate ?? date
        let workout = Workout(id: id,
                              name: workoutName.isEmpty ? nil : workoutName,
                              date: finalDate,
                              exercises: orderedExercises)
        print("[buildWorkout] built id: \(workout.id), name: \(workout.name ?? "-"), exercises: \(workout.exercises.count)")
        return workout
    }
    
    private let cardioNames: Set<String> = [
        "running", "rowing_machine", "stationary_bike", "elliptical_bike"
    ]

    // Ajoute cette petite fonction helper pour l'utiliser dans la vue
    func isCardio(_ name: String) -> Bool {
        return cardioNames.contains(name)
    }
    
    func removeExercise(_ name: String) {
        selectedNames.remove(name)
        selectedOrder.removeAll { $0 == name }
        configs[name] = nil
    }

    func removeExercises(at offsets: IndexSet) {
        // offsets correspond à l’ordre affiché (selectedOrder)
        // on supprime en partant de la fin pour éviter les décalages
        for i in offsets.sorted(by: >) {
            guard selectedOrder.indices.contains(i) else { continue }
            let name = selectedOrder[i]
            removeExercise(name)
        }
    }
    
    func removeExercise(_ ex: Workout.Exercise) {
        removeExercise(ex.name)
    }


}
