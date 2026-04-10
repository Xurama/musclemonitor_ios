import Foundation

public struct Workout: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String?
    public var date: Date
    public var exercises: [Exercise]

    public struct Exercise: Identifiable, Codable, Equatable {
        public let id: String
        public var name: String
        public var muscleGroup: MuscleTag
        public var equipment: Equipment?
        public var sets: Int
        public var effort: Effort
        public var restSec: Int

        // SOURCE UNIQUE DE VÉRITÉ — muscles sollicités par exercice
        public static let muscleMapping: [String: Set<MuscleTag>] = [
            // Pectoraux / Poussé
            "db_bench_press":          [.pectoraux, .triceps, .epaules],
            "db_incline_press":        [.pectoraux, .triceps, .epaules],
            "chest_fly_machine":       [.pectoraux],
            "dips_weighted":           [.pectoraux, .triceps],
            // Épaules
            "barbell_shoulder_press":  [.epaules, .triceps],
            "db_lateral_raises":       [.epaules],
            "face_pulls":              [.epaules],
            // Dos / Tirage
            "deadlift":                [.dos, .ischio, .fessiers],
            "lat_pulldown":            [.dos, .biceps],
            "seated_row":              [.dos, .biceps],
            "shrugs":                  [.dos],
            "weighted_pullups":        [.dos, .biceps],
            "scapular_pull_ups":       [.dos, .biceps],
            // Bras
            "triceps_pushdown":        [.triceps],
            "biceps_curl":             [.biceps],
            // Jambes
            "squat":                   [.quadriceps, .fessiers, .ischio],
            "leg_press":               [.quadriceps, .fessiers, .ischio],
            "hip_thrust":              [.fessiers],
            "leg_curl":                [.ischio],
            "leg_extension":           [.quadriceps],
            "calf_raise":              [.mollets],
            "walking_lunges":          [.quadriceps, .fessiers, .ischio],
            "hip_abduction":           [.fessiers],
            // Abdos / Gainage
            "plank":                   [.abdominaux],
            "leg_raises":              [.abdominaux],
            "dynamic_plank_taps":      [.abdominaux],
            "hanging_leg_raises":      [.abdominaux],
            "dynamic_plank":           [.abdominaux],
            "side_crunch":             [.abdominaux],
            "hollow_body_hold":        [.abdominaux],
            "side_plank":              [.abdominaux],
            "mountain_climbers":       [.abdominaux],
            // Cardio
            "running":                 [.cardio],
            "rowing_machine":          [.cardio, .dos, .quadriceps, .ischio],
            "stationary_bike":         [.cardio, .quadriceps],
            "elliptical_bike":         [.cardio, .quadriceps, .ischio],
            // Fonctionnel / Hyrox
            "burpees":                 [.pectoraux, .quadriceps, .epaules, .abdominaux],
            "db_thrusters":            [.quadriceps, .fessiers, .epaules, .triceps],
            "hyrox_ski_erg":           [.cardio, .dos, .epaules, .abdominaux],
            "hyrox_sled_push":         [.quadriceps, .fessiers, .epaules, .abdominaux],
            "hyrox_sled_pull":         [.dos, .biceps, .fessiers, .abdominaux],
            "hyrox_farmers_carry":     [.epaules, .abdominaux],
            "hyrox_wall_balls":        [.quadriceps, .epaules, .abdominaux],
        ]

        // Exercices dont l'effort se mesure en durée (chronomètre)
        public static let timeBasedNames: Set<String> = [
            "plank", "dynamic_plank", "hollow_body_hold", "side_plank",
            "running", "rowing_machine", "stationary_bike", "elliptical_bike",
            "mountain_climbers",
        ]

        // Exercices dont l'effort se mesure en distance
        public static let distanceBasedNames: Set<String> = [
            "hyrox_ski_erg", "hyrox_sled_push", "hyrox_sled_pull", "hyrox_farmers_carry",
            "ski_erg", "sled_push", "sled_pull", "farmers_carry",
        ]

        /// Effort par défaut lors de la création d'un exercice.
        public static func defaultEffort(for name: String) -> Effort {
            if distanceBasedNames.contains(name) { return .distance(meters: 100) }
            if timeBasedNames.contains(name) { return .time(seconds: 60) }
            return .reps(10)
        }

        // ✅ UNE SEULE DÉFINITION ICI
        public var isCardio: Bool {
            Exercise.muscleMapping[self.name]?.contains(.cardio) ?? false
        }

        public var isTimeBased: Bool {
            if case .time = self.effort { return true }
            return false
        }

        public var isDistanceBased: Bool {
            if case .distance = self.effort { return true }
            return false
        }

        public var targetReps: Int {
            if case .reps(let r) = effort { return r }
            return 0
        }

        public var targetSeconds: Int {
            if case .time(let s) = effort { return s }
            return 0
        }

        public var targetMeters: Int {
            if case .distance(let m) = effort { return m }
            return 0
        }

        public init(id: String = UUID().uuidString, name: String, muscleGroup: MuscleTag = .dos, equipment: Equipment? = nil, sets: Int = 3, effort: Effort = .reps(10), restSec: Int = 90) {
            self.id = id; self.name = name; self.muscleGroup = muscleGroup; self.equipment = equipment; self.sets = sets; self.effort = effort; self.restSec = restSec
        }

        private enum CodingKeys: String, CodingKey { case id, name, muscleGroup, equipment, sets, effort, restSec, reps }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self.name = try c.decode(String.self, forKey: .name)
            self.muscleGroup = try c.decodeIfPresent(MuscleTag.self, forKey: .muscleGroup) ?? .dos
            self.equipment = try c.decodeIfPresent(Equipment.self, forKey: .equipment)
            self.sets = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
            self.restSec = try c.decodeIfPresent(Int.self, forKey: .restSec) ?? 90
            if let eff = try c.decodeIfPresent(Effort.self, forKey: .effort) { self.effort = eff }
            else if let legacyReps = try c.decodeIfPresent(Int.self, forKey: .reps) { self.effort = .reps(legacyReps) }
            else { self.effort = .reps(10) }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
            try c.encodeIfPresent(equipment, forKey: .equipment); try c.encode(sets, forKey: .sets)
            try c.encode(restSec, forKey: .restSec); try c.encode(effort, forKey: .effort)
        }
    }

    public enum Equipment: String, Codable, CaseIterable, Identifiable {
        case barre, halteres, poulie, machine, corps, leste
        public var id: String { rawValue }
        public var display: String {
            switch self {
            case .barre: return "Barre"; case .halteres: return "Haltères"; case .poulie: return "Poulie"
            case .machine: return "Machine"; case .corps: return "Poids de corps"; case .leste: return "Lesté"
            }
        }
    }

    public enum Effort: Codable, Equatable {
        case reps(Int), time(seconds: Int), distance(meters: Int)
        private enum CodingKeys: String, CodingKey { case kind, value }
        private enum Kind: String, Codable { case reps, time, distance }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(Kind.self, forKey: .kind)
            let v = try c.decode(Int.self, forKey: .value)
            switch kind {
            case .reps: self = .reps(v)
            case .time: self = .time(seconds: v)
            case .distance: self = .distance(meters: v)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .reps(let r): try c.encode(Kind.reps, forKey: .kind); try c.encode(r, forKey: .value)
            case .time(let s): try c.encode(Kind.time, forKey: .kind); try c.encode(s, forKey: .value)
            case .distance(let m):
                try c.encode(Kind.distance, forKey: .kind)
                try c.encode(m, forKey: .value)
            }
        }
    }
}
