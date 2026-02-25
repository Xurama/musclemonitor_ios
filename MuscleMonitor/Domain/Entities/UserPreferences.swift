//
//  UserPreferences.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import Foundation

public enum ExerciseGoalKind: String, Codable {
    case oneRM
    case repScheme
}

public struct ExerciseGoal: Codable, Equatable {
    public var kind: ExerciseGoalKind
    // For oneRM target
    public var targetOneRM: Double?
    // For rep scheme target (e.g., 3x8 @ 60kg)
    public var targetSets: Int?
    public var targetReps: Int?
    public var targetWeight: Double?

    public init(oneRM: Double) {
        self.kind = .oneRM
        self.targetOneRM = oneRM
        self.targetSets = nil
        self.targetReps = nil
        self.targetWeight = nil
    }

    public init(sets: Int, reps: Int, weight: Double) {
        self.kind = .repScheme
        self.targetOneRM = nil
        self.targetSets = sets
        self.targetReps = reps
        self.targetWeight = weight
    }
}

public enum FirstWeekday: String, Codable, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    public var id: String { rawValue }
    public var display: String {
        switch self {
        case .monday: return "Lundi"
        case .tuesday: return "Mardi"
        case .wednesday: return "Mercredi"
        case .thursday: return "Jeudi"
        case .friday: return "Vendredi"
        case .saturday: return "Samedi"
        case .sunday: return "Dimanche"
        }
    }
}

public enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    public var id: String { rawValue }
    public var display: String {
        switch self { case .kg: return "kg"; case .lb: return "lb" }
    }
}

public enum CalorieObjective: String, Codable, CaseIterable, Identifiable {
    case deficit, maintain, surplus
    public var id: String { rawValue }
    public var display: String {
        switch self {
        case .deficit:  return "Déficit"
        case .maintain: return "Maintien"
        case .surplus:  return "Prise de masse"
        }
    }
}

public enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male, female
    public var id: String { rawValue }
    public var display: String { self == .male ? "Homme" : "Femme" }
}

public struct UserPreferences: Codable, Equatable {
    public var sex: BiologicalSex
    public var birthDate: Date

    // Per-exercise goals and progression settings
    public var exerciseGoals: [String: ExerciseGoal]? // key = exercise name
    public var overloadStableSessionsCount: Int? // default 3 if nil

    public var weeklyGoal: Int
    public var monthlyGoal: Int
    public var firstWeekday: FirstWeekday
    public var weightUnit: WeightUnit

    public var bodyWeightKg: Double?
    public var heightCm: Double?
    public var objective: CalorieObjective

    public init(
        weeklyGoal: Int = 3,
        monthlyGoal: Int = 15,
        firstWeekday: FirstWeekday = .monday,
        weightUnit: WeightUnit = .kg,
        bodyWeightKg: Double? = nil,
        heightCm: Double? = nil,
        objective: CalorieObjective = .maintain,
        sex: BiologicalSex = .male,
        birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        , exerciseGoals: [String: ExerciseGoal]? = nil
        , overloadStableSessionsCount: Int? = nil
    ) {
        self.weeklyGoal = weeklyGoal
        self.monthlyGoal = monthlyGoal
        self.firstWeekday = firstWeekday
        self.weightUnit = weightUnit
        self.bodyWeightKg = bodyWeightKg
        self.heightCm = heightCm
        self.objective = objective
        self.sex = sex
        self.birthDate = birthDate
        self.exerciseGoals = exerciseGoals
        self.overloadStableSessionsCount = overloadStableSessionsCount
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 25
    }

    enum CodingKeys: String, CodingKey {
        case weeklyGoal, monthlyGoal, firstWeekday, weightUnit
        case bodyWeightKg, heightCm, objective
        case sex, birthDate
        case exerciseGoals, overloadStableSessionsCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weeklyGoal   = try c.decodeIfPresent(Int.self, forKey: .weeklyGoal) ?? 3
        monthlyGoal  = try c.decodeIfPresent(Int.self, forKey: .monthlyGoal) ?? 15
        firstWeekday = try c.decodeIfPresent(FirstWeekday.self, forKey: .firstWeekday) ?? .monday
        weightUnit   = try c.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .kg
        bodyWeightKg = try c.decodeIfPresent(Double.self, forKey: .bodyWeightKg)
        heightCm     = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        objective    = try c.decodeIfPresent(CalorieObjective.self, forKey: .objective) ?? .maintain
        sex          = try c.decodeIfPresent(BiologicalSex.self, forKey: .sex) ?? .male
        birthDate    = try c.decodeIfPresent(Date.self, forKey: .birthDate) ?? (Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date())
        exerciseGoals = try c.decodeIfPresent([String: ExerciseGoal].self, forKey: .exerciseGoals)
        overloadStableSessionsCount = try c.decodeIfPresent(Int.self, forKey: .overloadStableSessionsCount)
    }
}

// MARK: - Nutrition Logic
extension UserPreferences {
    /// Calcule le métabolisme de base (BMR) - Formule de Mifflin-St Jeor
    func calculateBMR() -> Int {
        guard let weight = bodyWeightKg, let height = heightCm else { return 2000 }
        
        // Formule Homme : (10 × poids kg) + (6.25 × taille cm) - (5 × âge) + 5
        // On utilise 25 ans par défaut pour l'instant
        let bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) + (sex == .male ? 5 : -161)
        return Int(bmr)
    }

    /// Retourne l'ajustement calorique selon l'objectif sélectionné
    var calorieAdjustment: Int {
        switch objective {
        case .deficit:  return -500 // Déficit pour perte de gras
        case .maintain: return 0
        case .surplus:  return 300  // Surplus pour prise de muscle
        }
    }
    
    var proteinTarget: Double {
            guard let weight = bodyWeightKg else { return 180 }
            return weight * 2.0 // 2g/kg
        }
        
        var fatTarget: Double {
            guard let weight = bodyWeightKg else { return 80 }
            return weight * 0.9 // ~0.9g/kg
        }
        
        // Les glucides comblent le reste des calories (1g P/G = 4kcal, 1g L = 9kcal)
        func calculateCarbsTarget(totalKcal: Int) -> Double {
            let pKcal = proteinTarget * 4
            let fKcal = fatTarget * 9
            let remainingKcal = Double(totalKcal) - pKcal - fKcal
            return max(50, remainingKcal / 4)
        }
}

